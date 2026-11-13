# Phase 07 — AMM Pricing Engine (CPMM)

## 1. Phase identity

- Phase: 07 / 20
- Name: AMM Pricing Engine (CPMM)
- Project part: Contracts → Pricing & swaps

## 2. Scope planned

- 7.1 Implement `AMM.sol` (library) holding YES/NO reserves and pricing math.
- 7.2 Seed initial liquidity from market creation (split initial USDC → YES+NO into the pool).
- 7.3 Implement `getAmountOut(reserveIn, reserveOut, amountIn)` with a configurable fee.
- 7.4 Implement `quoteBuy(outcome, collateralIn)` and `quoteSell(outcome, sharesIn)` views.
- 7.5 Implement the swap primitive: buy = split collateral → add opposite token → send wanted token.
- 7.6 Enforce `x·y ≥ k` after every swap with fee accounting.
- 7.7 Track reserves; expose `getReserves()` and `priceYes`.
- 7.8 Unit tests: price monotonicity, no free money, fee accrual, edge reserves.
- 7.9 Fuzz/invariant tests: `k` never decreases; pool always fully backed.

## 3. What was done

- **7.1** Added `src/AMM.sol`: a pure library with a `Pool { reserveYes, reserveNo }` struct,
  `getAmountOut`, `quoteBuy`, `quoteSell`, `applyBuy`, `applySell`, a quadratic `_solveSell`, and a
  local Babylonian `sqrt`. OZ 5.7 `Math.sqrt` requires solc `^0.8.31`, so the repo's `0.8.24` pin
  needed a local implementation.
- **7.2** Replaced the temporary `activate()` with creator-only `seedLiquidity()`: pulls
  `initialLiquidity` USDC, calls the existing `_split(address(this), amount)`, deposits both legs at
  50/50, then moves `Created → Active`. Emits `LiquiditySeeded` and `MarketActivated`.
- **7.3** `getAmountOut` uses `grossOut = floor(amountIn·reserveOut/(reserveIn+amountIn))` and a
  **ceil-rounded** fee taken from the output. Rounding favors the pool; the fee is clamped to
  `grossOut` for extreme fee settings.
- **7.4** Added `quoteBuy` and `quoteSell` views; both validate zero amounts/`Unresolved` and return
  `(amountOut, fee)`. They are pure wrappers over the same `applyBuy`/`applySell` used by execution,
  so quotes match trades exactly.
- **7.5** Added `buy(outcome, collateralIn)` and `sell(outcome, sharesIn)`, both `Active`-only:
  - Buy splits the collateral to the market, adds the opposite leg to the pool, and sends the user
    `collateralIn + swappedOut` of the desired outcome.
  - Sell solves the fee-adjusted quadratic for the merged amount `n`, transfers the sold outcome in,
    swaps the remainder, burns `n` YES + `n` NO, and pays `n` USDC.
- **7.6** Fees stay in the pool, so `k` is non-decreasing. The sell path clamps `n` to `gross` if
  integer rounding would otherwise make the fee negative.
- **7.7** Added `getReserves()` and `priceYes()` (WAD, `1e18 = 100%`). `priceYes` reverts
  `AMM.InsufficientLiquidity` before seeding.
- **7.8** Added 37 `AMM.t.sol` tests: seeding, exact `getAmountOut` formula, buy/sell price
  monotonicity, quote/execution equality, fee accrual, round-trip loss, repeated trades, reserve/
  balance sync, both outcomes, library edge cases via `AMMHarness`, and all guard/zero/empty-pool/
  approval revert paths.
- **7.9** Added `AMMInvariant.t.sol` + `invariant/AMMHandler.sol` (random buy/sell/split/merge) and
  four invariants: `k` never decreases, reserves match market token balances, full backing, and
  `0 < priceYes < 1e18`.

## 4. What was skipped / deferred

- Slippage (`minSharesOut`/`minCollateralOut`), deadline, canonical `Trade` events, fee routing to
  LPs/treasury, and a reentrancy guard — **Phase 8** by design. Current `buy`/`sell` signatures are
  not final.
- LP token and add/remove-liquidity — **Phase 9**.
- Redemption payouts — **Phase 10**.
- EIP-2612 permit approvals — **Phase 20**.
- No Phase 7 deliverables were cut.

## 5. File changes

