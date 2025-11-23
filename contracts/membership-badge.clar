(define-constant ERR-NOT-MEMBER (err u200))
(define-constant ERR-ALREADY-OWNED (err u201))
(define-constant ERR-NON-TRANSFERABLE (err u202))
(define-constant ERR-NOT-AUTHORIZED (err u203))

(define-data-var contract-owner principal tx-sender)
(define-data-var dao-contract principal tx-sender)
(define-data-var next-token-id uint u0)
(define-data-var total-supply uint u0)

(define-map token-owners
  uint
  principal
)
(define-map owner-token
  principal
  uint
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-dao-contract)
  (var-get dao-contract)
)

(define-read-only (get-total-supply)
  (var-get total-supply)
)

(define-read-only (get-token-owner (token-id uint))
  (map-get? token-owners token-id)
)

(define-read-only (get-owner-token (owner principal))
  (map-get? owner-token owner)
)

(define-read-only (owns (owner principal))
  (is-some (map-get? owner-token owner))
)

(define-public (set-dao-contract (dao principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set dao-contract dao)
    (ok true)
  )
)

(define-public (mint)
  (let ((already (map-get? owner-token tx-sender)))
    (asserts! (contract-call? .Legal-Aid-Funding-DAO is-dao-member tx-sender)
      ERR-NOT-MEMBER
    )
    (asserts! (is-none already) ERR-ALREADY-OWNED)
    (let ((new-id (+ (var-get next-token-id) u1)))
      (map-set token-owners new-id tx-sender)
      (map-set owner-token tx-sender new-id)
      (var-set next-token-id new-id)
      (var-set total-supply (+ (var-get total-supply) u1))
      (ok new-id)
    )
  )
)

(define-public (transfer
    (token-id uint)
    (recipient principal)
  )
  (begin
    (asserts! false ERR-NON-TRANSFERABLE)
    (ok false)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
