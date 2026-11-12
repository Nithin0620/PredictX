# Phase 02 — Monorepo, Tooling & CI

## 1. Phase identity

- Phase: 02 / 20
- Name: Monorepo, Tooling & CI
- Project part: **Developer tooling & infrastructure** (repo foundation for all later phases)

## 2. Scope planned

- 2.1 Initialize a pnpm workspace with `packages/`.
- 2.2 Add Turborepo with `build`, `test`, `lint`, `typecheck` pipelines.
- 2.3 Create packages: `contracts`, `shared`, `backend`, `web`.
- 2.4 Configure ESLint + Prettier + TypeScript strict + Husky + lint-staged.
- 2.5 Add `.env.example` per package; never commit secrets.
- 2.6 Add GitHub Actions CI: install → lint → typecheck → build → test.
- 2.7 Add Makefile / root scripts: `dev`, `test`, `deploy:local`, `indexer:dev`.

## 3. What was done

- 2.1 → `pnpm-workspace.yaml` (`packages/*`) + root `package.json` with `packageManager: pnpm@11.27.0`.
- 2.2 → `turbo.json` with `build`, `typecheck`, `test`, `lint`, `dev`, `clean` tasks; `build`/`test`
  depend on upstream `^build`; package-level `turbo.json` overrides for placeholder packages.
- 2.3 → four workspaces:
  - `@predictx/shared` — **real**: chain constants, enums/types, ABI placeholder, built with `tsc`,
    tested with Vitest.
  - `@predictx/backend` — **minimal real**: Express app with `GET /health`, tested with
    Vitest + Supertest; `tsx` dev server.
  - `@predictx/contracts` — placeholder (Foundry lands in Phase 3).
  - `@predictx/web` — placeholder (Next.js lands in Phase 18).
- 2.4 → `eslint.config.mjs` (flat config: `@eslint/js` + `typescript-eslint` + Prettier),
  `.prettierrc.json`, `.prettierignore`, `tsconfig.base.json` (strict + `noUncheckedIndexedAccess`),
  Husky `.husky/pre-commit` running `lint-staged` (ESLint + Prettier on staged files).
- 2.5 → root `.env.example`, `packages/backend/.env.example`, `packages/web/.env.example`;
  `.gitignore` excludes `.env*` but keeps `*.env.example`.
- 2.6 → `.github/workflows/ci.yml` (pnpm + Node 24 → install `--frozen-lockfile` → lint →
  format:check → typecheck → build → test) with concurrency cancellation.
- 2.7 → root scripts (`dev`, `build`, `test`, `lint`, `typecheck`, `format`, `format:check`,
  `clean`) + `Makefile` (`install`, `dev`, `build`, `test`, `lint`, `typecheck`, `format`,
  `clean`, plus stubs for `chain`, `deploy-local`, `indexer-dev`).

## 4. What was skipped / deferred

- **Contracts package is a placeholder** — Foundry/`forge init` is Phase 3 by design.
- **Web package is a placeholder** — Next.js/thirdweb scaffold is Phase 18 by design.
- **Backend domain modules** (auth, markets, trading, portfolio, analytics, resolution) — Phase 14–16.
- **Redis/Docker Compose, Prisma/Neon** — Phase 14 (no DB needed for this phase).
- **Real contract ABIs** in `packages/shared/src/abis` — generated in Phase 13 after contracts exist.
- **Foundry install** — not available in this environment yet; needed before Phase 3.
- No commits were made (per project rule: only commit when explicitly requested).

## 5. File changes

> New files are untracked; counts are from `wc -l`. The repo already had a git history, so
> `git diff --stat` only covers modified tracked files (none were modified this phase).

