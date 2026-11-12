# PredictX — Project Plan (What We're Building & How)

> Execution roadmap lives in `PHASES.md` (20 phases, sub-levels, exit criteria).
> This document is the **single source of truth** for *what* PredictX is, *why* it exists,
> *what is in/out of scope*, and *how the pieces fit together*.

---

## 1. What is PredictX?

**PredictX** is a decentralized, oracle-powered **binary prediction market** on **Base Sepolia
(testnet only)**. Users:

1. Create YES/NO markets on objective future events (e.g. *"Will ETH be above $5,000 on 2027-12-31?"*).
2. Trade YES/NO shares against an on-chain **CPMM automated market maker** that discovers an
   implied probability.
3. Provide liquidity and earn trading fees.
4. Let an **oracle** resolve the market (Chainlink price feed for objective markets, a manual
   resolver fallback otherwise).
5. Go through a short **dispute window**, then **finalize**.
6. **Redeem** winning shares for 1 test-USDC each.

Everything financial (trading, liquidity, settlement) is enforced **on-chain**. Off-chain
infrastructure only provides **fast reads, discovery, analytics, and UX**.

**One-line pitch:** *A Polymarket-style prediction market with real outcome tokens, an AMM,
oracle resolution, and a reorg-safe event-driven backend — built end to end on Base Sepolia.*

---

## 2. Why this project (why it's a strong portfolio piece)

- **On-chain financial logic** — not just CRUD on a blockchain.
- **Real market microstructure** — AMM pricing, slippage, fees, liquidity, solvency invariants.
- **Oracles** — the genuinely hard part of prediction markets.
- **Event-driven backend** — indexers, cursors, reorgs, idempotency, workers.
- **Full-stack product** — wallet auth (SIWE), realtime UI, portfolio/PnL, resolution flows.

It demonstrates that you can **coordinate on-chain state with off-chain systems** — the thing
most "Web3 CRUD" projects never touch.

---

## 3. Scope

### 3.1 In scope (MVP → launch)

| Area | Included |
|---|---|
| Markets | Binary YES/NO only, permissionless creation |
| Tokens | ERC-20 YES/NO outcome tokens + LP token + mock USDC (6 decimals) |
| Pricing | CPMM (`x·y=k`) with configurable fee, fully collateralized |
| Trading | Buy/sell with slippage + deadline protection |
| Liquidity | Add/remove liquidity, LP fees |
| Resolution | Chainlink price-feed markets + manual resolver fallback |
| Disputes | One bonded propose/challenge round + admin arbiter |
| Settlement | Winner redeems 1 USDC/share, double-claim protection |
| Backend | REST API, Neon Postgres, reorg-safe indexer, BullMQ workers, notifications |
| Realtime | WebSocket/SSE probability + trade feed |
| Frontend | Discovery, market detail, trade, create, portfolio, resolve, claim |
| Ops | Base Sepolia deploy, CI, monitoring, docs, demo |

### 3.2 Explicitly out of scope (and why)

| Excluded | Reason |
|---|---|
| Mainnet / real money | Regulatory + safety. Testnet + mock USDC only. |
| Non-binary / multi-outcome markets | 3× complexity; binary proves the concept. |
| CLOB order book / LMSR | CPMM is proven and far cheaper to build correctly. |
| Full decentralized arbitration (UMA) | Bonded round + arbiter is enough; document as future work. |
| Sports / subjective markets | Resolution + dispute nightmare; objective price markets only. |
| AI as a resolver | AI is *insights only*, never authoritative. |
| Mobile app | Responsive web suffices. |

**Rule:** anything not required for the demo loop *faucet → trade → resolve → claim* is deferred.

---

## 4. System architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                            Browser (Next.js)                          │
│  thirdweb SDK (wallet + reads/writes) · TanStack Query · SIWE cookie   │
│  Markets · Trade · Portfolio · Create · Resolve · Claim · Realtime     │
└───────────────┬───────────────────────────────┬──────────────────────┘
                │ REST (read) + WS/SSE          │ wallet txs (write)
                ▼                               ▼
