# PredictX — End-to-End Build Plan (20 Phases)

> Companion document: see `PROJECT_PLAN.md` for **what** we are building and **how** it fits together.
> This file is the **execution roadmap**: every phase, its sub-levels, deliverables, and exit criteria.

---

## 0. How to read this document

Each phase has the same shape:

- **Goal** — one sentence on why this phase exists.
- **Sub-phases** — numbered sub-levels you complete in order.
- **Deliverables** — concrete artifacts (files, contracts, endpoints, pages).
- **Exit criteria (Definition of Done)** — what must be _true_ before moving on.
- **Risks / notes** — what usually goes wrong here.

Phases are ordered by dependency, not by importance. You can run **contracts (1–13)** and
**backend (14–17)** partially in parallel once Phase 7 is stable, but the sequence below is the
safe default for a solo builder.

---

## 1. Scope decisions — what we cut and why

These decisions are locked before Phase 1. They are the answer to "what should I cut".

| Feature                                  | Decision                  | Why                                                    |
| ---------------------------------------- | ------------------------- | ------------------------------------------------------ |
| Real ERC-20 YES/NO outcome tokens        | **Keep**                  | More impressive, composable, testable.                 |
| CPMM (x·y=k) AMM over YES/NO             | **Keep**                  | Proven math, no need to invent pricing.                |
| LMSR / CLOB order book                   | **Cut (MVP)**             | Huge complexity, poor ROI for portfolio.               |
| Chainlink price-feed markets             | **Keep**                  | Objective, automatable, the strong differentiator.     |
| Sports / subjective markets              | **Cut (MVP)**             | Resolution + dispute nightmare.                        |
| Full UMA-style decentralized arbitration | **Cut (MVP)**             | Replace with bonded propose/challenge + admin arbiter. |
| AI market insights                       | **Defer to Phase 20**     | Nice-to-have, not core, no resolution authority.       |
| Dispute bond + dispute window            | **Keep (simplified)**     | One bonded challenge round, then arbiter.              |
| Mainnet / real money                     | **Never in this project** | Regulatory + safety. Testnet + mock USDC only.         |
| Mobile app                               | **Cut**                   | Responsive web is enough.                              |
| Multi-outcome (non-binary) markets       | **Cut (MVP)**             | Binary only; architecture leaves room.                 |

**Golden rule:** if a feature is not needed for a demoable end-to-end trade → resolve → claim loop,
it does not belong in Phases 1–19.

---

## 2. Phase overview

| #   | Phase                                    | Est. (part-time) | Depends on | Primary deliverable                  |
| --- | ---------------------------------------- | ---------------- | ---------- | ------------------------------------ |
| 1   | Foundations & architecture decisions     | 2–3 days         | —          | ADRs + repo skeleton                 |
| 2   | Monorepo, tooling & CI                   | 2–3 days         | 1          | Working pnpm/turbo workspace + CI    |
| 3   | Local chain & contract scaffolding       | 3–4 days         | 2          | Foundry project + local Base fork    |
| 4   | Collateral, factory & market registry    | 4–5 days         | 3          | `MockUSDC`, `MarketFactory`          |
| 5   | Market lifecycle state machine           | 4–5 days         | 4          | `PredictionMarket` states + guards   |
| 6   | Outcome tokens & collateral vault        | 5–6 days         | 5          | `OutcomeToken`, split/merge          |
| 7   | AMM pricing engine (CPMM)                | 6–7 days         | 6          | `AMM` buy/sell quote + swap          |
| 8   | Trading engine (fees, slippage)          | 5–6 days         | 7          | End-to-end trade + events            |
| 9   | Liquidity provision & LP tokens          | 4–5 days         | 8          | Add/remove liquidity + fees          |
| 10  | Settlement & claim flow                  | 4–5 days         | 9          | Payouts + double-claim protection    |
| 11  | Oracle integration                       | 5–6 days         | 10         | Chainlink resolver + manual resolver |
| 12  | Dispute resolution & finalization        | 5–6 days         | 11         | Propose/challenge/arbiter flow       |
| 13  | Contract hardening & test suite          | 6–8 days         | 12         | Fuzz/invariant tests, gas report     |
| 14  | Backend foundation (API + DB)            | 5–6 days         | 13         | Express API + Prisma/Neon schema     |
| 15  | Blockchain indexer                       | 6–7 days         | 14         | Event sync + reorg handling          |
| 16  | Domain modules, workers & notifications  | 6–7 days         | 15         | REST modules + BullMQ jobs           |
| 17  | Realtime layer                           | 3–4 days         | 16         | WebSocket/SSE probability feed       |
| 18  | Frontend foundation & wallet             | 4–5 days         | 17         | Next.js shell + SIWE login           |
| 19  | Market discovery, trading & portfolio UI | 7–9 days         | 18         | Full user-facing product             |
| 20  | Advanced features, deployment & launch   | 7–10 days        | 19         | Deployed app + docs + demo           |

