# AMM Pricing Engine (CPMM)

Phase 7 implements a constant-product market maker over each market's YES/NO reserves. The market
owns the reserves and token balances; `src/AMM.sol` is a pure library for quotes and reserve math.
ADR 0004 is the design decision; this document is the formula reference.

## Pool

Each `PredictionMarket` tracks:

```solidity
struct Pool {
    uint256 reserveYes;
    uint256 reserveNo;
}
```

At seeding, the creator's `initialLiquidity` USDC is split into a complete set and both legs are
deposited:

```text
reserveYes = reserveNo = L        // 50/50 starting price
priceYes  = reserveNo / (reserveYes + reserveNo) = 0.5
```

`priceYes()` returns the implied probability in WAD (`1e18 = 100%`). It reverts with
`AMM.InsufficientLiquidity` if the pool is empty.

## Constant product and fees

```text
reserveYes · reserveNo = k
```

`feeBps` is configured per market (default `200` = 2%, capped at `1_000` = 10% by `MarketFactory`).
Fees are taken from the output and retained in the pool, so `k` never decreases. Phase 8 routes the
LP/protocol split and adds slippage/deadline parameters.

### Swap output

For an input of `amountIn` against `reserveIn`, with the other side `reserveOut`:

```text
grossOut = floor(amountIn · reserveOut / (reserveIn + amountIn))
fee      = ceil(amountIn · reserveOut · feeBps / ((reserveIn + amountIn) · 10_000))
amountOut = grossOut - fee
```

Rounding favors the pool: the output is rounded down and the fee is rounded up. The fee is clamped
to `grossOut` so an extreme `feeBps` cannot underflow.

## Buying

A buy always starts by splitting the user's USDC into a complete set, so the trade is fully
collateralized.

```text
buy(outcome = YES, collateralIn = C):
  split C USDC → C YES + C NO (minted to the market)
  swap C NO into the pool for YES:
      yesOut = getAmountOut(reserveNo, reserveYes, C)
  reserveNo  += C
  reserveYes -= yesOut
  user receives C + yesOut YES
```

Buying NO is symmetric: add `C` YES to the pool, swap for NO, and send `C + noOut` NO to the user.
The split leg is paid to the user; the swapped leg comes out of the pool. After the transfer, the
market's token balances equal the tracked reserves.

## Selling

A sell swaps the sold leg for the opposite leg, merges the resulting complete set, and pays USDC.

```text
sell(outcome = YES, sharesIn = S):
  swap S YES for NO in the pool, but merge n YES + n NO:
      n = collateralOut
      input = S - n                 // YES actually sold into the pool
      gross = input · reserveNo / (reserveYes + input)
      fee   = gross - n
  reserveYes += input
  reserveNo  -= n
  burn n YES + n NO from the market
  user receives n USDC
```

The no-fee relation is `n = reserveOpp · (S - n) / (reserveSold + S - n)`. With fee `f`:

```text
n = (1 - f) · reserveOpp · (S - n) / (reserveSold + S - n)
```

Rearranged to the quadratic solved by `AMM._solveSell`:

```text
A = 10_000
B = 10_000 · (reserveSold + S) + (10_000 - feeBps) · reserveOpp
C = (10_000 - feeBps) · reserveOpp · S

n = (B - sqrt(B² - 4AC)) / (2A)      // smaller root
```

`AMM.sqrt` is a local Babylonian implementation because OZ `Math.sqrt` requires solc `^0.8.31` and
this repo pins `0.8.24`. If integer rounding ever makes `n` exceed `gross`, `n` is clamped to
`gross` (zero fee) to keep the pool solvent.

## Invariants

- `reserveYes · reserveNo >= k₀` after every buy/sell; fees only increase `k`.
- `market.balanceOf(YES) == reserveYes` and `market.balanceOf(NO) == reserveNo`.
- `totalSupply(YES) == totalSupply(NO)` and `collateral.balanceOf(market) >= totalSupply(YES)`
  (`isFullyBacked()`).
- `0 < priceYes < 1e18` while the pool is non-empty.
- Buying YES raises `priceYes`; buying NO lowers it. Selling YES lowers it; selling NO raises it.
- No buy → sell round trip returns more USDC than it cost.

These are covered by `test/AMM.t.sol` and the stateful
`test/AMMInvariant.t.sol` (`k`, backing, reserve/balance sync, price range).

## API

| Function                                | Kind  | Notes                                            |
| --------------------------------------- | ----- | ------------------------------------------------ |
| `seedLiquidity()`                       | write | Creator-only, `Created` → `Active`; deposits `L` |
| `buy(Outcome, uint256)`                 | write | `Active` only; returns `sharesOut`               |
| `sell(Outcome, uint256)`                | write | `Active` only; returns `collateralOut`           |
| `quoteBuy(Outcome, uint256)`            | view  | Returns `(sharesOut, fee)`                       |
| `quoteSell(Outcome, uint256)`           | view  | Returns `(collateralOut, fee)`                   |
| `getAmountOut(uint256,uint256,uint256)` | view  | `(reserveIn, reserveOut, amountIn)` → net output |
| `getReserves()`                         | view  | Returns `(reserveYes, reserveNo)`                |
| `priceYes()`                            | view  | WAD probability; reverts on an empty pool        |

## Related

- `docs/adr/0004-pricing-amm.md`
- `docs/state-machine.md`
- `packages/contracts/src/AMM.sol`, `packages/contracts/src/PredictionMarket.sol`