┌───────────────────────────────┐   ┌──────────────────────────────────┐
│        Backend (Express)       │   │      Base Sepolia (EVM)           │
│  auth (SIWE) · markets ·       │   │  MarketFactory · PredictionMarket │
│  trading · portfolio ·         │   │  OutcomeToken (YES/NO) · AMM · LP │
│  analytics · resolution        │   │  OracleResolver (Chainlink)       │
│                                │   │  MockUSDC · DisputeManager        │
│  ┌──────────────────────────┐  │   └────────────▲─────────────────────┘
│  │ Indexer (viem getLogs)    │──┼────────────────┘ events / reads
│  │ cursor · finality · reorg │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │ BullMQ workers            │  │
│  │ event-sync · resolution · │  │
│  │ notifications             │  │
│  └──────────────────────────┘  │
└───────┬───────────────┬────────┘
        ▼               ▼
┌──────────────┐ ┌──────────────┐
│ Neon Postgres│ │ Redis        │
│ (indexed     │ │ (queues +    │
│  chain state)│ │  pub/sub)    │
└──────────────┘ └──────────────┘
```

**Trust model:** the chain is authoritative for balances, trades, and settlement. The database is a
**fast, rebuildable index** of chain state. The backend **never** decides outcomes.

---

## 5. Technology stack

| Layer | Choice | Notes |
|---|---|---|
| Chain | **Base Sepolia** | Cheap, EVM, Chainlink feeds available |
| Contracts | **Solidity ^0.8.24 + Foundry** | Fast tests, fuzzing, invariants |
| Contract deploy | **thirdweb CLI** (`npx thirdweb deploy`) | Deploys top-level contracts; Foundry still owns testing |
| Contract libs | **OpenZeppelin Contracts** | ERC-20, AccessControl, ReentrancyGuard, SafeERC20 |
| Oracle | **Chainlink Price Feeds** (+ manual resolver) | Objective markets only |
| Backend | **Node.js + TypeScript + Express** | Zod validation, pino logging |
| ORM/DB | **Prisma + Neon Postgres** | Serverless Postgres, migrations, typed queries |
| Queue/cache | **Redis + BullMQ** | Workers, retries, pub/sub |
| Chain client | **thirdweb SDK (frontend) · viem (backend indexer)** | thirdweb v5 is built on viem |
| Auth | **SIWE → JWT session cookie** | Wallet is identity |
| Realtime | **WebSocket / SSE** | Probability + trade feed |
| Frontend | **Next.js (App Router) + TypeScript** | SSR + client components |
| Web3 UI | **thirdweb SDK** (`ConnectButton`, `useActiveAccount`, `useReadContract`, `useSendTransaction`) | Replaces wagmi + RainbowKit |
| UI | **Tailwind CSS + shadcn/ui + Recharts** | Fast, consistent design |
| Monorepo | **pnpm workspaces + Turborepo** | One install/build/test |
| CI/CD | **GitHub Actions** | Lint, typecheck, test, deploy |
| Deploy | **Vercel (web) · Fly/Railway (API) · Neon Postgres · managed Redis** | |
| Monitoring | **Sentry + uptime + indexer-lag metric** | |

---

## 6. Repository layout

```
PredictX/
├── PHASES.md                    # 20-phase execution roadmap
├── PROJECT_PLAN.md              # this file
├── docs/
│   ├── adr/                     # architecture decision records
│   ├── vision.md
│   ├── state-machine.md
│   ├── amm.md
│   ├── resolution.md
│   ├── security.md
│   └── demo-script.md
├── apps/  (or packages/)
│   ├── contracts/
│   │   ├── src/
│   │   │   ├── MockUSDC.sol
│   │   │   ├── MarketFactory.sol
│   │   │   ├── PredictionMarket.sol
│   │   │   ├── OutcomeToken.sol
│   │   │   ├── AMM.sol
│   │   │   ├── LPToken.sol
│   │   │   ├── OracleResolver.sol
│   │   │   └── DisputeManager.sol
│   │   ├── test/  (unit · integration · invariant · fork)
│   │   └── script/ (deploy)
│   ├── backend/
│   │   ├── src/
│   │   │   ├── modules/ (auth, markets, trading, portfolio, analytics, resolution)
│   │   │   ├── blockchain/ (contracts, listeners, indexer)
│   │   │   ├── workers/ (event-sync, market-resolution, notification)
│   │   │   ├── realtime/
│   │   │   ├── database/
│   │   │   └── server.ts
│   │   └── prisma/schema.prisma
│   ├── web/
│   │   └── src/app/ (markets, market/[id], portfolio, create, resolve)
│   └── shared/                  # ABIs, types, constants, addresses
└── .github/workflows/ci.yml
```

---

## 7. Smart contract specifications

### 7.1 `MockUSDC.sol`
- ERC-20, **6 decimals**, `mint()` faucet (rate-limited on testnet).
- Collateral for all markets.

### 7.2 `MarketFactory.sol`
- `createMarket(MarketConfig) → marketId`
- Deploys a `PredictionMarket` (+ its YES/NO tokens), registers it.
- Emits `MarketCreated(marketId, market, creator, question, deadline)`.
- Permissionless creation with config validation + optional anti-spam guard.

### 7.3 `PredictionMarket.sol`
Owns lifecycle + collateral vault.

**State machine**
```
Created ──seedLiquidity──► Active ──close()──► Closed
   │                          │                  │
   │                          │                  ▼
   │                          │            Proposed ──dispute()──► Disputed
   │                          │                  │                     │
   │                          │                  ▼                     ▼
   │                          │             Finalized ◄──── arbiter ruling
   │                          │                  │
   └──────────────────────────┴──────────────────┘  (all states → claimable after Finalized)