**Realistic total:** ~10–14 weeks part-time for a high-quality finish. Compress to ~7–8 weeks by
using the "minimum path" noted at the bottom.

---

## 3. Detailed phases

---

### Phase 1 — Foundations & Architecture Decisions

**Goal:** Remove ambiguity. Every "we'll decide later" becomes a written decision now.

**Sub-phases**
1.1 Write the one-page project vision (what, who, why, demo script).
1.2 Lock the tech stack: chain, contracts, backend, frontend, infra.
1.3 Choose the chain: **Base Sepolia** (cheap, Chainlink feeds available, EVM).
1.4 Choose the token model: **ERC-20 YES/NO per market**, not internal ledger.
1.5 Choose pricing: **CPMM (x·y=k)** with full collateralization.
1.6 Choose resolution: **Chainlink price feeds** for objective markets + **manual resolver** fallback.
1.7 Write ADRs (Architecture Decision Records) for each above choice.
1.8 Define the demo story you must be able to show at the end.

**Deliverables**

- `docs/adr/0001-chain.md` … `docs/adr/0006-resolution.md`
- `docs/vision.md` (one page)
- `docs/demo-script.md`

**Exit criteria**

- Every decision in `PROJECT_PLAN.md` §Scope is written and justified.
- You can explain the full trade → resolve → claim loop on a whiteboard.

**Risks**

- Scope creep starts here. Say "no" in writing now, not later.

---

### Phase 2 — Monorepo, Tooling & CI

**Goal:** One repo, one command to build/test everything, green CI from day one.

**Sub-phases**
2.1 Initialize `pnpm` workspace with `apps/` and `packages/`.
2.2 Add Turborepo with `build`, `test`, `lint`, `typecheck` pipelines.
2.3 Create packages: `contracts`, `shared` (types + ABIs + constants), `backend`, `web`.
2.4 Configure ESLint + Prettier + TypeScript strict mode + Husky + lint-staged.
2.5 Add `.env.example` files per package; never commit secrets.
2.6 Add GitHub Actions: install → lint → typecheck → test (contracts + backend).
2.7 Add `Makefile` or root scripts: `dev`, `test`, `deploy:local`, `indexer:dev`.

**Deliverables**

- Root `package.json`, `pnpm-workspace.yaml`, `turbo.json`
- `packages/shared` with generated ABIs placeholder
- `.github/workflows/ci.yml`
- README with setup instructions

**Exit criteria**

- `pnpm install && pnpm build && pnpm test` passes locally and in CI.
- A new contributor can run the project from the README alone.

**Risks**

- Over-engineering tooling. Timebox to 3 days max.

---

### Phase 3 — Local Chain & Contract Scaffolding

**Goal:** A reproducible local blockchain and a compiling Foundry project.

**Sub-phases**
3.1 Install Foundry; create `packages/contracts` with `forge init`.
3.2 Add OpenZeppelin Contracts dependency.
3.3 Configure `foundry.toml` (solc 0.8.24+, optimizer, remappings, fuzz runs).
3.4 Set up Anvil + a deploy script + `Makefile` target to boot a local chain.
3.5 Optional: fork Base Sepolia (`anvil --fork-url`) for Chainlink feed testing.
3.6 Add `forge fmt` and `forge snapshot` baseline.
3.7 Create the directory layout: `src/`, `test/`, `script/`, `test/utils/`.
3.8 Add thirdweb CLI (`npx thirdweb deploy`) for testnet deployment; Foundry stays the source of truth for tests and local deploys.

**Deliverables**

- Compiling `packages/contracts` with empty/skeleton contracts
- `script/DeployLocal.s.sol`
- `make chain` boots Anvil with deterministic accounts
- thirdweb deploy config/notes in `docs/adr/`

**Exit criteria**

- `forge build` clean, `forge test` runs (even if 0 real tests).
- Anvil boots and you can deploy a placeholder contract to it.

