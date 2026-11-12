# Phase 04 — Collateral, Factory & Market Registry

## 1. Phase identity

- Phase: 04 / 20
- Name: Collateral, Factory & Market Registry
- Project part: **Contracts / market creation**

## 2. Scope planned

- 4.1 `MockUSDC.sol` — ERC-20, 6 decimals, mint faucet for testers.
- 4.2 `MarketConfig` struct — question, resolution source, deadline, resolver, fee, initial liquidity.
- 4.3 `MarketFactory.sol` — `createMarket(config)` deploys a `PredictionMarket` and registers it.
- 4.4 Sequential `marketId`; `marketId → market address`.
- 4.5 Emit `MarketCreated(marketId, address, creator, question, deadline)`.
- 4.6 Access control: permissionless creation with an anti-spam guard.
- 4.7 Unit tests: creation, ID uniqueness, config validation, event emission.
- 4.8 Deploy script wiring USDC → factory.

## 3. What was done

- 4.1 → `src/MockUSDC.sol`: OpenZeppelin `ERC20` + `Ownable`, `decimals() = 6`, owner `mint`,
  public `faucet()` (10,000 mUSDC per address per day), custom `FaucetCooldownActive` error.
- 4.2 → `src/MarketTypes.sol`: shared `MarketConfig` struct (`question`, `resolutionSource`,
  `deadline`, `resolver`, `feeBps`, `initialLiquidity`).
- 4.3 → `src/MarketFactory.sol`: validates config, deploys a minimal `PredictionMarket`, registers
  it in `marketById`, `marketIdByAddress`, and an enumerable `_markets` array.
- 4.4 → `nextMarketId` starts at 1 and increments; ids are sequential and never reused.
- 4.5 → `MarketCreated(uint256 indexed marketId, address indexed market, address indexed creator,
string question, uint256 deadline)` emitted on every creation.
- 4.6 → Permissionless, with a **60-second per-creator cooldown** plus a **minimum initial
  liquidity** (1 USDC) and fee/length caps as anti-spam/validation guards.
- 4.7 → `test/MockUSDC.t.sol` (8 tests) and `test/MarketFactory.t.sol` (13 tests) covering
  creation, event data, ids, uniqueness, enumeration, cooldown, and every invalid config.
- 4.8 → `script/DeployLocal.s.sol` now deploys `MockUSDC` then `MarketFactory(usdc)` and logs both
  addresses; verified against Anvil.
- **Cleanup / fixes:** removed `Placeholder.sol` + its test (superseded); added `remappings.txt` and
  `.vscode/settings.json` / `extensions.json` so editors resolve `@openzeppelin` / `forge-std`
  imports; fixed Foundry linter diagnostics (zero-address checks; justified inline suppressions for
  `block-timestamp` and `reentrancy-events`).
- `src/PredictionMarket.sol`: minimal immutable metadata contract (id, factory, creator, collateral,
  question, source, deadline, resolver, fee, initial liquidity) — state machine is Phase 5.

## 4. What was skipped / deferred

- **Initial liquidity is validated and stored, not escrowed.** Pulling USDC and minting YES/NO
  belongs to Phase 6 (`split`) and Phase 7 (liquidity seeding).
- **No real trading / AMM / tokens** — Phase 6–8.
- **No oracle or dispute wiring** — Phase 11–12.
- **No factory admin / configurable cooldown or fee** — constants for now; revisit in Phase 13.
- **No clone/proxy factory** — deploy-per-market accepted for MVP (gas noted as a risk).
- **No thirdweb testnet deployment** — Phase 20; ADR 0007 documents the path.
- **Solidity linter (Solhint/Slither)** — Phase 13; `forge fmt` + `forge lint` are green now.

## 5. File changes

> Phase 2/3 files are still untracked, so `git diff --stat` is not meaningful; counts are `wc -l`.
> `packages/contracts/lib/` (dependencies) is ignored and excluded.