```

- `split(amount)` → mint `amount` YES + `amount` NO (locks USDC).
- `merge(amount)` → burn `amount` YES + `amount` NO → return USDC.
- `buy/sell` delegate to AMM.
- `proposeOutcome / disputeOutcome / finalize`.
- `redeem()` → winner burns shares → 1 USDC each, once.
- Invariant: `usdc.balanceOf(market) ≥ totalSupply(YES)`.

### 7.4 `OutcomeToken.sol`
- Standard ERC-20 per outcome (YES and NO), minted/burned only by the market.

### 7.5 `AMM.sol`
- Holds YES/NO reserves; constant product `x·y=k`.
- `quoteBuy / quoteSell` (view) + `swap` (internal).
- Fee split: LP share + protocol treasury share.
- Invariant: `k` never decreases; pool always fully backed by collateral.
- Implied probability: `pYes = reserveNo / (reserveYes + reserveNo)`.

### 7.6 `LPToken.sol`
- ERC-20 representing proportional pool ownership.
- Minted on `addLiquidity`, burned on `removeLiquidity`.

### 7.7 `OracleResolver.sol`
- Wraps Chainlink `AggregatorV3Interface`.
- Encodes `(feed, comparator, threshold, deadline)`.
- `resolveFromFeed()` with **staleness + decimals + non-positive answer** checks.
- Calls `market.proposeOutcome()`; never pays out directly.

### 7.8 `DisputeManager.sol`
- `proposeOutcome` requires a bond; `disputeOutcome` requires a matching bond.
- Dispute window → `finalize()`, or arbiter resolves disputed markets.
- Bond slashing: honest party rewarded, dishonest party slashed; bonds conserved.

---

## 8. Core math (the part that must be right)

### 8.1 Full collateralization
```
1 USDC ──split──► 1 YES + 1 NO
1 YES + 1 NO ──merge──► 1 USDC
```
So at all times: `collateralHeld ≥ outstanding YES + outstanding NO` (in the fully-split model).

### 8.2 CPMM trade (buy YES)
```
1. User sends C collateral.
2. Contract splits C → C YES + C NO.
3. NO leg is added to the pool reserves.
4. YES leg (minus pool output) is sent to the buyer.
5. x·y ≥ k is enforced after the swap; fee is taken from the output.
```
Selling is the reverse (return shares to the pool, receive the opposite leg, merge → USDC).

### 8.3 Implied probability
```
pYes = reserveNo / (reserveYes + reserveNo)      ∈ (0, 1)
pNo  = 1 - pYes
```
A trade that buys YES raises `pYes`; selling lowers it.

### 8.4 Payouts (after finalization)
```
payout(user) = winningShares(user) × 1 USDC      (claimable once)
losingShares → 0
LP redeems its pro-rata share of residual collateral after claims
```
Dust from rounding is absorbed by the protocol treasury (documented).

---

## 9. Market resolution design

**Objective markets only (MVP).** Example criteria:
> "ETH/USD (Chainlink feed `0x…`) close price on 2027-12-31 ≥ $5,000."

Resolution flow:
```
deadline reached
  → close()                       (anyone)
  → resolver.proposeOutcome()     (Chainlink read, or manual resolver)
  → dispute window (e.g. 2h testnet / 24h realistic)
      ├─ no dispute → finalize()  (anyone)
      └─ dispute + bonds → arbiter ruling → finalize()
  → redeem() unlocks