**Risks**

- Solc/remapping mismatches. Pin versions explicitly.

---

### Phase 4 — Collateral, Factory & Market Registry

**Goal:** Create markets on-chain with unique IDs and a mock stablecoin.

**Sub-phases**
4.1 Implement `MockUSDC.sol` (ERC-20, 6 decimals, `mint` faucet for testers).
4.2 Define `MarketConfig` struct (question, resolution source, deadline, resolver, fee, initial liquidity).
4.3 Implement `MarketFactory.sol`: `createMarket(config)` deploys a `PredictionMarket`, registers it.
4.4 Assign sequential `marketId`; store `marketId → market address`.
4.5 Emit `MarketCreated(marketId, address, creator, question, deadline)`.
4.6 Add access control (who can create; allow permissionless with anti-spam guard).
4.7 Unit tests: creation, ID uniqueness, config validation, event emission.
4.8 Write deploy script wiring USDC → factory.

**Deliverables**

- `MockUSDC.sol`, `MarketFactory.sol`, `MarketCreated` event
- Tests covering creation + invalid configs
- Deploy script: USDC + factory

**Exit criteria**

- You can create N markets locally and enumerate them from the factory.
- Invalid configs (past deadline, zero liquidity, empty question) revert.

**Risks**

- Gas cost of deploying a contract per market. Accept for MVP; note a clone/proxy option later.

---

### Phase 5 — Market Lifecycle State Machine

**Goal:** A single, auditable state machine every other contract respects.

**Sub-phases**
5.1 Define states: `Created → Active → Closed → Proposed → Disputed? → Resolved → Finalized`.
5.2 Implement transition guards and `onlyState` modifiers.
5.3 Implement `close()` (after deadline, permissionless).
5.4 Implement `proposeOutcome()` entry point (resolver role) — body wired in Phase 11.
5.5 Define `MarketStatus` enum + getters; emit `MarketClosed`, `OutcomeProposed`, etc.
5.6 Add timelock/period constants (trading close, dispute window, finalization delay).
5.7 Unit tests for every legal and illegal transition (state × action matrix).
5.8 Document the state diagram in `docs/state-machine.md`.

**Deliverables**

- `PredictionMarket.sol` with full state enum + guards
- State-machine test matrix
- `docs/state-machine.md` diagram

**Exit criteria**

- No action can bypass a required state.
- The full state × action test matrix is green.

**Risks**

- Missing a transition → stuck markets. Test exhaustively now.

---

### Phase 6 — Outcome Tokens & Collateral Vault

**Goal:** YES/NO ERC-20 tokens fully backed 1:1 by collateral, with split/merge.

**Sub-phases**
6.1 Implement `OutcomeToken.sol` (ERC-20, 18 decimals or match USDC 6 — decide + document).
6.2 Deploy two tokens per market (`YES`, `NO`) from the market contract.
6.3 Implement `split(amount)`: pull USDC → mint `amount` YES + `amount` NO to caller.
6.4 Implement `merge(amount)`: burn `amount` YES + `amount` NO → return `amount` USDC.
6.5 Enforce collateral accounting: `usdc.balanceOf(market) >= totalSupply(YES)` invariant.
6.6 Add `redeem` stub (finalized in Phase 10).
6.7 Unit tests: split/merge round-trip, invariant holds, overflow/decimals edges.
6.8 Fuzz test the invariant: for random split/merge sequences, backing never breaks.

**Deliverables**

- `OutcomeToken.sol`, `split()`, `merge()` in market
- Invariant test proving full collateralization

**Exit criteria**

- `split` then `merge` returns exactly the input amount (minus zero fees).
- The collateral invariant holds under fuzzing.

**Risks**

- Decimal mismatch (USDC 6 vs token 18). Pick one and document everywhere.

---

### Phase 7 — AMM Pricing Engine (CPMM)

**Goal:** Constant-product pricing over YES/NO with correct, fully-collateralized swaps.

**Sub-phases**
7.1 Implement `AMM.sol` (or library) holding YES/NO reserves.
7.2 Seed initial liquidity from market creation (split initial USDC → YES+NO into pool).
7.3 Implement `getAmountOut(reserveIn, reserveOut, amountIn)` (0.3% or configurable fee).
7.4 Implement `quoteBuy(outcome, collateralIn)` and `quoteSell(outcome, sharesIn)` views.
7.5 Implement the swap primitive: buy = split collateral → add opposite token to pool → send wanted token out.
7.6 Enforce `x·y ≥ k` invariant after every swap (with fee accounting).
7.7 Track reserves; expose `getReserves()` and implied probability `priceYes = reserveNo / (reserveYes + reserveNo)` (document formula).
7.8 Unit tests: price monotonicity, no free money, fee accrual, edge reserves.
7.9 Fuzz/invariant tests: `k` never decreases; pool always fully backed.

