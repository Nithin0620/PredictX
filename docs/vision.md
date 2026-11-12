# PredictX — Vision (one page)

## One-liner

A Polymarket-style **binary prediction market** on **Base Sepolia** with real ERC-20 outcome tokens,
a fully-collateralized **CPMM** AMM, **Chainlink** oracle resolution, and a reorg-safe event-driven
backend — built end to end, testnet only.

## What it is

PredictX lets anyone:

1. **Create** a YES/NO market on an objective future event (e.g. _"Will ETH/USD be ≥ $5,000 on
   2027-12-31?"_).
2. **Trade** YES/NO shares against an on-chain AMM that turns crowd demand into an implied
   probability.
3. **Provide liquidity** and earn trading fees.
4. **Resolve** the market via a Chainlink price feed (or a manual resolver for non-price markets),
   followed by a short **dispute window**.
5. **Redeem** winning shares for **1 test-USDC each**.

Trading, liquidity, resolution, and settlement are enforced **on-chain**. The backend only provides
fast reads, discovery, analytics, and UX. **The chain is the authority; the database is a
rebuildable index.**

## Who it's for

- **The author**, as a final-year-quality portfolio project demonstrating full-stack Web3
  engineering (contracts + backend + frontend + oracles + indexing).
- **Reviewers/recruiters** who want to see real on-chain financial logic, not a blockchain-backed
  CRUD app.
- **Testers** who want to try a prediction market safely with free test tokens.

## Why it matters (what it demonstrates)

- On-chain **market microstructure**: AMM pricing, slippage, fees, liquidity, solvency.
- **Oracle integration** — the genuinely hard part of prediction markets.
- **Event-driven backend** — indexers, cursors, finality, reorgs, idempotency, workers.
- **Full product** — wallet auth (SIWE), realtime probabilities, portfolio/PnL, resolution flows.
- **Correctness discipline** — fuzz/invariant tests for financial invariants.

## Success criteria

A stranger can, unaided:

1. Open the deployed app and connect a Base Sepolia wallet.
2. Get test USDC from the faucet.
3. Open a market and see its implied probability.
4. Buy YES and watch the probability move in real time.
5. See a matured market resolve via Chainlink.
6. Claim winnings after finalization.
7. Verify the trade and payout on Basescan.

If all seven work smoothly, the project succeeds.

## Non-goals (explicit)

- **No real money / no mainnet.** Testnet + mock USDC only, for safety and regulatory reasons.
- **No multi-outcome markets** (binary only).
- **No order book / CLOB / LMSR.**
- **No sports or subjective markets** — objective price markets only.
- **No fully decentralized arbitration** — a simplified bonded dispute + admin arbiter.
- **No AI as a resolver** — AI is insights-only, never authoritative.
- **No mobile app** — responsive web only.

## Constraints & principles

- **Testnet only**, mock USDC with a faucet.
- **Chain = source of truth**; backend never decides outcomes.
- **Objective markets first**; subjective resolution is a future problem.
- **Correctness before features**: invariants and tests gate every phase.
- **Document every "cut"** — nothing silently disappears (see `PHASES.md` §1 and §7).

## The loop we are building

```
faucet → create/open market → buy YES/NO → probability moves
      → deadline → oracle proposes outcome → dispute window → finalize → claim
```

Everything else is in service of making that loop reliable, observable, and pleasant to use.

## Where to look next

- `PROJECT_PLAN.md` — what we're building and how the pieces fit.
- `PHASES.md` — the 20-phase execution roadmap + per-phase completion reports.
- `docs/adr/` — why each major technical decision was made.
- `docs/demo-script.md` — the exact end-to-end demo.
