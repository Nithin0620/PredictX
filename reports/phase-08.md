# Phase 08 — Trading Engine (fees, slippage, events)

## 1. Phase identity

- Phase: 08 / 20
- Name: Trading Engine (fees, slippage, events)
- Project part: Contracts → User-facing buy/sell

## 2. Scope planned

- 8.1 Implement `buy(outcome, collateralIn, minSharesOut, deadline)`.
- 8.2 Implement `sell(outcome, sharesIn, minCollateralOut, deadline)`.
- 8.3 Add slippage protection via `min/max` params + deadline (revert on violation).
- 8.4 Route fees: LP share + protocol treasury share; emit fee events.
- 8.5 Emit canonical `Trade(user, market, outcome, side, shares, collateral, fee, price)`.
- 8.6 Add reentrancy guards + checks-effects-interactions ordering.
- 8.7 Keep the ERC-20 approval flow (user approves USDC/outcome tokens to the market).
- 8.8 Integration tests: buy→sell round-trip, slippage reverts, fee math, event contents.
- 8.9 Gas snapshot of buy/sell.

## 3. What was done

- **8.1/8.2** Replaced the Phase 7 `buy(outcome, collateralIn)` / `sell(outcome, sharesIn)` entry
  points with deadline- and slippage-bounded versions:
  - `buy(Outcome outcome, uint256 collateralIn, uint256 minSharesOut, uint256 deadline)`
  - `sell(Outcome outcome, uint256 sharesIn, uint256 minCollateralOut, uint256 deadline)`
  - Added `DeadlineExpired(uint256 deadline)` and
    `SlippageExceeded(uint256 actual, uint256 minimum)`.
- **8.3** Both entry points reject `block.timestamp > deadline` before touching state and revert if
  the actual output is below the caller's bound. Sell also rejects a zero collateral output.
- **8.4** Added `PROTOCOL_FEE_SHARE_BPS = 2_000` (20%). The AMM still takes the full output fee;
  the protocol share is removed from the fee-outcome reserve and transferred to `treasury` in that
  outcome token. The remaining 80% (LP share) stays in the pool. The `ProtocolFee` event records
  the transfer. `MarketFactory` now takes an immutable `treasury` in its constructor and passes it
  to each market.
- **8.5** Added the canonical `Trade` event and `TradeSide { Buy, Sell }`. `Trade.fee` is a
  USDC-valued estimate using the pre-trade implied probability; `Trade.price` is the post-trade WAD
  probability. `Trade`/`ProtocolFee` are emitted before external token transfers.
- **8.6** `PredictionMarket` now inherits OpenZeppelin `ReentrancyGuard`; `seedLiquidity`, `split`,
  `merge`, `buy`, `sell`, `addLiquidity`, and `removeLiquidity` are `nonReentrant`. Buy/sell update
  reserves and emit events before splitting/transferring tokens (CEI).
- **8.7** The approval flow is unchanged: the market pulls USDC with `safeTransferFrom` on buy and
  pulls the sold outcome token on sell. EIP-2612 permit remains Phase 20.
- **8.8** Added `test/Trading.t.sol` (8 tests): buy/sell slippage reverts, deadline reverts,
  protocol fee routing on both sides, and `Trade` event contents. Updated `AMM.t.sol` with
  `_buy`/`_sell` helpers and protocol-fee-aware reserve assertions. Added the factory zero-treasury
  revert test.
- **8.9** Regenerated `packages/contracts/.gas-snapshot` after the new tests and entry points.

## 4. What was skipped / deferred

- EIP-2612 permit approvals — **Phase 20** by design.
- LP token and add/remove liquidity — **Phase 9** (implemented immediately after this phase).
- Redemption and LP settlement — **Phase 10**.
- No Phase 8 deliverables were cut.

## 5. File changes

| Type     | File                                               | Lines +/-                       |
| -------- | -------------------------------------------------- | ------------------------------- |
| Added    | `packages/contracts/test/Trading.t.sol`            | +~180                           |
| Modified | `packages/contracts/src/PredictionMarket.sol`      | +~150 / -30 (Phase 8 portion)   |
| Modified | `packages/contracts/src/MarketFactory.sol`         | +13 / -3                        |
| Modified | `packages/contracts/src/MarketTypes.sol`           | +6                              |
| Modified | `packages/contracts/test/AMM.t.sol`                | +~35 / -20 (helpers/assertions) |
| Modified | `packages/contracts/test/MarketFactory.t.sol`      | +10 / -2                        |
| Modified | `packages/contracts/test/invariant/AMMHandler.sol` | +4 / -4                         |
| Modified | `packages/contracts/script/DeployLocal.s.sol`      | +1 / -1                         |
| Modified | `docs/amm.md`                                      | fee/API sections                |
| Modified | `docs/state-machine.md`                            | actions/notes                   |
| Modified | `packages/contracts/README.md`, `README.md`        | status/test counts              |
| Modified | `packages/contracts/.gas-snapshot`                 | regenerated                     |

- Phase 6/7 files were already uncommitted, so the counts above are incremental portions.

## 6. Effects / impact

- Trades are now safe to submit from a UI: stale transactions and unfavorable price moves revert
  with explicit errors instead of silently filling.
- Fee value is split without a separate accounting contract. The treasury receives outcome tokens,
  so it can merge or redeem them later; LPs earn through reserve growth.
- All trading state changes emit an indexable event (`Trade`, `ProtocolFee`), which the Phase 14
  indexer can consume.
- Reentrancy is guarded and the buy/sell paths follow checks-effects-interactions ordering. The
  only external calls before events are trusted token operations in `split`/`merge`, which are
  themselves guarded.
- New risk/tech debt: the treasury receives volatile outcome tokens rather than USDC; this is
  intentional for testnet simplicity and can be swapped/merged by the treasury. Fee valuation in
  `Trade` is an estimate, not a guaranteed execution price.

## 7. Verification

- Tests: **127 / 127** Foundry tests pass at the end of Phase 9, including the 8 Phase 8
  `Trading.t.sol` tests: 8 `MockUSDC`, 14 `MarketFactory`, 16 `PredictionMarket`, 16 `Collateral`,
  7 `OutcomeToken`, 37 `AMM`, 8 `Trading`, 11 `Liquidity`, 7 `LPToken`, and 3 invariant suites.
- Invariants: 64 runs × 32 depth, 2,048 calls, 0 reverts for the AMM, collateral, and liquidity
  suites.
- Coverage: **96.35%** lines overall; `PredictionMarket` 98.54%, `AMM` 95.77%, `LPToken` /
  `OutcomeToken` / `MockUSDC` / `MarketFactory` 100%.
- Lint: `forge lint` clean; `forge fmt --check` clean.
- Gas snapshot: regenerated (127 tests across 12 suites).
- Size: `PredictionMarket` runtime 11,609 B (margin 12,967 B); `MarketFactory` 23,507 B (margin
  1,069 B).
- Monorepo: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm format:check` green with Foundry on
  `PATH`.

## 8. Progress

- Phases complete: **8 / 20** (40%)
- Overall estimate: ~40% done at the end of this phase
- Schedule: on track
- Remaining: LP tokens (9), settlement (10), oracle/disputes (11–13), backend/workers (14–17),
  web (18–19), hardening/demo (20).

## 9. Blockers & next

- Blockers: none.
- Next: **Phase 9 — Liquidity Provision & LP Tokens**: add the per-market `LPToken`, mint at
  seeding, `addLiquidity`/`removeLiquidity`, LP fee accrual via reserve growth, events, tests, and
  the LP-solvency invariant.