**Deliverables**

- `AMM.sol` with quote + swap
- Pricing formula documented in `docs/amm.md`
- Invariant tests for `k` and backing

**Exit criteria**

- Buying YES always raises YES price; selling lowers it.
- No sequence of trades can drain collateral or break `k`.
- Implied probability is always within (0, 1).

**Risks**

- The #1 place to lose money/bugs. Do not move on until invariants pass.

---

### Phase 8 — Trading Engine (fees, slippage, events)

**Goal:** User-facing buy/sell that is safe, bounded, and fully evented.

**Sub-phases**
8.1 Implement `buy(outcome, collateralIn, minSharesOut, deadline)`.
8.2 Implement `sell(outcome, sharesIn, minCollateralOut, deadline)`.
8.3 Add slippage protection via `min/max` params + deadline (revert on violation).
8.4 Route fees: LP share + protocol treasury share; emit fee events.
8.5 Emit canonical events: `Trade(user, market, outcome, side, shares, collateral, fee, price)`.
8.6 Add reentrancy guards + checks-effects-interactions ordering.
8.7 Implement ERC-20 approval flow (user approves USDC to market) — EIP-2612 deferred to Phase 20.
8.8 Integration tests: full buy→sell round-trip, slippage reverts, fee math, event contents.
8.9 Gas snapshot of buy/sell.

**Deliverables**

- `buy`/`sell` end-to-end with events + fees
- Integration tests + gas report

**Exit criteria**

- A user can buy YES, then sell YES, and receive the correct net collateral.
- Slippage/deadline violations revert with clear custom errors.
- Every state change emits an indexable event.

**Risks**

- Fee math rounding. Use consistent rounding direction (favor the pool) and test it.

---

### Phase 9 — Liquidity Provision & LP Tokens

**Goal:** Let users provide liquidity, earn fees, and exit without breaking solvency.

**Sub-phases**
9.1 Implement LP token (ERC-20) representing pool shares.
9.2 `addLiquidity(usdcAmount)` → split → add YES+NO → mint LP tokens.
9.3 `removeLiquidity(lpAmount)` → burn LP → return proportional YES+NO → optionally merge to USDC.
9.4 Enforce that liquidity can only be added/removed while `Active` (or per rules).
9.5 Distribute accrued fees to LPs (via reserve growth or explicit fee pool).
9.6 Emit `LiquidityAdded`, `LiquidityRemoved`.
9.7 Tests: add/remove round-trip, LP share math, fees accrue to LPs, no dilution attacks.
9.8 Invariant: LP redemption never exceeds pool solvency.

**Deliverables**

- LP token + add/remove liquidity + fee distribution
- Tests + invariants

**Exit criteria**

- Two LPs can add liquidity, earn fees from trades, and withdraw proportionally.
- Removing all liquidity still leaves outstanding positions claimable at settlement.

**Risks**

- Interaction between LP exit and open positions. Test "LP leaves, then market resolves".

---

### Phase 10 — Settlement & Claim Flow

**Goal:** Winning shares redeem for 1 USDC; losers get 0; no double claims.

**Sub-phases**
10.1 Implement `redeem()` for the winning outcome token (burn → pay 1 USDC each).
10.2 Implement losing-token handling (worth 0; optional cleanup).
10.3 Add `claimed` mapping to prevent double redemption.
10.4 Handle LP token settlement (LP redeems its share of remaining collateral after claims).
10.5 Ensure pool + open positions accounting sums exactly to collateral held.
10.6 Emit `Redeemed(user, market, outcome, shares, payout)`.
10.7 Tests: winner payout, loser zero, double-claim reverts, LP + trader both claim correctly.
10.8 Invariant: total payouts ≤ total collateral (no insolvency).

**Deliverables**

- `redeem()` + claim tracking + LP settlement
- Settlement invariant tests

**Exit criteria**

- After finalization, every winner can claim exactly `shares × 1 USDC` once.
- Sum of all payouts never exceeds collateral held.

**Risks**

