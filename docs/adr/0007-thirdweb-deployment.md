# ADR 0007 — Contract deployment via thirdweb CLI

- **Status:** Accepted
- **Date:** 2026-11-12
- **Deciders:** Project author
- **Phase:** 3

## Context

We need a repeatable way to deploy the PredictX contracts to **Base Sepolia** and verify them, while
keeping **Foundry** as the source of truth for local development, fuzzing, and invariant tests. The
frontend already uses the thirdweb SDK, so using thirdweb for deployment keeps the toolchain
consistent.

## Decision

- **Testing & local deploys:** Foundry (`forge build`, `forge test`, `forge script`).
- **Testnet deployment:** **thirdweb CLI** (`npx thirdweb deploy`).
- **Verification:** Basescan (via thirdweb or `forge verify-contract`).
- **Only top-level contracts are deployed via thirdweb:**
  - `MockUSDC`
  - `MarketFactory`
  - `OracleResolver`
  - `DisputeManager`
  - Per-market `PredictionMarket` + YES/NO tokens are deployed **by the factory at runtime**, not
    by thirdweb.

## Usage (once contracts exist in Phase 4+)

```bash
# from packages/contracts
npx thirdweb deploy
# select the contract, provide constructor args, choose Base Sepolia (84532), deploy
```

Environment used by the CLI / SDK:

```bash
NEXT_PUBLIC_THIRDWEB_CLIENT_ID=...
THIRDWEB_SECRET_KEY=...
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
```

After deploying, copy the addresses into `.env` / `packages/shared`:

```
NEXT_PUBLIC_USDC_ADDRESS=0x...
NEXT_PUBLIC_MARKET_FACTORY_ADDRESS=0x...
NEXT_PUBLIC_ORACLE_RESOLVER_ADDRESS=0x...
```

## Consequences

**Positive**

- One ecosystem for frontend wallet/reads/writes and deployment.
- No need to manage private keys in a custom deploy script for testnet.
- Basescan verification is straightforward.
- Foundry still gives fast, high-signal local tests.

**Negative / trade-offs**

- thirdweb CLI may require login / a client id; adds a vendor dependency.
- Constructor-argument-heavy deployments are easier to get wrong in a UI than in a script.
- Multi-contract wiring (e.g. factory → resolver) still needs a script or manual steps; Foundry
  scripts remain the fallback.

## Alternatives considered

| Option                                  | Why rejected                                                            |
| --------------------------------------- | ----------------------------------------------------------------------- |
| Foundry `forge script --broadcast` only | Works, but the author chose thirdweb for consistency with the frontend. |
| Hardhat deploy plugins                  | We are not using Hardhat.                                               |
| Manual Remix deployment                 | Not reproducible, no CI story.                                          |
| Ignition (Hardhat)                      | Same as above.                                                          |

## Guardrails

- **Testnet only.** Never deploy these contracts to mainnet for this project.
- Keep Foundry deploy scripts (`script/DeployLocal.s.sol` and later testnet scripts) in sync with
  what thirdweb deploys, so local and testnet setups match.
- Record every deployed address in `packages/shared` and in `reports/phase-XX.md`.

## Related

- `PROJECT_PLAN.md` §5 (stack), §14 (deployment topology)
- `PHASES.md` Phase 3, Phase 20
- `docs/adr/0002-tech-stack.md`
