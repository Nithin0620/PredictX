# ADR 0006 — Dispute resolution & trust model

- **Status:** Accepted (simplified for MVP)
- **Date:** 2026-11-12
- **Deciders:** Project author
- **Phase:** 1

## Context

A proposed outcome must not be immediately payable, or a malicious/incorrect resolver could drain a
market. Real systems (UMA, Kleros) use bonded optimistic oracles with escalation. Building a fully
decentralized arbitration layer is a multi-week project on its own and is out of scope.

## Decision

Implement a **single-round bonded propose/challenge flow with an admin arbiter**:

1. **Propose:** resolver calls `proposeOutcome(outcome)` and posts a **bond**.
2. **Dispute window:** e.g. **2 hours on testnet** (24h realistic). Anyone may call
   `disputeOutcome(outcome)` with a **matching bond**.
3. **No dispute:** after the window, anyone calls `finalize()` → market `Finalized`.
4. **Dispute:** market enters `Disputed`; a trusted **arbiter** reviews evidence and finalizes the
   correct outcome.
5. **Bonds:** honest party is rewarded, dishonest party is slashed; bonds are always conserved
   (never sent to the void).

**State machine (authoritative):**

```
Created → Active → Closed → Proposed → (Disputed) → Finalized
```

No payout (`redeem`) is possible before `Finalized`.

## Consequences

**Positive**

- Prevents instant bad resolution — there is always a challenge window.
- Bonded challenges create real economic disincentive against lying.
- Small, auditable surface area; realistic to finish solo.
- Clear upgrade path to UMA-style optimistic resolution later.

**Negative / trade-offs**

- **Trusted arbiter** is a centralization point (explicitly documented, not hidden).
- Bond sizing is a heuristic; too low invites griefing, too high blocks honest disputes.
- One dispute round only (no escalation ladder).
- Dispute windows add latency to payouts.

## Alternatives considered

| Option                        | Why rejected                                                      |
| ----------------------------- | ----------------------------------------------------------------- |
| No dispute mechanism          | Resolver could finalize a wrong outcome instantly — unacceptable. |
| Full UMA Optimistic Oracle    | Best-in-class but heavy integration; deferred as future work.     |
| Multi-sig council arbitration | Similar trust to arbiter but more moving parts.                   |
| Token-holder vote             | Complex, sybil-prone, slow; overkill for MVP.                     |

## What "real" would look like (future work)

- Replace the arbiter with an optimistic oracle + escalation game (UMA).
- Add appeal rounds with increasing bonds.
- Decentralize the resolver set / use multiple independent feeds.

## Related

- `PROJECT_PLAN.md` §9, §12
- `PHASES.md` Phase 12
- ADR 0005 (oracle resolution)