- Rounding dust. Decide who absorbs dust (treasury) and document it.

---

### Phase 11 — Oracle Integration

**Goal:** Objective markets resolve automatically from a trusted price feed; others via resolver.

**Sub-phases**
11.1 Implement `OracleResolver.sol` with a Chainlink `AggregatorV3Interface`.
11.2 Encode price-threshold markets: `(feed, comparator, threshold, deadline)`.
11.3 Implement `resolveFromFeed()` reading `latestRoundData()` at/after deadline (staleness checks).
11.4 Handle Chainlink edge cases: stale data, negative/zero answer, decimals.
11.5 Implement `ManualResolver` path for non-price markets (resolver role proposes outcome).
11.6 Wire resolver → `proposeOutcome()` in the market state machine.
11.7 Optional: Chainlink Automation to auto-trigger resolution at deadline.
11.8 Tests on a Base Sepolia fork: mock feed answers → correct outcome; stale feed reverts.
11.9 Document resolution criteria format in `docs/resolution.md`.

**Deliverables**

- `OracleResolver.sol`, `ManualResolver`, resolution docs
- Fork tests against real Chainlink feed

**Exit criteria**

- An ETH-price market resolves automatically from the feed on a fork.
- Stale/manipulated feed data cannot force resolution.

**Risks**

- This is the hardest correctness surface. Keep the first markets objective only.

---

### Phase 12 — Dispute Resolution & Finalization

**Goal:** A cheap, bounded challenge window before payouts unlock.

**Sub-phases**
12.1 Add `proposeOutcome(outcome)` with a proposer bond.
12.2 Add `disputeOutcome(outcome)` requiring a matching bond within the dispute window.
12.3 Add `finalize()` after the window (or after arbiter ruling) → `Finalized`.
12.4 Implement arbiter/admin resolution for disputed markets (documented trust assumption).
12.5 Bond slashing: honest party rewarded, dishonest party slashed.
12.6 Emit `OutcomeProposed`, `OutcomeDisputed`, `MarketFinalized`.
12.7 Tests: propose→finalize happy path; propose→dispute→arbiter path; bond accounting.
12.8 Document trust model + "what a real UMA integration would replace".

**Deliverables**

- Propose/dispute/finalize flow + bond logic
- Trust-model doc

**Exit criteria**

- No payout is possible before finalization.
- A disputed outcome cannot be finalized without arbiter action.
- Bonds are conserved (never lost to the void).

**Risks**

- Do not over-build arbitration. One round + admin arbiter is enough for a portfolio.

---

### Phase 13 — Contract Hardening & Test Suite

**Goal:** Production-quality confidence in the contracts before backend work.

**Sub-phases**
13.1 Reach target coverage (>90% on core contracts).
13.2 Invariant/fuzz suite: collateralization, `k` non-decrease, payout solvency.
13.3 Add Slither static analysis; fix/justify every finding.
13.4 Gas optimization pass (packed structs, custom errors, calldata) + before/after report.
13.5 Add `forge snapshot` and track regressions.
13.6 Write `docs/security.md`: threat model, trust assumptions, known limitations.
13.7 (Optional) Testnet dry run: deploy to Base Sepolia, run the full loop with a script.
13.8 Freeze the contract ABI; generate TypeScript ABIs into `packages/shared`.

**Deliverables**

- High-coverage test suite + invariants
- Slither report + gas report
- `docs/security.md`
- Frozen ABIs in `packages/shared`

**Exit criteria**

- CI enforces tests + coverage + lint on contracts.
- ABIs are generated and consumable by backend/frontend.

**Risks**

- Perfectionism. Timebox; "audit-ready" not "audited".

---

### Phase 14 — Backend Foundation (API + DB + Auth)

**Goal:** A running API with a schema that mirrors on-chain truth.

**Sub-phases**
14.1 Scaffold `packages/backend`: Express + TypeScript + Zod validation.
14.2 Configure Prisma + **Neon Postgres** (one Neon branch per dev; pooled connection for runtime, direct connection for migrations).
14.3 Design schema: `users, markets, outcomes, positions, trades, liquidity_events, resolutions, disputes, transactions, event_cursors, market_stats, notifications`.
14.4 Implement SIWE (Sign-In with Ethereum) → JWT session.
14.5 Implement health/metrics endpoints + structured logging (pino).
14.6 Add config loader (env, chain id, contract addresses, RPC URL).
14.7 Add error handling middleware + consistent API envelope.
14.8 Docker Compose: Redis for local dev (Postgres is Neon; no local PG needed).

