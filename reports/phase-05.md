# Phase 05 — Market Lifecycle State Machine

## 1. Phase identity

- Phase: 05 / 20
- Name: Market Lifecycle State Machine
- Project part: **Contracts / market lifecycle**

## 2. Scope planned

- 5.1 Define states: `Created → Active → Closed → Proposed → Disputed? → Resolved → Finalized`.
- 5.2 Implement transition guards and `onlyState` modifiers.
- 5.3 Implement `close()` (after deadline, permissionless).
- 5.4 Implement `proposeOutcome()` entry point (resolver role) — body wired in Phase 11.
- 5.5 Define `MarketStatus` enum + getters; emit `MarketClosed`, `OutcomeProposed`, etc.
- 5.6 Add timelock/period constants (trading close, dispute window, finalization delay).
- 5.7 Unit tests for every legal and illegal transition (state × action matrix).
- 5.8 Document the state diagram in `docs/state-machine.md`.

## 3. What was done

- 5.1 → Canonical states in `MarketTypes.sol`: `Created`, `Active`, `Closed`, `Proposed`,
  `Disputed`, `Finalized`. ADR 0006 is authoritative; the roadmap's "Resolved" maps to
  `Proposed`/`Finalized`, not a separate state.
- 5.2 → `PredictionMarket` uses a private `_status` plus `onlyState(MarketStatus)`, `onlyCreator`,
  and `onlyResolver` modifiers; illegal transitions revert `InvalidState(current, required)`.
- 5.3 → `close()`: permissionless, requires `Active` and `block.timestamp >= deadline`; records
  `closedAt` and emits `MarketClosed`.
- 5.4 → `proposeOutcome(Outcome)`: resolver-only, requires `Closed`, rejects `Unresolved`, records
  `proposedOutcome` + `proposedAt`, emits `OutcomeProposed`. Phase 11 wires the oracle to it.
- 5.5 → `status()` getter + `Outcome` enum (`Unresolved`/`Yes`/`No`); events `MarketActivated`,
  `MarketClosed`, `OutcomeProposed`, `MarketFinalized`.
- 5.6 → `DISPUTE_WINDOW = 2 hours`, `FINALIZATION_DELAY = 0` (testnet); `finalize()` is
  permissionless after `proposedAt + window + delay`.
- 5.7 → `test/PredictionMarket.t.sol`: 16 tests, including `test_StateActionMatrix` (5 reachable
  states × 4 actions = 20 combinations) plus explicit error-path tests.
- 5.8 → `docs/state-machine.md`: Mermaid diagram, state/transition tables, state × action matrix,
  invariants, and notes (temporary `activate()`, `Disputed` deferred to Phase 12).
- **Supporting changes:** added `SafeCast.toUint64` for timestamp casts; fixed all Foundry linter
  diagnostics (unsafe typecast + test timestamp reads) — `forge lint` is clean.
- `activate()` is a temporary creator-only entry point until Phase 7 replaces it with
  `seedLiquidity()` (which will require collateral first).

## 4. What was skipped / deferred

- **`Disputed` state is unreachable** — `disputeOutcome()` and arbiter `resolveDispute()` land in
  Phase 12 with bonds. The state and its all-revert matrix row are already defined.
- **`finalize()` has no dispute check yet** — Phase 12 makes it revert when a dispute is open.
- **`activate()` is a scaffold** — Phase 7 replaces it with `seedLiquidity()`.
- **No outcome tokens, collateral vault, AMM, or redemption** — Phase 6–8.
- **No oracle wiring** — Phase 11.
- **No payout guard implementation** — `redeem()` arrives in Phase 6+; the invariant is documented.
- **No upgradeability / timelock admin** — not needed for MVP.

## 5. File changes

> Earlier phases' files remain untracked, so `git diff --stat` is not meaningful; counts are `wc -l`.

| Type     | File                                                                    | Lines     |
| -------- | ----------------------------------------------------------------------- | --------- |
| Modified | `packages/contracts/src/MarketTypes.sol` (enums + config)               | 38        |
| Modified | `packages/contracts/src/PredictionMarket.sol` (state machine)           | 173       |
| Added    | `packages/contracts/test/PredictionMarket.t.sol`                        | 317       |
| Modified | `packages/contracts/test/utils/TestConstants.sol` (+finalization delay) | 14        |
| Added    | `docs/state-machine.md`                                                 | 81        |
| Modified | `packages/contracts/README.md` (Phase 5 status)                         | 78        |
| Modified | `packages/contracts/.gas-snapshot` (37 tests)                           | 36        |
| Modified | `README.md` (Phase 5 status + capabilities)                             | 112       |
| Added    | `reports/phase-05.md`                                                   | this file |
| Modified | `reports/PROGRESS.md`                                                   | +2 / -1   |

- **Total touched:** ~862 lines across 10 files (+ this report).

## 6. Effects / impact

- Every market now has an auditable lifecycle; off-chain indexers can follow `status()` and the
  lifecycle events without guessing.
- `close()` cannot run early, `proposeOutcome()` cannot run before close, and `finalize()` cannot
  run before the dispute window — no action can skip a state.
- `proposedOutcome` is immutable after proposal, so Phase 6+ payout logic can trust it once
  `Finalized`.
- The full state × action matrix is encoded as a test, reducing the risk of a stuck market.
- The state machine is documented once (`docs/state-machine.md`) and referenced from the contracts.

## 7. Verification

- `forge build --force` → ✅ 36 files compiled with Solc 0.8.24, **no warnings**.
- `forge test -vv` → ✅ **37/37 passed** (8 MockUSDC + 13 MarketFactory + 16 PredictionMarket).
- `test_StateActionMatrix` → ✅ 20 state × action combinations (legal transition or revert).
- `forge lint` → ✅ **0 diagnostics**; `forge fmt --check` → ✅ clean.
- `forge snapshot` → ✅ `.gas-snapshot` updated.
- Root pipeline → ✅ `pnpm lint`, `pnpm format:check`, `pnpm typecheck`, `pnpm build`, `pnpm test`.
- Total tests now: **44** (5 shared + 2 backend + 37 contracts).

## 8. Progress

- Phases complete: **5 / 20 (25%)**
- Overall estimate: **~22%** (lifecycle done; no tokens/AMM yet).
- Schedule: **on track** (Phase 5 scoped at 3–4 days).
- Remaining: Phase 6 (outcome tokens + vault) through Phase 20 (deploy/launch).

## 9. Blockers & next

- No blocking bugs. Contract deps remain git-ignored (`make contracts-deps`); changes are
  **uncommitted** per project rule.
- Next phase: **Phase 6 — Outcome Tokens & Collateral Vault** (`OutcomeToken.sol`, YES/NO per
  market, `split`/`merge`, 1:1 USDC backing).
