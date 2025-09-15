(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-EXISTS (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-PROPOSAL-EXPIRED (err u104))
(define-constant ERR-PROPOSAL-ACTIVE (err u105))
(define-constant ERR-ALREADY-VOTED (err u106))
(define-constant ERR-INVALID-AMOUNT (err u107))
(define-constant ERR-VOTING-ENDED (err u108))
(define-constant ERR-NOT-MEMBER (err u109))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u110))
(define-constant ERR-MULTISIG-REQUIRED (err u111))
(define-constant ERR-INSUFFICIENT-APPROVALS (err u112))
(define-constant ERR-NOT-TRUSTEE (err u113))
(define-constant ERR-ALREADY-APPROVED (err u114))

(define-data-var contract-owner principal tx-sender)
(define-data-var dao-treasury uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var member-counter uint u0)
(define-data-var minimum-stake uint u1000000)
(define-data-var voting-period uint u1008)
(define-data-var multisig-threshold uint u5000000)
(define-data-var required-approvals uint u3)

(define-map dao-members
    principal
    {
        stake: uint,
        reputation: uint,
        joined-at: uint,
        is-active: bool,
        is-trustee: bool,
    }
)

(define-map proposals
    uint
    {
        proposer: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        requested-amount: uint,
        beneficiary: principal,
        created-at: uint,
        voting-ends-at: uint,
        yes-votes: uint,
        no-votes: uint,
        total-voters: uint,
        executed: bool,
        status: (string-ascii 20),
        requires-multisig: bool,
        approval-count: uint,
    }
)

(define-map votes
    {
        proposal-id: uint,
        voter: principal,
    }
    bool
)

(define-map multisig-approvals
    {
        proposal-id: uint,
        trustee: principal,
    }
    bool
)

(define-map legal-cases
    uint
    {
        case-id: uint,
        client: principal,
        lawyer: principal,
        case-type: (string-ascii 50),
        amount-requested: uint,
        amount-funded: uint,
        case-status: (string-ascii 20),
        created-at: uint,
        urgency-level: uint,
    }
)

(define-data-var case-counter uint u0)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (get-dao-treasury)
    (var-get dao-treasury)
)

(define-read-only (get-member-info (member principal))
    (map-get? dao-members member)
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-legal-case (case-id uint))
    (map-get? legal-cases case-id)
)

(define-read-only (get-vote
        (proposal-id uint)
        (voter principal)
    )
    (map-get? votes {
        proposal-id: proposal-id,
        voter: voter,
    })
)

(define-read-only (is-dao-member (member principal))
    (match (map-get? dao-members member)
        member-data (get is-active member-data)
        false
    )
)

(define-read-only (get-proposal-count)
    (var-get proposal-counter)
)

(define-read-only (get-member-count)
    (var-get member-counter)
)

(define-read-only (get-case-count)
    (var-get case-counter)
)

(define-read-only (get-minimum-stake)
    (var-get minimum-stake)
)

(define-public (join-dao)
    (let (
            (stake-amount (var-get minimum-stake))
            (current-balance (stx-get-balance tx-sender))
        )
        (asserts! (>= current-balance stake-amount) ERR-INSUFFICIENT-FUNDS)
        (asserts! (is-none (map-get? dao-members tx-sender)) ERR-ALREADY-EXISTS)

        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))

        (map-set dao-members tx-sender {
            stake: stake-amount,
            reputation: u100,
            joined-at: stacks-block-height,
            is-active: true,
            is-trustee: false,
        })

        (var-set member-counter (+ (var-get member-counter) u1))
        (var-set dao-treasury (+ (var-get dao-treasury) stake-amount))

        (ok true)
    )
)

(define-public (leave-dao)
    (let (
            (member-data (unwrap! (map-get? dao-members tx-sender) ERR-NOT-FOUND))
            (stake-amount (get stake member-data))
        )
        (asserts! (get is-active member-data) ERR-NOT-FOUND)

        (try! (as-contract (stx-transfer? stake-amount tx-sender tx-sender)))

        (map-delete dao-members tx-sender)
        (var-set member-counter (- (var-get member-counter) u1))
        (var-set dao-treasury (- (var-get dao-treasury) stake-amount))

        (ok true)
    )
)

(define-public (create-funding-proposal
        (title (string-ascii 100))
        (description (string-ascii 500))
        (requested-amount uint)
        (beneficiary principal)
    )
    (let (
            (proposal-id (+ (var-get proposal-counter) u1))
            (current-height stacks-block-height)
            (voting-end (+ current-height (var-get voting-period)))
        )
        (asserts! (is-dao-member tx-sender) ERR-NOT-MEMBER)
        (asserts! (> requested-amount u0) ERR-INVALID-AMOUNT)
        (asserts! (<= requested-amount (var-get dao-treasury))
            ERR-INSUFFICIENT-FUNDS
        )
        (let ((needs-multisig (>= requested-amount (var-get multisig-threshold))))
            (map-set proposals proposal-id {
                proposer: tx-sender,
                title: title,
                description: description,
                requested-amount: requested-amount,
                beneficiary: beneficiary,
                created-at: current-height,
                voting-ends-at: voting-end,
                yes-votes: u0,
                no-votes: u0,
                total-voters: u0,
                executed: false,
                status: "active",
                requires-multisig: needs-multisig,
                approval-count: u0,
            })

            (var-set proposal-counter proposal-id)
            (ok proposal-id)
        )
    )
)