**Deliverables**

- Running API with `/health`, `/auth/siwe`, `/auth/verify`
- Prisma schema + migrations against Neon
- Docker Compose (Redis) + Neon branch config in `.env.example`

**Exit criteria**

- Backend boots, migrates DB, and authenticates a wallet via SIWE.
- Config comes entirely from env; no hardcoded addresses.

**Risks**

- Modeling DB before indexer events are final. Revisit schema in Phase 15.

---

### Phase 15 — Blockchain Indexer

**Goal:** Reliable, reorg-safe sync of on-chain events into Neon Postgres.

**Sub-phases**
15.1 Define event decoders for every contract event (viem `parseEventLogs`).
15.2 Store a block cursor in `event_cursors`; process logs in block order.
15.3 Implement idempotent upserts keyed by `(tx_hash, log_index)`.
15.4 Add finality lag (e.g., wait N blocks) before marking rows final.
15.5 Implement reorg detection (parent hash check) + rollback of unfinalized rows.
15.6 Add backfill mode (historical range) + live mode (poll/subscribe).
15.7 Derive aggregates: `positions`, `market_stats` (volume, open interest, last price).
15.8 Add tests with a local Anvil: emit events → assert DB state; simulate reorg.
15.9 Add indexer lag/health metrics.

**Deliverables**

- `blockchain/indexer` with backfill + live modes
- Reorg handling + idempotency tests
- Derived `positions` / `market_stats`

**Exit criteria**

- Killing and restarting the indexer resumes exactly where it left off.
- Replaying the same block twice produces identical DB state.
- A simulated reorg rolls back correctly.

**Risks**

- This is where most "Web3 backend" projects break. Budget extra time here.

---

### Phase 16 — Domain Modules, Workers & Notifications

**Goal:** Clean REST APIs over indexed data + background jobs.

**Sub-phases**
16.1 `markets` module: list, filter, detail, search, pagination.
16.2 `trading` module: build unsigned tx payloads (quote + calldata) for the frontend.
16.3 `portfolio` module: user positions, PnL, claimable amounts, history.
16.4 `analytics` module: volume, probability history, leaderboards.
16.5 `oracle`/`resolution` module: resolution status, evidence, dispute info.
16.6 BullMQ workers: `event-sync` (safety net), `market-resolution` (trigger resolution at deadline), `notification` (email/Telegram optional).
16.7 Retries + dead-letter queue + idempotency keys.
16.8 Notifications: trade confirmations, market closed, resolution available, claim ready.
16.9 API tests (integration) + OpenAPI/Swagger docs.

**Deliverables**

- REST modules + OpenAPI docs
- BullMQ workers + DLQ
- Notification pipeline

**Exit criteria**

- Frontend can fetch everything it needs from documented endpoints.
- Resolution worker can auto-close and trigger resolution for matured markets.
- Failed jobs retry and surface in a dead-letter queue.

**Risks**

- Duplicating on-chain logic in backend. Backend _reads_ chain; it never _decides_ outcomes.

---

### Phase 17 — Realtime Layer

**Goal:** Live probability and price updates without polling.

**Sub-phases**
17.1 Add WebSocket/SSE server (Express + `ws`, or SSE route).
17.2 Publish channel events from the indexer (`market:{id}:trades`, `market:{id}:price`).
17.3 Client subscription protocol + auth for private channels (portfolio).
17.4 Throttle/coalesce high-frequency updates.
17.5 Reconnect + replay from last cursor.
17.6 Load test (many subscribers) + memory/backpressure checks.
17.7 Document the realtime protocol.

**Deliverables**

- WS/SSE server + pub/sub
- Reconnect/replay protocol
- Load test results

**Exit criteria**

- A trade on-chain updates all subscribed clients' implied probability in near real time.
- Clients can reconnect and catch up without missing events.

**Risks**

- Redis pub/sub vs in-process. Use Redis so it survives restarts and scales.

---

### Phase 18 — Frontend Foundation & Wallet

**Goal:** The app shell: wallet connect, auth, layout, design system.

