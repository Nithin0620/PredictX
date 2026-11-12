# Phase 01 — Foundations & Architecture Decisions

## 1. Phase identity

- Phase: 01 / 20
- Name: Foundations & Architecture Decisions
- Project part: **Project-wide foundations (docs / architecture)** — no runtime code yet

## 2. Scope planned

- 1.1 Write the one-page project vision (what, who, why, demo script).
- 1.2 Lock the tech stack: chain, contracts, backend, frontend, infra.
- 1.3 Choose the chain (Base Sepolia).
- 1.4 Choose the token model (ERC-20 YES/NO per market).
- 1.5 Choose pricing (CPMM).
- 1.6 Choose resolution (Chainlink feeds + manual resolver fallback).
- 1.7 Write ADRs for each decision.
- 1.8 Define the demo story to show at the end.

## 3. What was done

- 1.1 → `docs/vision.md` (what, who, why, success criteria, non-goals, the core loop).
- 1.2 → `docs/adr/0002-tech-stack.md` (Next.js · Express · Neon Postgres + Prisma · Redis/BullMQ ·
  thirdweb · viem · Foundry · pnpm/Turborepo).
- 1.3 → `docs/adr/0001-chain.md` (Base Sepolia, chain ID `84532`, testnet only).
- 1.4 → `docs/adr/0003-token-model.md` (per-market ERC-20 YES/NO, 6 decimals, LP token,
  split/merge invariants).
- 1.5 → `docs/adr/0004-pricing-amm.md` (CPMM `x·y=k`, fee split, slippage/deadline, `k` invariant).
- 1.6 → `docs/adr/0005-oracle-resolution.md` (Chainlink price feeds + manual resolver fallback).
- 1.7 → six ADRs (`0001`–`0006`) + index `docs/adr/README.md` + `docs/adr/0000-template.md`.
- 1.8 → `docs/demo-script.md` (3-minute end-to-end demo + fallbacks).
- Also captured the **dispute & trust model** as `docs/adr/0006-dispute-and-trust.md`.

## 4. What was skipped / deferred

- None from the Phase 1 plan.
- Noted as **future work** (not part of this phase): UMA-style optimistic oracle, multi-outcome
  markets, CLOB/order book, AI as a resolver. These are documented as out of scope in
  `docs/vision.md` and `PROJECT_PLAN.md` §3.2.

## 5. File changes

> Repo is **not yet a git repository** (git init + CI arrive in Phase 2), so line counts come from
> `wc -l` rather than `git diff --stat`.

| Type  | File                                 | Lines     |
| ----- | ------------------------------------ | --------- |
| Added | `docs/vision.md`                     | 88        |
| Added | `docs/demo-script.md`                | 103       |
| Added | `docs/adr/README.md`                 | 32        |
| Added | `docs/adr/0000-template.md`          | 34        |
| Added | `docs/adr/0001-chain.md`             | 59        |
| Added | `docs/adr/0002-tech-stack.md`        | 83        |
| Added | `docs/adr/0003-token-model.md`       | 64        |
| Added | `docs/adr/0004-pricing-amm.md`       | 69        |
| Added | `docs/adr/0005-oracle-resolution.md` | 68        |
| Added | `docs/adr/0006-dispute-and-trust.md` | 68        |
| Added | `reports/phase-01.md`                | this file |

- **Total (docs):** ~668 lines added across 10 files (+ this report). No source code yet.

## 6. Effects / impact

- All major technical decisions are now **written and justified** — no "we'll decide later".
- Scope guardrails are explicit: binary markets only, objective price markets only, testnet only,
  simplified disputes, AI is non-authoritative.
- The **demo loop** is defined, so every later phase has a concrete target:
  `faucet → trade → probability moves → oracle resolve → dispute window → finalize → claim`.
- Downstream phases (2–20) now have fixed inputs: chain, token model, AMM, resolution, trust model.
- No runtime risk yet (documentation only). Risk reduced: scope creep is now controlled in writing.

## 7. Verification

- Tests: N/A (docs-only phase; no code).
- Coverage: N/A.
- Gas snapshot: N/A.
- CI: not set up yet (Phase 2).
- Manual checks:
  - Cross-checked ADRs against `PROJECT_PLAN.md` §3 (Scope), §5 (Stack), §9 (Resolution), §14
    (Deployment).
  - Confirmed all Phase 1 sub-phases (1.1–1.8) map to a deliverable.
  - Confirmed the six ADRs cover chain, stack, token model, pricing, oracle, disputes.
  - Confirmed the demo script exercises every core subsystem.

## 8. Progress

- Phases complete: **1 / 20 (5%)**
- Overall estimate: **~4%** of the project (foundations only; no code shipped yet).
- Schedule: **on track** (Phase 1 was scoped at 2–3 days; completed as a docs deliverable).
- Remaining: Phase 2 (monorepo/tooling/CI) through Phase 20 (deploy/launch).

## 9. Blockers & next

- Blockers: none.
- Note: `git init` + CI are **not** done yet; they are the first tasks of Phase 2. Per-phase
  `git diff --stat` reporting becomes possible once the repo is initialized and tagged.
- Next phase: **Phase 2 — Monorepo, Tooling & CI**.
