# ADR 0004 — Pricing: constant-product market maker (CPMM)

- **Status:** Accepted
- **Date:** 2026-11-12
- **Deciders:** Project author
- **Phase:** 1

## Context

Prices must emerge from supply/demand rather than being set by an admin. The main candidates are a
constant-product AMM (CPMM), an LMSR (Logarithmic Market Scoring Rule), a central limit order book
(CLOB), or fixed odds. We must pick the option with the best correctness/effort ratio while still
demonstrating real market microstructure.

## Decision

Use a **constant-product AMM (`x·y = k`) over the YES/NO outcome tokens**, fully collateralized by
USDC.

- The pool holds YES and NO reserves.
- Initial liquidity is seeded by splitting USDC into YES + NO and depositing both into the pool.
- Buying an outcome:
  1. Pull `C` USDC from the user.
  2. Split `C` → `C` YES + `C` NO.
  3. Add the **opposite** outcome leg to the pool reserves.
  4. Send the **desired** outcome leg (minus fee) to the user.
  5. Enforce `x·y ≥ k` after the swap.
- Selling reverses the flow and merges the resulting pair back into USDC.
- **Fee:** configurable (default ~2%), split between LPs and a protocol treasury.
- **Slippage/deadline:** every trade takes `minSharesOut` / `maxCollateralOut` + `deadline`.
- **Implied probability:** `pYes = reserveNo / (reserveYes + reserveNo)`.

## Consequences

**Positive**

- Proven, simple, well-understood math; no novel mechanism to get wrong.
- Always liquid — users can trade at any time, unlike an order book.
- Continuous price discovery → a live implied probability for the UI.
- Clean invariants to fuzz: `k` never decreases; pool stays fully backed.

**Negative / trade-offs**

- **Impermanent loss / LP risk** for liquidity providers.
- Capital-inefficient for large trades; slippage grows with size.
- Price can be moved by a single large trade (no order-book depth).
- Requires careful fee/rounding handling so the pool never becomes insolvent.

## Alternatives considered

| Option                   | Why rejected                                                                                               |
| ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| LMSR                     | Elegant bounded-loss market maker, but more complex math, harder to audit, and less familiar to reviewers. |
| CLOB (order book)        | Highest realism but requires off-chain matching, settlement, and much more engineering — out of MVP scope. |
| Fixed odds by admin      | No real price discovery; not a market.                                                                     |
| Uniswap V2 fork directly | Same math, but we need split/merge + binary-market semantics, so a purpose-built CPMM is cleaner.          |

## Required invariants (tested in Phase 7/13)

- `reserveYes * reserveNo >= k_previous` after every swap.
- The pool's collateral backing is always sufficient for all outstanding YES/NO.
- `0 < pYes < 1` for any non-empty pool.
- No sequence of buys/sells can extract more collateral than deposited (minus fees).

## Related

- `PROJECT_PLAN.md` §8 (core math)
- `PHASES.md` Phases 7, 8, 9, 13
- ADR 0003 (token model)
