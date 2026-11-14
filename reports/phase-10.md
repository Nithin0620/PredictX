# Phase 10 — Settlement & Claim Flow

## 1. Phase identity

- Phase: 10 / 20
- Name: Settlement & Claim Flow
- Project part: Contracts → post-finalization user claims and LP settlement

## 2. Scope planned

- 10.1 Implement `redeem()` for the winning outcome at 1 USDC per share.
- 10.2 Support partial redemption and prevent double claims.
- 10.3 Make losing tokens explicitly worthless.
- 10.4 Implement LP settlement after finalization.
- 10.5 Emit `Redeemed` and `LiquiditySettled` events.
- 10.6 Update `isFullyBacked()` for the finalized state.
- 10.7 Tests: winner/loser, partial/double claim, LP settlement, state guards.
- 10.8 Invariant: total payouts never exceed collateral; winning claims stay covered.

## 3. What was done

- **10.1** Replaced the Phase 6 `redeem()` stub with a `Finalized`-only `nonReentrant` function.
  `redeem()` burns the caller's full winning balance and pays exactly 1 USDC per share. The old
  `RedeemNotImplemented` error and stub test expectations were removed.
- **10.2** Added `redeem(uint256 amount)` for partial claims and
  `mapping(address => uint256) public claimed` as a cumulative analytics counter. The winning-token
  burn is the actual double-claim guard; a second claim reverts with
  `ERC20InsufficientBalance`.
- **10.3** Losing tokens are never burned or paid by `redeem()`. A holder of only losing tokens gets
  `ZeroAmount` from `redeem()`, and losing balances remain untouched and worthless.
- **10.4** Added `redeemLiquidity(uint256 lpAmount)`: after finalization it burns LP, burns the
  market's proportional YES/NO reserves, and pays the winning reserve share in USDC. Partial
  settlements are proportional; a full settlement returns the entire winning reserve. Rounding dust
  stays in the pool for remaining LPs. Losing reserve tokens are burned and pay zero.
- **10.5** Added `Redeemed(user, marketId, outcome, shares, payout)` and
  `LiquiditySettled(provider, lpAmount, payout)`. Events are emitted before token burns/transfers
  where required by `forge lint`.
- **10.6** `isFullyBacked()` now has two modes: before finalization it requires equal YES/NO supplies
  and collateral covering YES; after finalization it only requires collateral to cover the
  outstanding winning supply. This keeps backing true as winning tokens are burned and LPs settle.
- **10.7** Added `test/Settlement.t.sol` (12 tests): full/partial redemption, double-claim revert,
  losing-token zero payout, pre-finalization guards, zero amounts, LP winning-reserve payout, NO
  reserve payout, combined trader + LP + treasury claims, partial LP settlement, and no-LP/empty-LP
  guards. Updated `test/Collateral.t.sol` to the real redemption behavior.
- **10.8** Added `test/SettlementInvariant.t.sol` + `test/invariant/SettlementHandler.sol` with random
  winner/treasury redemptions and LP settlements. Four invariants cover payout ≤ collateral at
  finalization, winning claims covered, reserves matching market balances, and LP supply/reserve
  consistency.
- **Size refactor:** the added settlement bytecode pushed `MarketFactory` to 25,429 B, over the
  EIP-170 24,576 B runtime limit. Added `MarketDeployer`, which owns the `PredictionMarket` creation
  bytecode; `MarketFactory` now calls it and stores the deployer. Factory runtime dropped to
  2,590 B; `MarketDeployer` is 23,718 B (858 B margin). `MarketFactory.t.sol` now computes the
  expected market address from the deployer nonce; `MarketDeployer.t.sol` covers the factory-only
  deploy guard and direct deploy path.

## 4. What was skipped / deferred

- Bonded disputes and arbiter finalization — **Phase 12** by design.
- A treasury/admin sweep for rounding dust — intentionally left in the pool; no sweep function.
- Merkle/claim-contract distribution, off-chain claim indexing, and a claim UI — later backend/web
  phases; redemption is direct on-chain.
- No Phase 10 deliverables were cut.

## 5. File changes

| Type     | File                                                      | Change                                                            |
| -------- | --------------------------------------------------------- | ----------------------------------------------------------------- |
| Modified | `packages/contracts/src/PredictionMarket.sol`             | `claimed`, `Redeemed`, `redeem` overloads, LP settlement, backing |
| Added    | `packages/contracts/src/MarketDeployer.sol`               | Factory-only market deployment                                    |
| Modified | `packages/contracts/src/MarketFactory.sol`                | Uses `MarketDeployer`; runtime back under EIP-170                 |
| Added    | `packages/contracts/test/Settlement.t.sol`                | 12 settlement tests                                               |
| Added    | `packages/contracts/test/SettlementInvariant.t.sol`       | Four settlement invariants                                        |
| Added    | `packages/contracts/test/invariant/SettlementHandler.sol` | Random claim/settlement handler                                   |
| Added    | `packages/contracts/test/MarketDeployer.t.sol`            | 2 deployer tests                                                  |
| Modified | `packages/contracts/test/Collateral.t.sol`                | Replaced stub redemption tests                                    |
| Modified | `packages/contracts/test/MarketFactory.t.sol`             | Deployer-based expected address                                   |
| Modified | `docs/amm.md`, `docs/state-machine.md`                    | Settlement formulas, actions, invariants                          |
| Modified | `README.md`, `packages/contracts/README.md`               | Status and test counts                                            |
| Modified | `packages/contracts/.gas-snapshot`                        | Regenerated                                                       |

## 6. Effects / impact

- Winners can claim directly after finalization; no admin action or merkle root is required.
- LPs have a defined post-resolution exit: they receive the winning reserve share and burn the
  worthless losing reserve. Traders and LPs can claim in either order.
- The winning-token burn makes double claims impossible even without a separate claim flag; `claimed`
  is informational and monotonic.
- `isFullyBacked()` remains meaningful after finalization instead of incorrectly requiring equal
  supplies forever.
- The factory/deployer split is a structural change: market creation is now a factory → deployer →
  market call chain. This keeps room for future market bytecode growth.

## 7. Verification

- Tests: **179 / 179** Foundry tests pass, plus 1 env-gated fork test skipped (180 total). New
  Phase 10 suites: 12 `Settlement`, 2 `MarketDeployer`, 1 settlement invariant suite.
- Invariants: settlement suite runs 64 × 32 (2,048 calls); payout bound, winning claims, reserve
  sync, and LP supply consistency all pass.
- Coverage: **96.26%** lines, **88.59%** branches overall; `MarketDeployer` 100%,
  `PredictionMarket` 98.74%, `MarketFactory` 100%.
- Lint/format: `forge lint` clean; `forge fmt --check` clean.
- Gas snapshot: regenerated (180 total tests).
- Sizes: `MarketFactory` 2,590 B (margin 21,986 B); `MarketDeployer` 23,718 B (margin 858 B);
  `PredictionMarket` 13,468 B (margin 11,108 B).
- Monorepo: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm format:check` green with Foundry on
  `PATH`.

## 8. Progress

- Phases complete: **10 / 20** (50%)
- Overall estimate: ~50% done
- Schedule: on track
- Remaining: oracle/disputes (11–13), backend/workers (14–17), web (18–19), hardening/demo (20).

## 9. Blockers & next

- Blockers: none.
- Next: **Phase 11 — Oracle Integration**: Chainlink `AggregatorV3` wrapper, manual resolver,
  stale/incomplete/negative-price guards, decimal normalization, and resolver tests.
