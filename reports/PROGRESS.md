# PredictX — Progress Log

One-line-per-phase summary. Full detail lives in `reports/phase-XX.md`.

| Phase | Name                                  | Status      | Date       | Skipped/deferred                                                                            | Notes                                                                                                                                          |
| ----- | ------------------------------------- | ----------- | ---------- | ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 01    | Foundations & Architecture Decisions  | ✅ Complete | 2026-11-12 | None                                                                                        | 6 ADRs + vision + demo script (~668 docs lines). No code yet.                                                                                  |
| 02    | Monorepo, Tooling & CI                | ✅ Complete | 2026-11-12 | Contracts/web are placeholders (Phase 3/18)                                                 | pnpm+Turborepo, ESLint/Prettier/Husky, CI, shared pkg + Express `/health` skeleton.                                                            |
| 03    | Local Chain & Contract Scaffolding    | ✅ Complete | 2026-11-12 | `lib/` is git-ignored (restore with `make contracts-deps`); only a placeholder contract     | Foundry 1.9.0 + OZ 5.7.0 + forge-std 1.17.0, `Placeholder.sol`, 4 tests, Anvil deploy script, thirdweb ADR.                                    |
| 04    | Collateral, Factory & Market Registry | ✅ Complete | 2026-11-12 | Initial liquidity stored but not escrowed until Phase 6/7                                   | `MockUSDC` faucet, `MarketFactory` validation/cooldown/ids/registry, minimal `PredictionMarket`, 21 contract tests.                            |
| 05    | Market Lifecycle State Machine        | ✅ Complete | 2026-11-12 | `Disputed` state + dispute edges deferred to Phase 12; `activate()` temporary until Phase 7 | `Created→Active→Closed→Proposed→Finalized` guards, events, window constants, 16 new tests + full state×action matrix, `docs/state-machine.md`. |

**Progress:** 5 / 20 phases complete (25%). Next: Phase 6 — Outcome Tokens & Collateral Vault.