(define-public (vote-on-proposal
        (proposal-id uint)
        (vote-yes bool)
    )
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR-NOT-FOUND))
            (member-data (unwrap! (map-get? dao-members tx-sender) ERR-NOT-MEMBER))
            (current-height stacks-block-height)
        )
        (asserts! (get is-active member-data) ERR-NOT-MEMBER)
        (asserts! (<= current-height (get voting-ends-at proposal))
            ERR-VOTING-ENDED
        )
        (asserts!
            (is-none (map-get? votes {
                proposal-id: proposal-id,
                voter: tx-sender,
            }))
            ERR-ALREADY-VOTED
        )

        (map-set votes {
            proposal-id: proposal-id,
            voter: tx-sender,
        }
            vote-yes
        )

        (map-set proposals proposal-id
            (merge proposal {
                yes-votes: (if vote-yes
                    (+ (get yes-votes proposal) (get stake member-data))
                    (get yes-votes proposal)
                ),
                no-votes: (if vote-yes
                    (get no-votes proposal)
                    (+ (get no-votes proposal) (get stake member-data))
                ),
                total-voters: (+ (get total-voters proposal) u1),
            })
        )

        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR-NOT-FOUND))
            (current-height stacks-block-height)
            (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
            (required-votes (/ (var-get dao-treasury) u2))
        )
        (asserts! (> current-height (get voting-ends-at proposal))
            ERR-PROPOSAL-ACTIVE
        )
        (asserts! (not (get executed proposal)) ERR-ALREADY-EXISTS)
        (asserts! (> (get yes-votes proposal) (get no-votes proposal))
            ERR-PROPOSAL-NOT-PASSED
        )
        (asserts! (>= total-votes required-votes) ERR-INSUFFICIENT-FUNDS)
        (asserts!
            (if (get requires-multisig proposal)
                (>= (get approval-count proposal) (var-get required-approvals))
                true
            )
            ERR-INSUFFICIENT-APPROVALS
        )

        (try! (as-contract (stx-transfer? (get requested-amount proposal) tx-sender
            (get beneficiary proposal)
        )))

        (map-set proposals proposal-id
            (merge proposal {
                executed: true,
                status: "executed",
            })
        )

        (var-set dao-treasury
            (- (var-get dao-treasury) (get requested-amount proposal))
        )
        (ok true)
    )
)

(define-public (create-legal-case
        (client principal)
        (lawyer principal)
        (case-type (string-ascii 50))
        (amount-requested uint)
        (urgency-level uint)
    )
    (let ((case-id (+ (var-get case-counter) u1)))
        (asserts! (is-dao-member tx-sender) ERR-NOT-MEMBER)
        (asserts! (> amount-requested u0) ERR-INVALID-AMOUNT)
        (asserts! (<= urgency-level u5) ERR-INVALID-AMOUNT)

        (map-set legal-cases case-id {
            case-id: case-id,
            client: client,
            lawyer: lawyer,
            case-type: case-type,
            amount-requested: amount-requested,
            amount-funded: u0,
            case-status: "pending",
            created-at: stacks-block-height,
            urgency-level: urgency-level,
        })

        (var-set case-counter case-id)
        (ok case-id)
    )
)

(define-public (fund-legal-case
        (case-id uint)
        (amount uint)
    )
    (let (
            (case-data (unwrap! (map-get? legal-cases case-id) ERR-NOT-FOUND))
            (current-funded (get amount-funded case-data))
            (total-needed (get amount-requested case-data))
        )
        (asserts! (is-dao-member tx-sender) ERR-NOT-MEMBER)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (<= (+ current-funded amount) total-needed) ERR-INVALID-AMOUNT)
        (asserts! (>= (stx-get-balance tx-sender) amount) ERR-INSUFFICIENT-FUNDS)

        (try! (stx-transfer? amount tx-sender (get client case-data)))

        (map-set legal-cases case-id
            (merge case-data {
                amount-funded: (+ current-funded amount),
                case-status: (if (is-eq (+ current-funded amount) total-needed)
                    "fully-funded"
                    "partially-funded"
                ),
            })
        )

        (ok true)
    )
)

(define-public (update-case-status
        (case-id uint)
        (new-status (string-ascii 20))
    )
    (let ((case-data (unwrap! (map-get? legal-cases case-id) ERR-NOT-FOUND)))
        (asserts!
            (or
                (is-eq tx-sender (get lawyer case-data))
                (is-eq tx-sender (get client case-data))
                (is-eq tx-sender (var-get contract-owner))
            )
            ERR-NOT-AUTHORIZED
        )

        (map-set legal-cases case-id
            (merge case-data { case-status: new-status })
        )

        (ok true)
    )
)

