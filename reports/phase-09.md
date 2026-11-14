# Phase 09 — Liquidity Provision & LP Tokens

## 1. Phase identity

- Phase: 09 / 20
- Name: Liquidity Provision & LP Tokens
- Project part: Contracts → LP shares and liquidity exits

## 2. Scope planned

- 9.1 Implement an ERC-20 LP token representing pool shares.
- 9.2 `addLiquidity(usdcAmount)` → split → add YES+NO → mint LP tokens.
- 9.3 `removeLiquidity(lpAmount)` → burn LP → return proportional YES+NO → optionally merge to USDC.
- 9.4 Allow add/remove only while `Active`.
- 9.5 Distribute accrued fees to LPs via reserve growth.
- 9.6 Emit `LiquidityAdded`, `LiquidityRemoved`.
- 9.7 Tests: add/remove round-trip, LP share math, fees accrue to LPs, no dilution attacks.
- 9.8 Invariant: LP redemption never exceeds pool solvency.

## 3. What was done

- **9.1** Added `src/LPToken.sol`: an ERC-20 with 6 decimals, an immutable `market`, market-only
  `mint`/`burn`, zero-address validation, and `TOKEN_KIND = "LP"` for indexers and tooling.
  `PredictionMarket` deploys one `LPToken` per market in its constructor and exposes it via
  `lpToken()`.
- **9.2** `seedLiquidity` now mints `initialLiquidity` LP to the creator, so one LP unit tracks one
  USDC of initial liquidity. Added `addLiquidity(usdcAmount)`: splits the deposit, adds both legs,
  and mints `min(usdcAmount · supply / reserveYes, usdcAmount · supply / reserveNo)` shares. The
  minimum prevents an imbalanced pool from diluting existing LPs. Re-seeding an empty pool mints
  1:1.
- **9.3** Added `removeLiquidity(lpAmount)`: burns LP and returns
  `reserveYes · lpAmount / supply` YES plus the proportional NO. The caller can `merge` the
  complete-set portion to USDC. Removing all shares returns all reserves.
- **9.4** Both functions are `Active`-only and `nonReentrant`; adding after `close()` or before
  `seedLiquidity` reverts with `InvalidState`.
- **9.5** No separate fee pool was added. The LP share of trading fees remains in the reserves, so
  LP shares appreciate through reserve growth. A round-trip trade increases `k`, and a withdrawing
  LP receives more value than the original deposit in the fee-accrual test.
- **9.6** Added `LiquidityAdded(provider, collateral, lpAmount)` and
  `LiquidityRemoved(provider, lpAmount, yesOut, noOut)`. Events are emitted before token
  transfers/mints where lint requires it.
- **9.7** Added `test/Liquidity.t.sol` (11 tests): seed LP mint, proportional add, two-LP
  add/remove, proportional reserves, fee accrual via reserve growth, full exit then re-add,
  outstanding positions after a full LP exit, state guards, and zero-amount reverts. Added
  `test/LPToken.t.sol` (7 tests) for metadata, zero address, mint/burn, and only-market guards.
- **9.8** Added `test/LiquidityInvariant.t.sol` + `test/invariant/LiquidityHandler.sol` with random
  add/remove/merge actions and three invariants: reserves match balances, full backing, and LP
  solvency (zero LP supply iff empty reserves; no phantom LP; proportional redemption).

## 4. What was skipped / deferred

- LP settlement at resolution (LP redeeming its share of remaining collateral after claims) —
  **Phase 10** by design.
- Lockups, withdrawal fees, and a separate reward accounting contract — not required for the
  testnet MVP; reserve growth is the fee mechanism.
- EIP-2612 permit for LP tokens — **Phase 20**.
- No Phase 9 deliverables were cut.

## 5. File changes

| Type     | File                                                     | Lines +/-     |
| -------- | -------------------------------------------------------- | ------------- |
| Added    | `packages/contracts/src/LPToken.sol`                     | +44           |
| Added    | `packages/contracts/test/LPToken.t.sol`                  | +70           |
| Added    | `packages/contracts/test/Liquidity.t.sol`                | +~250         |
| Added    | `packages/contracts/test/LiquidityInvariant.t.sol`       | +90           |
| Added    | `packages/contracts/test/invariant/LiquidityHandler.sol` | +48           |
| Modified | `packages/contracts/src/PredictionMarket.sol`            | +~90 / -2     |
| Modified | `packages/contracts/src/OutcomeToken.sol`                | +3            |
| Modified | `docs/amm.md`                                            | liquidity/API |
| Modified | `docs/state-machine.md`                                  | actions/notes |
| Modified | `packages/contracts/README.md`, `README.md`              | status/counts |
| Modified | `packages/contracts/.gas-snapshot`                       | regenerated   |

## 6. Effects / impact

- Anyone can provide liquidity to an `Active` market and receive a transferable ERC-20 claim on the
  pool. Two LPs can add, trade fees accrue to the pool, and both can exit proportionally.
- LP exits return YES/NO rather than USDC; `merge` converts complete sets to USDC. This keeps the
  collateral accounting exact and avoids a second pricing path.
- Removing all liquidity empties the pool but does not touch outstanding user positions. The market
  remains fully backed and can still be closed/proposed/finalized; Phase 10 will implement claims.
- New risk/tech debt: a fully exited pool cannot be traded until someone adds liquidity again (only
  while `Active`). LP returns are exposed to impermanent loss and to the final outcome; Phase 10's
  LP settlement will define the post-resolution path.

## 7. Verification

- Tests: **127 / 127** Foundry tests pass (124 unit + 3 invariant suites): 8 `MockUSDC`, 14
  `MarketFactory`, 16 `PredictionMarket`, 16 `Collateral`, 7 `OutcomeToken`, 37 `AMM`, 8 `Trading`,
  11 `Liquidity`, 7 `LPToken`, 1 collateral invariant, 1 AMM invariant, 1 liquidity invariant.
- Invariants: 64 runs × 32 depth, 2,048 calls, 0 reverts for the liquidity suite; the AMM and
  collateral suites also pass unchanged.
- Coverage: **96.35%** lines overall; `LPToken` 100%, `PredictionMarket` 98.54%, `AMM` 95.77%,
  `OutcomeToken` / `MockUSDC` / `MarketFactory` 100%; branches 87.38%.
- Lint: `forge lint` clean; `forge fmt --check` clean.
- Gas snapshot: regenerated (127 tests across 12 suites).
- Size: `PredictionMarket` runtime 11,609 B (margin 12,967 B); `MarketFactory` 23,507 B (margin
  1,069 B); `LPToken` 2,247 B.
- Monorepo: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm format:check` green with Foundry on
  `PATH`.

## 8. Progress

- Phases complete: **9 / 20** (45%)
- Overall estimate: ~45% done
- Schedule: on track
- Remaining: settlement (10), oracle/disputes (11–13), backend/workers (14–17), web (18–19),
  hardening/demo (20).

## 9. Blockers & next

- Blockers: none.
- Next: **Phase 10 — Settlement & Claim Flow**: implement `redeem()` for the winning outcome,
  losing-token handling, double-claim protection, LP settlement after resolution, `Redeemed` events,
  and payout/insolvency invariants.