**Sub-phases**
18.1 Scaffold `packages/web`: Next.js (App Router) + TypeScript + Tailwind + shadcn/ui.
18.2 Configure thirdweb SDK (client + `ConnectButton`) for Base Sepolia; reads/writes via `useReadContract` / `useSendTransaction`.
18.3 Implement SIWE login → session cookie → authenticated API client.
18.4 Build layout: nav, network guard (wrong-network banner), footer, toasts.
18.5 Set up TanStack Query + typed API client generated from OpenAPI.
18.6 Build reusable components: `Button`, `Card`, `PriceBadge`, `ProbabilityBar`, `TxButton`.
18.7 Add loading/error/empty states + skeleton loaders.
18.8 Add a faucet page to mint mock USDC.

**Deliverables**

- Next.js shell + wallet connect + SIWE session
- Design system primitives + faucet

**Exit criteria**

- A user can connect a wallet, sign in, and see their address in the nav.
- Wrong network is detected and handled gracefully.

**Risks**

- Wallet/network config churn. Pin chain + RPC in one config module.

---

### Phase 19 — Market Discovery, Trading & Portfolio UI

**Goal:** The full user-facing product loop, end to end.

**Sub-phases**
19.1 Markets list: cards with question, probability bar, volume, deadline, status filters.
19.2 Market detail: probability chart, order form, liquidity info, resolution criteria.
19.3 Trade flow: quote → approve USDC → sign `buy`/`sell` → toast + optimistic update.
19.4 Realtime price updates wired to the chart.
19.5 Portfolio: positions, value, PnL, claimable, transaction history.
19.6 Create-market flow (form → validate → deploy via factory → redirect).
19.7 Resolution/dispute UI: propose outcome, dispute, finalize, evidence display.
19.8 Claim flow: show claimable → redeem → update balances.
19.9 Responsive polish + accessibility (keyboard, contrast, ARIA).
19.10 E2E test (Playwright): connect → buy → resolve → claim.

**Deliverables**

- Full market/trading/portfolio/create/resolve/claim UI
- Playwright E2E happy path
- Responsive + a11y pass

**Exit criteria**

- A new user can go from faucet → buy YES → see probability move → claim after resolution.
- The Playwright happy path is green in CI.

**Risks**

- This is the biggest phase. Reuse components aggressively; do not gold-plate visuals.

---

### Phase 20 — Advanced Features, Deployment & Launch

**Goal:** Ship it: deployed, documented, demoable, and polished.

**Sub-phases**
20.1 AI market insights: summarize news/sentiment per market (clearly non-authoritative).
20.2 Gas optimization + EIP-2612 permit-based approvals (if time).
20.3 Analytics dashboard: volume, probability history, top traders.
20.4 Deploy top-level contracts to Base Sepolia via thirdweb CLI; verify on Basescan; seed demo markets (factory deploys per-market contracts at runtime).
20.5 Deploy backend (Fly/Railway) + Neon Postgres + managed Redis; run indexer + workers.
20.6 Deploy frontend (Vercel) with production env + RPC.
20.7 Monitoring: uptime, indexer lag, error tracking (Sentry), alerting.
20.8 Write `README`, architecture diagram, demo video, and "how it works" doc.
20.9 Final security/limitations writeup + roadmap-next doc.
20.10 Portfolio package: screenshots, metrics, what-you-learned, resume bullets.

**Deliverables**

- Live app on Base Sepolia
- Verified contracts + monitoring
- Docs + demo video + resume package

**Exit criteria**

- A stranger can open the URL, get test USDC, trade, and claim.
- All services are monitored and restart-safe.
- You have a 3-minute demo recording and a one-page architecture summary.

**Risks**

- Deployment surprises (RPC limits, CORS, env). Do a staging deploy in Phase 18/19 early.

---

## 4. Minimum path (if you must compress)

If time is tight, this subset still produces a credible end-to-end demo:

> Phases **1–8 → 10 → 11 → 13 → 14–15 → 16 (markets/trading/portfolio only) → 18–19 → 20 (deploy only)**

Defer: LP tokens (9), full disputes (12, keep a simple admin resolve), realtime (17), AI/analytics (20.x).

This still shows: contracts, AMM, oracle resolution, indexer, API, and a real UI.

---

## 5. Global Definition of Done (the whole project)

PredictX is "done" when all of these are true:

- [ ] Contracts deploy to Base Sepolia, verified, with high test coverage + invariants.
- [ ] A market can be created, traded (buy + sell), provided with liquidity, resolved, disputed (optional), finalized, and claimed.
- [ ] The backend indexes all events reorg-safely and serves the full API.
- [ ] The frontend lets a new user go faucet → trade → resolve → claim without help.
- [ ] CI is green (lint, typecheck, tests, coverage).
- [ ] Monitoring, docs, and a demo video exist.
- [ ] Every "cut" decision in §1 is documented with rationale.

