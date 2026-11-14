# Phase 11 — Oracle Integration

## 1. Phase identity

- Phase: 11 / 20
- Name: Oracle Integration
- Project part: Contracts → Chainlink price resolution and manual fallback

## 2. Scope planned

- 11.1 Add a minimal `AggregatorV3Interface`.
- 11.2 Implement `OracleResolver` for price-threshold markets.
- 11.3 Validate stale, incomplete, future, and non-positive feed rounds.
- 11.4 Normalize feed decimals to WAD and support comparators.
- 11.5 Implement `ManualResolver` for non-price markets.
- 11.6 Wire resolution through `proposeOutcome` without paying users directly.
- 11.7 Tests: comparators, guards, decimals, non-resolver, state transitions.
- 11.8 Optional Base Sepolia fork test against a live Chainlink feed.

## 3. What was done

- **11.1** Added `src/interfaces/IAggregatorV3.sol` with the `latestRoundData`,
  `getRoundData`, `decimals`, `description`, and `version` functions.
- **11.2** Added `src/OracleResolver.sol`. One resolver instance stores an immutable feed,
  comparator, WAD threshold, and `maxStaleness`. `resolve(PredictionMarket)` is permissionless,
  checks `market.resolver() == address(this)`, closes an `Active` market at/after its deadline, and
  calls `proposeOutcome`. It never transfers collateral.
- **11.3** `_read()` rejects `updatedAt == 0`, stale timestamps, future timestamps,
  `startedAt > updatedAt`, `answeredInRound < roundId`, and `answer <= 0` with dedicated custom
  errors. A stale or malformed feed delays resolution instead of producing an outcome.
- **11.4** Answers are normalized to 18 decimals: lower-decimal feeds multiply up, higher-decimal
  feeds divide down, and feeds above 36 decimals revert `InvalidDecimals`. Comparators are
  `GreaterThan`, `GreaterThanOrEqual`, `LessThan`, and `LessThanOrEqual`.
- **11.5** Added `src/ManualResolver.sol`: immutable owner, owner-only `resolve(market, outcome)`,
  `Unresolved` rejection, resolver/state checks, and `close()` when the market is still `Active`.
- **11.6** Both resolvers emit `Resolved` and call `market.proposeOutcome`; the existing dispute
  window and permissionless `finalize()` remain the only path to payout.
- **11.7** Added `test/OracleResolver.t.sol` (25 tests) covering all comparators, threshold
  boundaries, close/propose flow, state guards, non-resolver markets, stale/zero/future timestamps,
  incomplete rounds, zero/negative answers, 6/8/20-decimal normalization, invalid decimals,
  `latestAnswer`, and constructor guards. Added `test/ManualResolver.t.sol` (12 tests) and
  `test/utils/MockAggregatorV3.sol`.
- **11.8** Added `test/OracleResolverFork.t.sol`, gated by `BASE_SEPOLIA_RPC_URL` and
  `CHAINLINK_ETH_USD_FEED`. It deploys a market against the live ETH/USD feed and verifies a
  positive price resolves YES. It skips cleanly when the env vars are absent.

## 4. What was skipped / deferred

- Bonded disputes, dispute resolution, and arbiter finalization — **Phase 12** by design.
- Automated keeper/bot to call `resolve` — later backend/worker phase; anyone can call it.
- Feed registry, per-market feed allowlist, and admin feed migration — not needed for the MVP.
- Composite/multi-feed or TWAP resolution — out of scope for objective single-feed markets.
- The live fork test is env-gated and skipped in the default local/CI run.

## 5. File changes

| Type     | File                                                  | Change                                               |
| -------- | ----------------------------------------------------- | ---------------------------------------------------- |
| Added    | `packages/contracts/src/interfaces/IAggregatorV3.sol` | Minimal Chainlink interface                          |
| Added    | `packages/contracts/src/OracleResolver.sol`           | Feed/comparator/threshold resolver                   |
| Added    | `packages/contracts/src/ManualResolver.sol`           | Owner-controlled fallback resolver                   |
| Added    | `packages/contracts/test/utils/MockAggregatorV3.sol`  | Configurable feed mock                               |
| Added    | `packages/contracts/test/OracleResolver.t.sol`        | 25 oracle tests                                      |
| Added    | `packages/contracts/test/ManualResolver.t.sol`        | 12 manual resolver tests                             |
| Added    | `packages/contracts/test/OracleResolverFork.t.sol`    | Env-gated Base Sepolia fork test                     |
| Added    | `docs/resolution.md`                                  | Resolution design, validation, and fork instructions |
| Modified | `docs/amm.md`, `docs/state-machine.md`                | Cross-links and resolution actions                   |
| Modified | `README.md`, `packages/contracts/README.md`           | Status and test counts                               |
| Modified | `packages/contracts/.gas-snapshot`                    | Regenerated                                          |

## 6. Effects / impact

- Objective price-threshold markets can resolve automatically from Chainlink after the deadline,
  without an admin choosing the outcome.
- Resolution fails closed on stale/incomplete/non-positive data, which is safer than guessing.
- Manual markets use a trusted owner resolver but follow the same proposal/finalization path.
- A resolver is bound to its markets by `market.resolver()`, so one resolver cannot resolve another
  resolver's market.
- `ManualResolver` ownership is immutable; changing the resolver requires a new market (or a future
  migration feature).

## 7. Verification

- Tests: **179 / 179** Foundry tests pass, plus 1 env-gated fork test skipped (180 total). New
  Phase 11 suites: 25 `OracleResolver`, 12 `ManualResolver`, 1 fork test (skipped by default).
- Coverage: `OracleResolver` 100% lines / 91.30% branches; `ManualResolver` 100% lines/branches;
  overall **96.26%** lines, **88.59%** branches.
- Lint/format: `forge lint` clean; `forge fmt --check` clean.
- Gas snapshot: regenerated (180 total tests).
- Sizes: `OracleResolver` 2,990 B; `ManualResolver` 1,088 B; `MarketDeployer` 23,718 B (margin
  858 B); `MarketFactory` 2,590 B.
- Fork test: skipped locally because `BASE_SEPOLIA_RPC_URL` / `CHAINLINK_ETH_USD_FEED` are unset;
  command documented in `docs/resolution.md`.
- Monorepo: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm format:check` green with Foundry on
  `PATH`.

## 8. Progress

- Phases complete: **11 / 20** (55%)
- Overall estimate: ~55% done
- Schedule: on track
- Remaining: disputes (12–13), backend/workers (14–17), web (18–19), hardening/demo (20).

## 9. Blockers & next

- Blockers: none. The live fork test needs an RPC URL and feed address when run.
- Next: **Phase 12 — Disputes & Resolution Trust**: bonded disputes, dispute window enforcement,
  arbiter resolution, and finalization from the `Disputed` state.