| Type     | Area                                                                                                    | Files | Lines                           |
| -------- | ------------------------------------------------------------------------------------------------------- | ----- | ------------------------------- |
| Added    | Root config (workspace/turbo/ts/eslint/prettier/editor/git/npm/nvm/env/Makefile/README)                 | 17    | ~360                            |
| Added    | `packages/shared` (pkg, tsconfigs, 4 src files)                                                         | 7     | ~180                            |
| Added    | `packages/backend` (pkg, tsconfigs, 4 src files, env)                                                   | 8     | ~150                            |
| Added    | `packages/contracts` (pkg, README, turbo)                                                               | 3     | ~50                             |
| Added    | `packages/web` (pkg, README, env, turbo)                                                                | 4     | ~55                             |
| Added    | `.github/workflows/ci.yml`, `.husky/pre-commit`                                                         | 2     | ~50                             |
| Added    | `pnpm-lock.yaml` (generated)                                                                            | 1     | 2,819                           |
| Added    | `reports/phase-02.md`                                                                                   | 1     | this file                       |
| Modified | `reports/PROGRESS.md`                                                                                   | 1     | +2 / -1                         |
| Modified | `PHASES.md`, `PROJECT_PLAN.md`, `PredictX.md` (Prettier formatting + earlier uncommitted content edits) | 3     | +313 / -216 (`git diff --stat`) |

- **Total (excluding lockfile):** ~819 new lines across 42 files.
- **With lockfile:** ~3,638 lines.
- **Tracked-file diff:** `3 files changed, 313 insertions(+), 216 deletions(-)` — formatting-only
  for `PredictX.md`; `PHASES.md`/`PROJECT_PLAN.md` also include the stack/phase-report edits made in
  the preceding turns (all uncommitted).

## 6. Effects / impact

- The repo now has a **single install/build/test pipeline** (`pnpm install && pnpm build && pnpm test`).
- `@predictx/shared` is consumable by backend (and later web/indexer) via workspace package
  `@predictx/shared` with built `dist` + type declarations.
- `@predictx/backend` boots and serves `GET /health` returning chain info (Base Sepolia, 84532).
- CI will enforce lint, formatting, types, build, and tests on every push/PR.
- Husky prevents committing unlinted/unformatted code.
- Placeholder packages let Turbo/CI include contracts and web from day one, so Phase 3/18 only add
  code — no pipeline rework.
- New risk: `@types/node` is v26 with TS 5.9 (works now; pin/adjust if it drifts).

## 7. Verification

- `pnpm install` — ✅ 253 packages, lockfile generated, esbuild build approved via
  `pnpm-workspace.yaml` `allowBuilds`.
- `pnpm lint` — ✅ no errors.
- `pnpm format:check` — ✅ all files formatted.
- `pnpm typecheck` — ✅ 5 turbo tasks successful.
- `pnpm build` — ✅ 4 turbo tasks successful (shared/backend emit `dist`; contracts/web no-op).
- `pnpm test` — ✅ **7 tests passed**: shared 5 (`constants.test.ts`), backend 2
  (`app.test.ts`: health + no `x-powered-by`).
- Smoke test — ✅ `node packages/backend/dist/server.js` served
  `{"status":"ok","service":"PredictX API","chain":"Base Sepolia","chainId":84532,...}`.
- CI: workflow written; will run on next push/PR (not executed locally).
- Coverage: not configured yet (optional, Phase 13/16).

## 8. Progress

- Phases complete: **2 / 20 (10%)**
- Overall estimate: **~8%** (foundation + tooling; contracts/backend/web are still scaffolds).
- Schedule: **on track** (Phase 2 scoped at 2–3 days).
- Remaining: Phase 3 (Foundry scaffold) through Phase 20 (deploy/launch).

## 9. Blockers & next

- **Blocker for Phase 3:** Foundry is not installed in this environment
  (`forge: command not found`). Install with
  `curl -L https://foundry.paradigm.xyz | bash && foundryup` before starting Phase 3.
- Git: repo history exists but Phase 2 changes are **uncommitted** (not committed unless asked).
  Once committed, tag `phase-02-complete` to keep per-phase diffs trivial.
- Next phase: **Phase 3 — Local Chain & Contract Scaffolding**.