---

## 6. Working rules for every phase

1. **One phase = one PR (or a small set of PRs).** Do not start the next until exit criteria pass.
2. **Test before moving on.** Every phase ends with tests, not just code.
3. **Update `PROJECT_PLAN.md`** if a decision changes — the docs are the source of truth.
4. **Never add real money.** Testnet + mock USDC only.
5. **Commit messages** reference the phase: `feat(phase-07): CPMM swap + invariants`.
6. **Timebox.** If a phase overruns >50%, cut scope inside it and log the tradeoff.
7. **Write the Phase Completion Report (§7) before marking a phase done.** No report = not complete.

---

## 7. Phase Completion Report (mandatory after every phase)

At the **end of every phase**, before starting the next one, write a report. This is not optional —
a phase is only "complete" when its report exists and the exit criteria are green.

**Where to put it:**

- Create `reports/phase-XX.md` (one file per phase), **and**
- Paste the same summary into the phase's PR description, **and**
- Append a 3-line summary to `reports/PROGRESS.md`.

**What it must contain (all 9 sections):**

| #   | Section                         | What to answer                                                                                                                    |
| --- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Phase identity**              | Phase number + name; which **part of the project** it belongs to (e.g. "Contracts → AMM", "Backend → Indexer").                   |
| 2   | **Scope planned**               | The sub-phases and deliverables listed in this file for that phase.                                                               |
| 3   | **What was done**               | What actually shipped, mapped to the sub-phase numbers.                                                                           |
| 4   | **What was skipped / deferred** | Anything cut from the phase, **and why** (time, complexity, dependency). Never leave this blank — if nothing was cut, say "none". |
| 5   | **File changes**                | Added / modified / deleted files, with **lines added / removed** (from `git diff --stat`). Include total LOC delta.               |
| 6   | **Effects / impact**            | What now works, behavior changes, new risks or tech debt introduced, anything that affects later phases.                          |
| 7   | **Verification**                | Tests run, coverage %, gas snapshot delta, CI status, manual checks performed.                                                    |
| 8   | **Progress**                    | Overall project progress: phases complete / 20, rough % done, on-track vs. behind schedule, and what remains.                     |
| 9   | **Blockers & next**             | Open issues, known bugs, and the exact next phase to start.                                                                       |

**Copy-paste template:**

```markdown
# Phase XX — <Name>

## 1. Phase identity

- Phase: XX / 20
- Name: <phase name>
- Project part: <e.g. Contracts → AMM>

## 2. Scope planned

- <sub-phase 1>
- <sub-phase 2>

## 3. What was done

- <what shipped, per sub-phase>

## 4. What was skipped / deferred

- <item> — reason: <why> (or "None")

## 5. File changes

| Type     | File           | Lines +/- |
| -------- | -------------- | --------- |
| Added    | `path/to/file` | +120      |
| Modified | `path/to/file` | +18 / -4  |
| Deleted  | `path/to/file` | -30       |

- **Total:** +X / -Y across N files (`git diff --stat`)

## 6. Effects / impact

- <what now works>
- <behavior changes>
- <new risks / tech debt>

## 7. Verification

- Tests: <pass/fail counts>
- Coverage: <X%>
- Gas snapshot: <delta>
- CI: <green/red>
- Manual: <what you clicked/ran>

## 8. Progress

- Phases complete: XX / 20 (<%>)
- Overall estimate: <%> done
- Schedule: <on track / X days behind>
- Remaining: <summary>

## 9. Blockers & next

- Blockers: <none / list>
- Next phase: Phase YY — <name>
```

**How to get the numbers quickly:**

```bash
# per-phase diff vs. the previous phase tag/commit
git diff --stat <last-phase-tag>..HEAD
git diff --shortstat <last-phase-tag>..HEAD      # "N files changed, X insertions(+), Y deletions(-)"

# coverage + gas (contracts)
forge coverage --report summary
forge snapshot --diff
```

Tag each completed phase so diffs are trivial next time:

```bash
git tag phase-07-complete
```

**Rule of thumb for §4:** if you skipped something from the phase's plan, it must also be
re-added to a later phase in this file (or moved to the "deferred" list in `PROJECT_PLAN.md`).
Nothing silently disappears.