```

**Trust assumptions (documented in `docs/security.md`):**
- Chainlink feed is honest and fresh; staleness reverts.
- Manual resolver is trusted for non-price markets.
- Arbiter is trusted for disputed markets (future work: UMA/Optimistic Oracle).
- AI never has resolution authority.

---

## 10. Backend design

### 10.1 Modules
| Module | Responsibility |
|---|---|
| `auth` | SIWE challenge/verify, session issuance |
| `markets` | list, filter, detail, search, pagination |
| `trading` | quote + unsigned tx payloads for the frontend |
| `portfolio` | positions, PnL, claimable, history |
| `analytics` | volume, probability history, leaderboards |
| `resolution` | resolution status, evidence, dispute info |
| `realtime` | WS/SSE publish + subscribe |

### 10.2 Database schema (indexed chain state)
| Table | Key fields |
|---|---|
| `users` | id, wallet_address, created_at |
| `markets` | id, onchain_id, question, deadline, status, resolver_type, feed, threshold |
| `outcomes` | id, market_id, label (YES/NO), token_address |
| `positions` | user_id, market_id, outcome, shares, avg_price |
| `trades` | tx_hash, log_index, market_id, user_id, side, shares, collateral, fee, price |
| `liquidity_events` | tx_hash, log_index, market_id, user_id, type, amount, lp_tokens |
| `resolutions` | market_id, proposed_outcome, proposer, evidence_url, proposed_at |
| `disputes` | market_id, disputer, bond, outcome, created_at, resolved_at |
| `transactions` | tx_hash, block_number, block_hash, status, finalized |
| `event_cursors` | contract, last_block, last_block_hash |
| `market_stats` | market_id, volume, open_interest, last_price, p_yes |
| `notifications` | user_id, type, payload, read_at |

### 10.3 Indexer guarantees
- **Ordered:** process logs in block order.
- **Idempotent:** upsert keyed by `(tx_hash, log_index)`.
- **Reorg-safe:** finality lag + parent-hash check + rollback of unfinalized rows.
- **Resumable:** persisted cursor; restart continues exactly where it stopped.
- **Rebuildable:** DB can be fully rebuilt from chain history.

### 10.4 Workers (BullMQ)
- `event-sync` — safety-net polling + gap recovery.
- `market-resolution` — triggers resolution for matured markets.
- `notification` — trade/close/resolution/claim notifications.
- Retries + exponential backoff + dead-letter queue.

---

## 11. Frontend design

### Routes
| Route | Purpose |
|---|---|
| `/` | Market discovery (cards, filters, search) |
| `/market/[id]` | Probability chart, trade form, liquidity, criteria, resolution |
| `/create` | Create a market |
| `/portfolio` | Positions, PnL, claimable, history |
| `/resolve/[id]` | Propose/dispute/finalize/claim (role-aware) |
| `/faucet` | Mint mock USDC |

### Key UX flows
1. **Onboarding:** connect wallet → SIWE sign-in → faucet.
2. **Trade:** pick market → quote → approve USDC → buy → optimistic update + realtime price.
3. **Resolve:** deadline passes → resolution status → (dispute if needed) → finalize.
4. **Claim:** claimable badge → redeem → balance update.

---

## 12. Security & correctness model

- **Reentrancy:** `ReentrancyGuard` + checks-effects-interactions on all value flows.
- **Access control:** `AccessControl` for resolver/arbiter/treasury roles.
- **Math:** Solidity 0.8 checked arithmetic + explicit rounding direction.
- **Invariants (tested):** collateralization, `k` non-decrease, payout solvency, bond conservation.
- **Slippage/deadline:** every trade reverts on violation.
- **Oracle safety:** staleness + decimals + non-positive answer checks.
- **Idempotency:** indexer + workers dedupe by `(tx_hash, log_index)` / job key.
- **Secrets:** env only; `.env.example` committed, real `.env` never.
- **Testnet only:** no real funds, mock USDC with a faucet.

Known limitations (documented, not hidden): trusted arbiter, trusted manual resolver, contract-per-market
gas cost, dust handling, no formal audit.

---

## 13. Testing strategy

| Layer | Tool | Coverage target |
|---|---|---|
| Contracts unit | Foundry | >90% core |
| Contracts integration | Foundry | full trade→resolve→claim |
| Contracts invariants | Foundry fuzz/invariant | collateral, `k`, solvency, bonds |
| Oracle | Foundry fork (Base Sepolia) | feed resolution + stale revert |
| Indexer | Anvil + test DB | replay, idempotency, reorg |
| Backend API | Vitest/Supertest | module endpoints |
| E2E | Playwright | connect→faucet→trade→claim |
| Static analysis | Slither | zero unjustified findings |

---

## 14. Deployment topology

```
Contracts  → Base Sepolia (deploy via thirdweb CLI, verified on Basescan)
Frontend   → Vercel
Backend    → Fly.io / Railway (Docker)
Postgres   → Neon (serverless Postgres; pooled connection for runtime, direct for migrations)
Redis      → managed (Upstash/Railway)
Workers    → same container or separate process
Monitoring → Sentry + uptime + indexer-lag alert
```

Production checklist: env vars set, contracts verified, addresses in `packages/shared`, indexer
caught up, workers running, alerts firing, demo markets seeded.

---

## 15. Roadmap mapping

The 20 phases in `PHASES.md` map to this plan as:

| Plan area | Phases |
|---|---|
| Foundations & tooling | 1–2 |
| Chain & contract scaffolding | 3 |
| Collateral + factory | 4 |
| Lifecycle state machine | 5 |
| Outcome tokens | 6 |
| AMM pricing | 7 |
| Trading | 8 |
| Liquidity | 9 |
| Settlement & claim | 10 |
| Oracle | 11 |
| Disputes | 12 |
| Hardening & tests | 13 |
| Backend foundation | 14 |
| Indexer | 15 |
| Modules + workers | 16 |
| Realtime | 17 |
| Frontend foundation | 18 |
| Frontend product | 19 |
| Advanced + deploy | 20 |

---

## 16. Success criteria (the demo)

A reviewer should be able to, unaided:

1. Open the deployed app, connect a Base Sepolia wallet.
2. Get mock USDC from the faucet.
3. Open a market and see its implied probability.
4. Buy YES, watch the probability move in real time.
5. (Admin/resolver) see a matured market resolve via Chainlink.
6. After finalization, claim winnings.
7. See the trade and payout reflected in the portfolio and on Basescan.

If all seven work smoothly, PredictX is a success.

---

## 17. Resume / interview framing

- **"Built a decentralized prediction market (Solidity, Foundry, Base Sepolia) with ERC-20 outcome
  tokens, a fully-collateralized CPMM AMM, and Chainlink oracle resolution."**
- **"Designed a reorg-safe event indexer (viem + Neon Postgres) with cursors, idempotent upserts, and
  rollback, plus BullMQ workers for resolution and notifications."**
- **"Enforced financial invariants (collateralization, constant-product, payout solvency) via Foundry
  fuzz/invariant testing."**
- **"Shipped a full-stack Next.js + thirdweb product with SIWE auth, realtime probability updates, and
  end-to-end Playwright coverage."**

---

## 18. Glossary

| Term | Meaning |
|---|---|
| Outcome token | ERC-20 representing a YES or NO share |
| Split / Merge | Convert 1 USDC ↔ 1 YES + 1 NO |
| CPMM | Constant-product market maker (`x·y=k`) |
| Implied probability | Price of YES ≈ market's probability estimate |
| Resolution | Determining the true outcome via oracle/manual |
| Finalization | Locking the outcome after the dispute window |
| Claim / Redeem | Burning winning shares for 1 USDC each |
| Indexer | Off-chain process mirroring chain events into Neon Postgres |
| Reorg | Chain history rewrite; indexer must roll back unfinalized rows |
| SIWE | Sign-In with Ethereum (wallet-based auth) |