(define-public (donate-to-treasury (amount uint))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= (stx-get-balance tx-sender) amount) ERR-INSUFFICIENT-FUNDS)

        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set dao-treasury (+ (var-get dao-treasury) amount))

        (ok true)
    )
)

(define-public (update-member-reputation
        (member principal)
        (new-reputation uint)
    )
    (let ((member-data (unwrap! (map-get? dao-members member) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

        (map-set dao-members member
            (merge member-data { reputation: new-reputation })
        )

        (ok true)
    )
)

(define-public (emergency-withdraw
        (amount uint)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (<= amount (var-get dao-treasury)) ERR-INSUFFICIENT-FUNDS)

        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        (var-set dao-treasury (- (var-get dao-treasury) amount))

        (ok true)
    )
)

(define-public (set-minimum-stake (new-stake uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (> new-stake u0) ERR-INVALID-AMOUNT)

        (var-set minimum-stake new-stake)
        (ok true)
    )
)

(define-public (set-voting-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (> new-period u0) ERR-INVALID-AMOUNT)

        (var-set voting-period new-period)
        (ok true)
    )
)

(define-public (deactivate-member (member principal))
    (let ((member-data (unwrap! (map-get? dao-members member) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active member-data) ERR-NOT-FOUND)

        (map-set dao-members member (merge member-data { is-active: false }))

        (ok true)
    )
)

(define-read-only (calculate-voting-power (member principal))
    (match (map-get? dao-members member)
        member-data (+ (get stake member-data) (/ (get reputation member-data) u10))
        u0
    )
)

(define-read-only (get-proposal-result (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal
        {
            passed: (> (get yes-votes proposal) (get no-votes proposal)),
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal),
            participation: (get total-voters proposal),
        }
        {
            passed: false,
            yes-votes: u0,
            no-votes: u0,
            participation: u0,
        }
    )
)

(define-read-only (get-active-proposals)
    (var-get proposal-counter)
)

(define-read-only (get-member-cases (member principal))
    (var-get case-counter)
)

(define-read-only (get-urgent-cases)
    (var-get case-counter)
)

(define-public (set-trustee
        (member principal)
        (is-trustee-status bool)
    )
    (let ((member-data (unwrap! (map-get? dao-members member) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active member-data) ERR-NOT-MEMBER)

        (map-set dao-members member
            (merge member-data { is-trustee: is-trustee-status })
        )
        (ok true)
    )
)

(define-public (approve-multisig-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR-NOT-FOUND))
            (member-data (unwrap! (map-get? dao-members tx-sender) ERR-NOT-MEMBER))
        )
        (asserts! (get is-active member-data) ERR-NOT-MEMBER)
        (asserts! (get is-trustee member-data) ERR-NOT-TRUSTEE)
        (asserts! (get requires-multisig proposal) ERR-MULTISIG-REQUIRED)
        (asserts!
            (is-none (map-get? multisig-approvals {
                proposal-id: proposal-id,
                trustee: tx-sender,
            }))
            ERR-ALREADY-APPROVED
        )

        (map-set multisig-approvals {
            proposal-id: proposal-id,
            trustee: tx-sender,
        }
            true
        )

        (map-set proposals proposal-id
            (merge proposal { approval-count: (+ (get approval-count proposal) u1) })
        )

        (ok true)
    )
)

(define-public (revoke-multisig-approval (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR-NOT-FOUND))
            (member-data (unwrap! (map-get? dao-members tx-sender) ERR-NOT-MEMBER))
        )
        (asserts! (get is-active member-data) ERR-NOT-MEMBER)
        (asserts! (get is-trustee member-data) ERR-NOT-TRUSTEE)
        (asserts! (get requires-multisig proposal) ERR-MULTISIG-REQUIRED)
        (asserts!
            (is-some (map-get? multisig-approvals {
                proposal-id: proposal-id,
                trustee: tx-sender,
            }))
            ERR-NOT-FOUND
        )

        (map-delete multisig-approvals {
            proposal-id: proposal-id,
            trustee: tx-sender,
        })

        (map-set proposals proposal-id
            (merge proposal { approval-count: (- (get approval-count proposal) u1) })
        )

        (ok true)
    )
)

(define-public (set-multisig-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (> new-threshold u0) ERR-INVALID-AMOUNT)

        (var-set multisig-threshold new-threshold)
        (ok true)
    )
)

(define-public (set-required-approvals (new-count uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (> new-count u0) ERR-INVALID-AMOUNT)

        (var-set required-approvals new-count)
        (ok true)
    )
)

(define-read-only (get-multisig-approval
        (proposal-id uint)
        (trustee principal)
    )
    (map-get? multisig-approvals {
        proposal-id: proposal-id,
        trustee: trustee,
    })
)

(define-read-only (is-trustee (member principal))
    (match (map-get? dao-members member)
        member-data (and (get is-active member-data) (get is-trustee member-data))
        false
    )
)

(define-read-only (get-multisig-settings)
    {
        threshold: (var-get multisig-threshold),
        required-approvals: (var-get required-approvals),
    }
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)
