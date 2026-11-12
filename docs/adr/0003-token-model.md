# ADR 0003 — Outcome token model

- **Status:** Accepted
- **Date:** 2026-11-12
- **Deciders:** Project author
- **Phase:** 1

## Context

A prediction market needs a representation of YES and NO positions. Options range from an internal
ledger inside the market contract to standard, transferable ERC-20/ERC-1155 tokens. The choice
affects composability, complexity, gas, and how much of the project is "real Web3" versus a database
with extra steps.

## Decision

Use **per-market ERC-20 outcome tokens**:

- Each market deploys **two ERC-20 tokens**: `YES` and `NO`.
- Collateral is **`MockUSDC`** (ERC-20, **6 decimals**).
- `split(amount)` locks `amount` USDC and mints `amount` YES + `amount` NO.
- `merge(amount)` burns `amount` YES + `amount` NO and returns `amount` USDC.
- Liquidity providers receive a separate **LP ERC-20 token** per market.
- Only the market contract may mint/burn outcome tokens.

**Decimals:** outcome tokens use **6 decimals** to match USDC, so 1 share ↔ 1 USDC unit and payout
math is exact with no scaling. This is documented everywhere to avoid 6-vs-18 confusion.

## Consequences

**Positive**

- Transferable, composable positions (future wallets, secondary markets, collateralization).
- Standard ERC-20 tooling (thirdweb, explorers, indexers) works out of the box.
- The 1:1 split/merge primitive gives a clean, testable solvency invariant.
- Matching decimals eliminates rounding surprises.

**Negative / trade-offs**

- One contract deployment per market per token → higher gas than an internal ledger (acceptable on
  testnet; a clone/proxy factory is a future optimization).
- Users must manage token approvals for trading (EIP-2612 permit deferred to Phase 20).
- More events to index.

## Alternatives considered

| Option                                       | Why rejected                                                                                           |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Internal share ledger in the market contract | Simpler/gas-cheaper but not composable and less impressive; harder to demonstrate real Web3 ownership. |
| ERC-1155 (single contract, two IDs)          | Cheaper deploys, but ERC-20 per outcome integrates more cleanly with AMM/LP and existing tooling.      |
| Gnosis Conditional Tokens framework          | Powerful but heavy; overkill for binary markets and adds a large dependency.                           |
| ERC-20 with 18 decimals                      | Mismatch with 6-decimal USDC forces scaling/rounding logic.                                            |

## Invariants this creates

- `usdc.balanceOf(market) >= totalSupply(YES)` (full collateralization).
- `totalSupply(YES) == totalSupply(NO)` at all times in the split model.
- `split(x)` then `merge(x)` returns exactly `x` (absent fees).

## Related

- `PROJECT_PLAN.md` §7 (contracts), §8.1 (collateralization)
- `PHASES.md` Phases 4, 6, 7, 10
- ADR 0004 (pricing/AMM)
