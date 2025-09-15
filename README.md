# Legal Aid Funding DAO ⚖️💰

A decentralized autonomous organization (DAO) for funding legal aid cases, built on the Stacks blockchain using Clarity smart contracts.

## Overview 📋

This smart contract enables a community-driven approach to funding legal aid cases. Members can stake STX tokens to join the DAO, propose funding for legal cases, vote on proposals, and track case progress.

## Features ✨

- 🏛️ **DAO Membership**: Stake-based membership system with reputation scoring
- 📊 **Proposal System**: Create and vote on funding proposals for legal cases
- ⚖️ **Legal Case Management**: Track legal cases from creation to completion
- 💰 **Treasury Management**: Community-controlled fund allocation
- 🔐 **Access Control**: Role-based permissions for different actions
- 🚨 **Urgency Levels**: Priority system for critical legal cases

## Getting Started 🚀

### Prerequisites
- Clarinet CLI installed
- Stacks wallet with STX tokens

### Installation
```bash
git clone <repository-url>
cd Legal-Aid-Funding-DAO
clarinet check
```

## Usage 💡

### Joining the DAO
```clarity
(contract-call? .Legal-Aid-Funding-DAO join-dao)
```
Stake the minimum required STX to become a DAO member.

### Creating Funding Proposals
```clarity
(contract-call? .Legal-Aid-Funding-DAO create-funding-proposal 
  "Emergency Housing Legal Aid" 
  "Funding needed for eviction defense case"
  u5000000 
  'SP1ABC...RECIPIENT)
```

### Voting on Proposals
```clarity
(contract-call? .Legal-Aid-Funding-DAO vote-on-proposal u1 true)
```

### Creating Legal Cases
```clarity
(contract-call? .Legal-Aid-Funding-DAO create-legal-case
  'SP1CLIENT...
  'SP1LAWYER...
  "Housing Rights"
  u3000000
  u4)
```

### Funding Legal Cases
```clarity
(contract-call? .Legal-Aid-Funding-DAO fund-legal-case u1 u1000000)
```

## Contract Functions 🛠️

### Public Functions
- `join-dao()` - Join the DAO by staking minimum STX
- `leave-dao()` - Leave the DAO and retrieve stake
- `create-funding-proposal()` - Submit new funding proposal
- `vote-on-proposal()` - Vote yes/no on proposals
- `execute-proposal()` - Execute passed proposals
- `create-legal-case()` - Register new legal case
- `fund-legal-case()` - Fund existing legal cases
- `donate-to-treasury()` - Donate STX to DAO treasury

### Read-Only Functions
- `get-member-info()` - Get member details and reputation
- `get-proposal()` - Get proposal information
- `get-legal-case()` - Get legal case details
- `is-dao-member()` - Check if address is DAO member
- `get-dao-treasury()` - Get current treasury balance
- `calculate-voting-power()` - Calculate member's voting weight

## Governance 🗳️

- **Voting Period**: 1008 blocks (~1 week)
- **Minimum Stake**: 1,000,000 microSTX (1 STX)
- **Voting Power**: Stake amount + reputation/10
- **Proposal Threshold**: 50% of treasury for quorum

## Case Categories ⚖️

Legal cases are categorized by type and urgency:
- **Case Types**: Housing Rights, Immigration, Family Law, Criminal Defense, Civil Rights
- **Urgency Levels**: 1 (Low) to 5 (Critical Emergency)

## Treasury Management 💎

- Members contribute through staking and donations
- Funds allocated through democratic voting process
- Emergency withdrawal function for contract owner
- Transparent fund tracking and allocation

## Testing 🧪

```bash
npm install
npm test
```


## Security Considerations 🔒

- Contract owner has emergency functions only
- All fund transfers require multi-signature validation
- Member reputation system prevents abuse
- Time-locked voting prevents rushed decisions

## License 📄

MIT License - see LICENSE file for details.
