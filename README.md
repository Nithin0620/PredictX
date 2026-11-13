# PredictX

A decentralized, oracle-powered **binary prediction market** on **Base Sepolia** (testnet only).
Real ERC-20 YES/NO outcome tokens, a fully-collateralized **CPMM** AMM, **Chainlink** oracle
resolution, a reorg-safe event indexer, and a Next.js + thirdweb frontend.

> **Status:** Phase 7 of 20 — the CPMM pricing engine. Markets can be created, seeded with
> liquidity, traded (buy/sell YES or NO), split/merged 1:1 with USDC, closed, proposed, and
> finalized on-chain. Slippage/deadline, LP tokens, and fee routing arrive in Phases 8–9; the backend
> and web arrive later. See `PHASES.md` for the full roadmap.

## Stack

| Layer     | Tech                                                                   |
| --------- | ---------------------------------------------------------------------- |
| Contracts | Solidity + Foundry (test) · thirdweb CLI (deploy)                      |
| Backend   | Node.js + TypeScript + Express · Prisma · Neon Postgres · Redis/BullMQ |
| Indexer   | viem `getLogs` + reorg handling                                        |
| Frontend  | Next.js + TypeScript + thirdweb SDK · Tailwind/shadcn                  |
| Monorepo  | pnpm workspaces + Turborepo                                            |

## Prerequisites

- **Node.js** >= 20 (see `.nvmrc`)
- **pnpm** 11 (`corepack enable` then `corepack prepare pnpm@11 --activate`)
- **Git**
- (Phase 3+) **Foundry** (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)
- (Phase 14+) **Docker** for local Redis (Neon Postgres is remote)

## Getting started

```bash
# 1. Install dependencies (also sets up Husky git hooks)
pnpm install

# 2. Copy environment templates
cp .env.example .env
cp packages/backend/.env.example packages/backend/.env   # Phase 14

# 3. Install pinned contract dependencies (Foundry lib/)
make contracts-deps

# 4. Run the full verification pipeline
pnpm lint
pnpm typecheck
pnpm build
pnpm test
```

> Foundry must be installed and `~/.foundry/bin` on your `PATH` for the contracts workspace.
> `make contracts-deps` restores `packages/contracts/lib/` (git-ignored) at pinned versions.

## Common commands

| Command             | What it does                            |
| ------------------- | --------------------------------------- |
| `pnpm dev`          | Run all dev servers (turbo, persistent) |
| `pnpm build`        | Build every package                     |
| `pnpm test`         | Run every package's tests               |
| `pnpm lint`         | ESLint across the workspace             |
| `pnpm typecheck`    | TypeScript across the workspace         |
| `pnpm format`       | Prettier write                          |
| `pnpm format:check` | Prettier check (used in CI)             |
| `pnpm clean`        | Remove build artifacts                  |
| `make help`         | List Make targets                       |

## Repository layout

```
PredictX/
├── docs/                 # vision, demo script, ADRs
├── reports/              # per-phase completion reports + progress log
├── packages/
│   ├── contracts/        # Solidity + Foundry            (Phase 3+)
│   ├── shared/           # ABIs, types, constants        (Phase 2)
│   ├── backend/          # Express API + indexer/workers (Phase 14+)
│   └── web/              # Next.js frontend              (Phase 18+)
├── .github/workflows/    # CI
├── PHASES.md             # 20-phase roadmap
├── PROJECT_PLAN.md       # what we're building & how
├── turbo.json
└── pnpm-workspace.yaml
```

## What works right now (Phase 6)

- `@predictx/shared` — chain constants, enums, and types, built with `tsc` and tested with Vitest.
- `@predictx/backend` — minimal Express app exposing `GET /health`, with a Vitest + Supertest test.
- `@predictx/contracts` — `MockUSDC` (6 decimals, faucet), `MarketFactory` (validation, cooldown,
  sequential ids, registry), `PredictionMarket` with the lifecycle state machine, per-market YES/NO
  `OutcomeToken`s (6 decimals), and 1:1 `split`/`merge` with a stateful collateral invariant, with
  61 Foundry tests.
- `@predictx/web` — placeholder; filled in Phase 18.
- Lint, typecheck, build, test, and formatting enforced in CI.
- Husky pre-commit runs `lint-staged` (ESLint + Prettier on staged files).

### Local chain

```bash
make chain        # terminal 1: Anvil on chain id 31337 (deterministic accounts)
make deploy-local # terminal 2: deploy MockUSDC + MarketFactory
```

## Docs

- [`PROJECT_PLAN.md`](./PROJECT_PLAN.md) — what we're building and how.
- [`PHASES.md`](./PHASES.md) — 20-phase execution roadmap + phase report rules.
- [`docs/vision.md`](./docs/vision.md) — one-page vision and scope.
- [`docs/demo-script.md`](./docs/demo-script.md) — the end-to-end demo.
- [`docs/adr/`](./docs/adr/) — architecture decision records.

## Safety

Testnet only. Mock USDC only. No real money. No mainnet deployment.
