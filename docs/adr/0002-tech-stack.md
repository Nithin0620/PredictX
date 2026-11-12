# ADR 0002 — Technology stack

- **Status:** Accepted
- **Date:** 2026-11-12
- **Deciders:** Project author
- **Phase:** 1

## Context

PredictX is a full-stack product spanning smart contracts, an event-driven backend, and a Web3
frontend. The stack must be fast to build solo, well-documented, and demonstrate both on-chain and
off-chain engineering. The author has chosen: **Next.js** frontend, **Express** backend,
**SQL-based Neon** database, and **thirdweb** for deployment, chain access, and wallet UI.

## Decision

| Layer            | Choice                                                                                          |
| ---------------- | ----------------------------------------------------------------------------------------------- |
| Monorepo         | **pnpm workspaces + Turborepo**                                                                 |
| Contracts        | **Solidity ^0.8.24 + Foundry** (tests, fuzzing, invariants)                                     |
| Contract deploy  | **thirdweb CLI** (`npx thirdweb deploy`) to Base Sepolia                                        |
| Contract libs    | **OpenZeppelin Contracts**                                                                      |
| Oracle           | **Chainlink Price Feeds** + manual resolver fallback                                            |
| Backend          | **Node.js + TypeScript + Express** (Zod validation, pino logging)                               |
| ORM / DB         | **Prisma + Neon Postgres** (serverless SQL)                                                     |
| Queue / cache    | **Redis + BullMQ**                                                                              |
| Chain client     | **thirdweb SDK** (frontend) · **viem** (backend indexer)                                        |
| Auth             | **SIWE → JWT session cookie**                                                                   |
| Realtime         | **WebSocket / SSE**                                                                             |
| Frontend         | **Next.js (App Router) + TypeScript**                                                           |
| Web3 UI          | **thirdweb SDK** (`ConnectButton`, `useActiveAccount`, `useReadContract`, `useSendTransaction`) |
| Styling / charts | **Tailwind CSS + shadcn/ui + Recharts**                                                         |
| CI/CD            | **GitHub Actions**                                                                              |
| Hosting          | **Vercel** (web) · **Fly.io/Railway** (API) · **Neon** (DB) · managed **Redis**                 |
| Monitoring       | **Sentry** + uptime + indexer-lag metric                                                        |

## Rationale

- **Neon Postgres (not MongoDB):** prediction-market data is relational (users ↔ positions ↔
  trades ↔ markets). SQL gives joins, foreign keys, aggregations, and transactional consistency for
  the indexer. Neon provides serverless Postgres with branching, so each dev gets an isolated DB
  branch and migrations are straightforward.
- **Prisma:** typed schema + migrations; use the **pooled** connection string at runtime and the
  **direct** connection for migrations (Neon requirement).
- **Express:** the author's chosen backend framework; minimal, well-understood, easy to attach
  BullMQ workers and a WebSocket/SSE layer.
- **thirdweb:** one SDK for deploy + wallet UI + contract reads/writes. thirdweb v5 is built on
  **viem**, so it is not a lock-in dead end.
- **viem for the indexer:** thirdweb helpers are convenient but do not provide the cursor,
  finality-lag, and reorg-rollback control a reliable indexer needs. Raw `getLogs` is required.
- **Foundry + thirdweb deploy:** Foundry remains the source of truth for correctness; thirdweb
  handles testnet deployment and verification convenience.
- **Redis/BullMQ:** Neon is Postgres-only, so queues and pub/sub need a separate Redis.

## Consequences

**Positive**

- Clear separation: chain = authority, DB = rebuildable index, backend = reads/UX.
- Strong typing end-to-end (TypeScript + Prisma + generated ABIs).
- thirdweb reduces wallet/deploy boilerplate; viem keeps backend control.

**Negative / trade-offs**

- Two chain clients (thirdweb frontend, viem backend) — mitigated because thirdweb wraps viem.
- Neon requires pooled vs direct connection awareness; serverless cold starts.
- More moving parts than a single-framework app (contracts, API, workers, web).

## Alternatives considered

| Option                    | Why rejected                                                                     |
| ------------------------- | -------------------------------------------------------------------------------- |
| MongoDB + Mongoose        | Weaker relational integrity and multi-doc transactions for financial data.       |
| Fastify backend           | Fine, but author prefers Express; Fastify-specific optimizations are not needed. |
| wagmi + RainbowKit        | Overlaps with thirdweb; thirdweb is the chosen single Web3 SDK.                  |
| Hardhat                   | Foundry offers faster tests, fuzzing, and invariant testing out of the box.      |
| Supabase/Railway Postgres | Viable; Neon chosen for branching + serverless model.                            |

## Related

- `PROJECT_PLAN.md` §5 Technology stack, §6 Repository layout
- `PHASES.md` Phases 2, 3, 14–20
- ADR 0001 (chain)