| Type     | File                                                           | Lines     |
| -------- | -------------------------------------------------------------- | --------- |
| Added    | `packages/contracts/src/MarketTypes.sol`                       | 21        |
| Added    | `packages/contracts/src/MockUSDC.sol`                          | 49        |
| Added    | `packages/contracts/src/PredictionMarket.sol`                  | 65        |
| Added    | `packages/contracts/src/MarketFactory.sol`                     | 124       |
| Added    | `packages/contracts/test/MockUSDC.t.sol`                       | 87        |
| Added    | `packages/contracts/test/MarketFactory.t.sol`                  | 208       |
| Added    | `packages/contracts/remappings.txt`                            | 2         |
| Added    | `.vscode/settings.json`                                        | 13        |
| Added    | `.vscode/extensions.json`                                      | 3         |
| Modified | `packages/contracts/script/DeployLocal.s.sol` (USDC + factory) | 31        |
| Modified | `packages/contracts/README.md` (Phase 4 status/commands)       | 77        |
| Modified | `packages/contracts/.gas-snapshot` (21 tests)                  | 20        |
| Modified | `packages/shared/src/types.ts` (+`resolutionSource`)           | 39        |
| Modified | `README.md` (Phase 4 status + local flow)                      | 111       |
| Added    | `reports/phase-04.md`                                          | this file |
| Modified | `reports/PROGRESS.md`                                          | +2 / -1   |
| Removed  | `packages/contracts/src/Placeholder.sol`                       | -24       |
| Removed  | `packages/contracts/test/Placeholder.t.sol`                    | -33       |

- **Total touched (excluding ignored `lib/`):** ~861 lines across 17 files (+ this report), minus 57
  removed placeholder lines.

## 6. Effects / impact

- Markets can now be created on-chain permissionlessly with validated configs and sequential ids.
- The factory is the single source of truth for market addresses and ordering; indexers can
  enumerate via `marketCount()` / `marketAt()` / `getMarkets()` and the `MarketCreated` event.
- A testnet collateral token exists (`mUSDC`, 6 decimals) with a public faucet for demos.
- Every market stores immutable metadata (question, source, deadline, resolver, fee, liquidity),
  ready for the Phase 5 state machine and Phase 6 token vault.
- Editor/import resolution is fixed via `remappings.txt` + VS Code settings.
- Foundry build/lint output is clean (no warnings).

## 7. Verification

- `forge build` → ✅ compiled with Solc 0.8.24, **no warnings**.
- `forge test -vv` → ✅ **21/21 passed** (8 MockUSDC + 13 MarketFactory).
- `forge fmt --check` → ✅ clean; `forge lint` → ✅ no diagnostics.
- `forge snapshot` → ✅ 21-entry `.gas-snapshot` baseline.
- Anvil smoke test → ✅ deployed `MockUSDC` at
  `0x5FbDB2315678afecb367f032d93F642f64180aa3` and `MarketFactory` at
  `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`; `decimals() = 6`, `symbol() = "mUSDC"`,
  `factory.usdc()` → MockUSDC, `marketCount() = 0`.
- Root pipeline → ✅ `pnpm lint`, `pnpm format:check`, `pnpm typecheck`, `pnpm build`, `pnpm test`.
- Total tests now: **28** (5 shared + 2 backend + 21 contracts).

## 8. Progress

- Phases complete: **4 / 20 (20%)**
- Overall estimate: **~18%** (collateral + factory + registry; no market logic yet).
- Schedule: **on track** (Phase 4 scoped at 3–4 days).
- Remaining: Phase 5 (state machine) through Phase 20 (deploy/launch).

## 9. Blockers & next

- **Operational:** contract deps remain git-ignored; run `make contracts-deps` on a fresh clone/CI.
- No blocking bugs. Repo changes remain **uncommitted** (per project rule).
- Next phase: **Phase 5 — Market Lifecycle State Machine** (states, guards, close/propose entry
  points, transition test matrix, `docs/state-machine.md`).
