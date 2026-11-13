# Phase 06 — Outcome Tokens & Collateral Vault

## 1. Phase identity

- Phase: 06 / 20
- Name: Outcome Tokens & Collateral Vault
- Project part: Contracts → Collateral & outcome tokens

## 2. Scope planned

- 6.1 Implement `OutcomeToken.sol` (ERC-20; 6 decimals to match USDC).
- 6.2 Deploy two tokens per market (`YES`, `NO`) from `PredictionMarket`.
- 6.3 `split(amount)`: pull USDC → mint `amount` YES + `amount` NO.
- 6.4 `merge(amount)`: burn `amount` YES + `amount` NO → return `amount` USDC.
- 6.5 Enforce `usdc.balanceOf(market) >= totalSupply(YES)`.
- 6.6 Add a `redeem` stub (finalized in Phase 10).
- 6.7 Unit tests: split/merge round-trip, invariant, decimals/overflow edges.
- 6.8 Fuzz the invariant over random split/merge sequences.

## 3. What was done

- **6.1** Added `OutcomeToken`: OpenZeppelin `ERC20`, `DECIMALS = 6`, immutable `market`, and
  `mint`/`burn` restricted to the market (`OnlyMarket`). Zero-market construction is rejected.
- **6.2** `PredictionMarket` now deploys `yesToken` and `noToken` in its constructor with unique
  names/symbols (`PredictX YES #<id>` / `pYES<id>`, same for NO). Used a local `_toString` helper
  because OZ 5.7's `Strings.sol` requires solc `^0.8.31` while the repo is pinned to `0.8.24`.
- **6.3** Added `split(amount)`: `Active`-only, pulls USDC via `SafeERC20.safeTransferFrom`, mints
  an equal YES/NO amount, emits `Split`. Zero amounts revert.
- **6.4** Added `merge(amount)`: allowed from `Active` through `Finalized` (not `Created`), burns
  YES + NO from the caller, returns USDC, emits `Merged`. Zero amounts revert.
- **6.5** Added `isFullyBacked()` and an internal `_split(account, amount)` helper (reused by Phase 7
  seeding). The helper keeps the accounting invariant true by construction.
- **6.6** Added `redeem()` as a `Finalized`-only stub that reverts `RedeemNotImplemented`.
- **6.7** Added 7 `OutcomeToken` tests and 16 `Collateral` tests: round-trip, state gates, zero
  amounts, missing approval/balance, post-close/finalize merge, redeem stub, and fuzzed sequences.
- **6.8** Added a stateful invariant test (`CollateralInvariantTest` + `CollateralHandler`) that runs
  random bounded split/merge sequences and asserts matching supplies and full collateralization.

## 4. What was skipped / deferred

- `redeem()` payout logic — deferred to Phase 10 by design; Phase 6 ships the stub only.
- AMM liquidity seeding via split — deferred to Phase 7; `_split(account, amount)` is ready for it.
- `Disputed` state and bonded disputes — deferred to Phase 12 (unchanged from Phase 5).
- `activate()` replacement with `seedLiquidity()` — deferred to Phase 7.
- None of the Phase 6 deliverables were cut.

## 5. File changes

| Type     | File                                                      | Lines +/- |
| -------- | --------------------------------------------------------- | --------- |
| Added    | `packages/contracts/src/OutcomeToken.sol`                 | +44       |
| Added    | `packages/contracts/test/OutcomeToken.t.sol`              | +70       |
| Added    | `packages/contracts/test/Collateral.t.sol`                | +284      |
| Added    | `packages/contracts/test/CollateralInvariant.t.sol`       | +66       |
| Added    | `packages/contracts/test/invariant/CollateralHandler.sol` | +40       |
| Modified | `packages/contracts/src/PredictionMarket.sol`             | +101 / -0 |
| Modified | `packages/contracts/.gas-snapshot`                        | +46 / -22 |
| Modified | `docs/state-machine.md`                                   | +19 / -3  |
| Modified | `packages/contracts/README.md`                            | +6 / -5   |
| Modified | `README.md`                                               | +7 / -6   |
| Modified | `.husky/pre-commit` (tooling fix)                         | +1 / -1   |

- **Total:** +684 / -37 across 10 files, excluding this report and `reports/PROGRESS.md`.

## 6. Effects / impact

- Every market now has two 6-decimal outcome tokens; `split`/`merge` provide the 1:1 collateral
  on-ramp/off-ramp that the AMM and redemption phases build on.
- `split` is `Active`-only; `merge` stays available through `Finalized`, so complete sets can always
  recover collateral. This is documented in `docs/state-machine.md`.
- `_split` is the intended Phase 7 hook for seeding liquidity (pull creator USDC → mint YES/NO to
  the market/pool).
- `redeem()` always reverts for now; callers must not treat Phase 6 as payout-complete.
- `activate()` remains creator-only until Phase 7 replaces it with `seedLiquidity()`.
- New risk/tech debt: token names/symbols embed the market id; the local `_toString` exists only
  because OZ 5.7 `Strings` needs a newer solc. Revisit if the solc pin moves to `>=0.8.31`.

## 7. Verification

- Tests: **61 / 61** Foundry tests pass (8 `MockUSDC`, 13 `MarketFactory`, 16 `PredictionMarket`,
  16 `Collateral`, 7 `OutcomeToken`, 1 invariant). Monorepo total: **68 tests** (61 contracts + 5
  shared + 2 backend).
- Invariant: 64 runs × 32 depth, 2,048 calls, 0 reverts; `YES`/`NO` supplies match and collateral
  always covers supply.
- Coverage: **93.21%** lines overall; `OutcomeToken` 100%, `PredictionMarket` 98.73%, `MockUSDC`
  and `MarketFactory` 100%. (`script/` is 0% by design.)
- Lint: `forge lint` clean; `forge fmt --check` clean.
- Gas snapshot: regenerated; 60 entries (was 37 test entries in Phase 5).
- CI: not run locally; `pnpm test`, `pnpm typecheck`, and the contracts workspace are green.
- Manual: started Anvil, polled `cast block-number` for readiness, ran
  `forge script script/DeployLocal.s.sol --broadcast`; MockUSDC and MarketFactory deployed at the
  deterministic addresses and factory bytecode is present.

## 8. Progress

- Phases complete: **6 / 20** (30%)
- Overall estimate: ~30% done
- Schedule: on track
- Remaining: AMM (7–8), trading API/indexer (9+), redemption (10), oracle/resolution (11–13),
  backend/workers (14–17), web (18–19), hardening/demo (20).

## 9. Blockers & next

- Blockers: none.
- Next: **Phase 7 — AMM Pricing Engine (CPMM)**, starting with `AMM.sol`, initial liquidity seeding
  via `_split`, quotes, and the `x·y ≥ k` swap invariant.