| Type     | File                                                | Lines +/-                            |
| -------- | --------------------------------------------------- | ------------------------------------ |
| Added    | `packages/contracts/src/AMM.sol`                    | +170                                 |
| Added    | `packages/contracts/test/AMM.t.sol`                 | +475                                 |
| Added    | `packages/contracts/test/AMMInvariant.t.sol`        | +90                                  |
| Added    | `packages/contracts/test/invariant/AMMHandler.sol`  | +69                                  |
| Added    | `packages/contracts/test/utils/AMMHarness.sol`      | +36                                  |
| Added    | `docs/amm.md`                                       | +138                                 |
| Modified | `packages/contracts/src/PredictionMarket.sol`       | +~120 / -8 (Phase 7 portion)         |
| Modified | `packages/contracts/test/PredictionMarket.t.sol`    | +26 / -11                            |
| Modified | `packages/contracts/test/Collateral.t.sol`          | +~15 / -8 (seeding setup/assertions) |
| Modified | `packages/contracts/test/CollateralInvariant.t.sol` | +5 / -2                              |
| Modified | `docs/state-machine.md`                             | +~30 / -15 (Phase 7 portion)         |
| Modified | `packages/contracts/README.md`                      | +11 / -5                             |
| Modified | `README.md`                                         | +8 / -6                              |
| Modified | `packages/contracts/.gas-snapshot`                  | regenerated                          |

- `PredictionMarket.sol` and `Collateral*.t.sol` were already uncommitted from Phase 6, so the
  Phase 7 line counts above are the incremental portions.

## 6. Effects / impact

- Markets now start at a 50/50 CPMM price and can be traded end-to-end on-chain:
  `seedLiquidity → buy/sell → close → propose → finalize`.
- `activate()` is gone; a market cannot become `Active` without depositing collateral, removing the
  old "active but empty" state.
- The pool is always solvent and fully backed: reserves equal token balances, supplies match, and
  collateral covers the outstanding YES supply. Verified by the stateful invariant.
- Fees increase `k` rather than leaving the pool; Phase 8 will split them between LPs and treasury.
  Until then, `quoteBuy`/`quoteSell` expose the fee so callers can account for it.
- `priceYes` is a WAD probability for the future frontend/indexer; it is not a price oracle and
  reverts on an empty pool.
- New risk/tech debt: no slippage/deadline yet (Phase 8), no reentrancy guard yet (trusted
  MockUSDC/OutcomeToken have no hooks), and no LP accounting (Phase 9). Sell math uses a local
  quadratic/sqrt because of the solc pin; revisit if the pin moves to `>=0.8.31`.

## 7. Verification

- Tests: **99 / 99** Foundry tests pass (97 unit tests + 2 invariant suites): 8 `MockUSDC`,
  13 `MarketFactory`, 16 `PredictionMarket`, 16 `Collateral`, 7 `OutcomeToken`, 37 `AMM`,
  1 collateral invariant, 1 AMM invariant.
- Invariants: 64 runs × 32 depth, 2,048 calls, 0 reverts for both suites. `k` never decreases,
  reserves match balances, supplies match, collateral covers supply, and price stays in `(0, 1)`.
- Coverage: **95.68%** lines overall; `PredictionMarket` 99.21%, `OutcomeToken` / `MockUSDC` /
  `MarketFactory` 100%, `AMM` 95.77% (branches 90%).
- Lint: `forge lint` clean; `forge fmt --check` clean.
- Gas snapshot: regenerated; 97 unit-test entries + 5 invariant entries.
- Size: `PredictionMarket` runtime 8,041 B (margin 16,535 B); `MarketFactory` 16,241 B.
- Monorepo: `pnpm test`, `pnpm typecheck`, `pnpm lint`, `pnpm format:check` green.
- Manual: Anvil deploy re-verified after the changes.

## 8. Progress

- Phases complete: **7 / 20** (35%)
- Overall estimate: ~35% done
- Schedule: on track
- Remaining: trading engine (8), LP tokens (9), settlement (10), oracle/disputes (11–13),
  backend/workers (14–17), web (18–19), hardening/demo (20).

## 9. Blockers & next

- Blockers: none.
- Next: **Phase 8 — Trading Engine (fees, slippage, events)**: add
  `buy(outcome, collateralIn, minSharesOut, deadline)` and
  `sell(outcome, sharesIn, minCollateralOut, deadline)`, route LP/protocol fees, emit the canonical
  `Trade` event, add a reentrancy guard, and extend integration/gas tests.
