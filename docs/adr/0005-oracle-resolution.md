# ADR 0005 — Oracle & resolution

- **Status:** Accepted
- **Date:** 2026-11-12
- **Deciders:** Project author
- **Phase:** 1

## Context

Smart contracts cannot read external data directly. Prediction markets live or die on reliable
resolution. Resolution approaches range from a trusted backend submitting results, to Chainlink
data feeds, to a full optimistic-oracle/dispute system (UMA). Reliability is the hardest part of
this project.

## Decision

Use a **two-track resolution model**:

1. **Chainlink Price Feeds (primary)** for **objective price-threshold markets**.
   - Example: _"Will ETH/USD be ≥ $5,000 at 2027-12-31T23:59Z?"_
   - `OracleResolver` wraps `AggregatorV3Interface` and reads `latestRoundData()` at/after the
     deadline.
   - Reverts on **stale data**, **non-positive answers**, and handles feed **decimals**.
   - Calls `market.proposeOutcome(...)`; it never pays out directly.
2. **Manual resolver (fallback)** for any market that is not a pure price threshold.
   - A resolver role proposes an outcome with an evidence URL.
   - The same dispute/finalization path applies (see ADR 0006).

**Scope guard:** the MVP only ships **objective, price-feed-resolvable markets**. Sports, elections,
and subjective questions are explicitly out of scope because they require robust dispute resolution
we are not building.

## Consequences

**Positive**

- Real, automatable resolution — a genuine differentiator versus "admin clicks resolve".
- Objective criteria remove ambiguity and most dispute pressure.
- Chainlink is well-documented, battle-tested, and available on Base Sepolia.

**Negative / trade-offs**

- Limited to markets expressible as a feed + comparator + threshold + timestamp.
- Depends on feed freshness/liveness; staleness checks can delay resolution.
- Chainlink is a trust dependency (documented in the security model).
- Manual resolver is a trusted role for non-price markets.

## Alternatives considered

| Option                       | Why rejected                                                              |
| ---------------------------- | ------------------------------------------------------------------------- |
| Custom backend oracle only   | Simplest, but centralized and less impressive; kept only as fallback.     |
| Pyth Network                 | Good, but Chainlink has broader default EVM testnet coverage and docs.    |
| UMA Optimistic Oracle        | Strong decentralization but a large integration; deferred as future work. |
| AI-based resolution          | Unreliable and non-auditable; AI is insights-only, never authoritative.   |
| No oracle (creator resolves) | Too centralized; not a credible prediction market.                        |

## Trust assumptions (documented in `docs/security.md`)

- Chainlink feed is honest and timely; stale rounds cause a revert, not a bad outcome.
- Manual resolver is trusted for non-price markets.
- Resolution only _proposes_; finalization requires the dispute window (ADR 0006).

## Related

- `PROJECT_PLAN.md` §9 (resolution design), §12 (security)
- `PHASES.md` Phase 11
- ADR 0006 (dispute & trust)
