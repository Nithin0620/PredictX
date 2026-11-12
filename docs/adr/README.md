# Architecture Decision Records (ADRs)

Short, immutable records of the significant decisions behind PredictX. Each file explains the
**context**, the **decision**, the **consequences**, and the **alternatives considered**. If a
decision changes, add a new ADR that supersedes the old one — do not silently rewrite history.

| ADR                                 | Decision                                                             | Status         |
| ----------------------------------- | -------------------------------------------------------------------- | -------------- |
| [0001](0001-chain.md)               | Target chain: **Base Sepolia** (testnet only)                        | Accepted       |
| [0002](0002-tech-stack.md)          | Tech stack: Next.js · Express · Neon Postgres · thirdweb · viem      | Accepted       |
| [0003](0003-token-model.md)         | Outcome model: **ERC-20 YES/NO per market** + LP token, 6 decimals   | Accepted       |
| [0004](0004-pricing-amm.md)         | Pricing: **CPMM (`x·y=k`)** over YES/NO, fully collateralized        | Accepted       |
| [0005](0005-oracle-resolution.md)   | Resolution: **Chainlink price feeds** + manual resolver fallback     | Accepted       |
| [0006](0006-dispute-and-trust.md)   | Disputes: **bonded propose/challenge** + admin arbiter               | Accepted (MVP) |
| [0007](0007-thirdweb-deployment.md) | Contract deploy: **thirdweb CLI** to Base Sepolia; Foundry for tests | Accepted       |

## Template

When adding a new ADR, copy `0000-template.md` (or the structure of an existing one):

```
# ADR NNNN — Title
- Status: Proposed | Accepted | Superseded by NNNN
- Date: YYYY-MM-DD
- Deciders: ...
- Phase: N

## Context
## Decision
## Consequences
## Alternatives considered
## Related
```
