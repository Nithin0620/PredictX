# ADR 0001 — Target chain: Base Sepolia

- **Status:** Accepted
- **Date:** 2026-11-12
- **Deciders:** Project author
- **Phase:** 1

## Context

PredictX needs an EVM chain that is:

- Cheap and fast enough to deploy a contract **per market** and trade frequently.
- Supported by **Chainlink price feeds** (core to objective market resolution).
- Supported by **thirdweb** (deployment CLI + frontend SDK).
- Observable on a block explorer for verification and demos.
- Strictly a **testnet**, because real-money prediction markets have regulatory and safety
  implications we are deliberately avoiding.

## Decision

Use **Base Sepolia** (chain ID `84532`) as the only target chain for the project.

- Deploy top-level contracts (`MockUSDC`, `MarketFactory`, `OracleResolver`, `DisputeManager`)
  via the **thirdweb CLI**.
- Verify on **Basescan** (Sepolia).
- Read/write from the frontend via **thirdweb SDK**; index events from the backend via **viem**.
- Use Chainlink feeds available on Base Sepolia for objective markets.
- Local development runs on **Anvil**, optionally forked from Base Sepolia to exercise real feeds.

## Consequences

**Positive**

- Very low gas → per-market contract deployment is economically fine on testnet.
- Strong tooling: thirdweb, viem, Foundry, Basescan all support Base Sepolia.
- Chainlink feeds exist, so oracle resolution is realistic, not simulated.
- EVM-equivalent → all standard Solidity/OpenZeppelin patterns apply.

**Negative / trade-offs**

- Base-specific RPC quirks and occasional testnet instability.
- Chainlink feed addresses must be tracked per network (stored in `packages/shared`).
- Testnet tokens have no value, so some incentive/UX behaviors differ from mainnet.

## Alternatives considered

| Option           | Why rejected                                                             |
| ---------------- | ------------------------------------------------------------------------ |
| Ethereum Sepolia | Higher gas, slower blocks, more expensive per-market deploys.            |
| Polygon Amoy     | Viable, but weaker default Chainlink feed coverage for our target pairs. |
| Arbitrum Sepolia | Viable; Base chosen for ecosystem fit with thirdweb + Coinbase tooling.  |
| Local Anvil only | No real oracle feeds, no public demo, no explorer.                       |
| Mainnet          | Out of scope: real money, regulation, and safety risk.                   |

## Related

- `PROJECT_PLAN.md` §3 Scope, §5 Technology stack, §14 Deployment topology
- `PHASES.md` Phase 3, Phase 11, Phase 20
- ADR 0005 (oracle resolution), ADR 0002 (tech stack)
