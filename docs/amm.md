# AMM Pricing, Trading & Liquidity (CPMM)

Phases 7–10 implement a constant-product market maker over each market's YES/NO reserves, bounded
buy/sell entry points, protocol fee routing, an ERC-20 LP token, and post-finalization claims. The
market owns the reserves and token balances; `src/AMM.sol` is a pure library for quotes and reserve
math. ADR 0004 is the design decision; this document is the formula and API reference.

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
lpToken.mint(creator, L)          // one LP unit per USDC of initial liquidity
```

`priceYes()` returns the implied probability in WAD (`1e18 = 100%`). It reverts with
`AMM.InsufficientLiquidity` if the pool is empty.

## Constant product and fees

```text
reserveYes · reserveNo = k
```

`feeBps` is configured per market (default `200` = 2%, capped at `1_000` = 10% by `MarketFactory`).
Fees are taken from the output. The AMM layer leaves the full output fee in the pool; the market
then routes `PROTOCOL_FEE_SHARE_BPS = 2_000` (20%) of that fee to `treasury` in the fee outcome
token. The remaining 80% is the LP share and stays in the pool, accruing to LPs through reserve
growth. No separate fee pool or reward accounting is needed.

Protocol fee token by side:

| Action   | Fee token sent to treasury |
| -------- | -------------------------- |
| Buy YES  | YES                        |
| Buy NO   | NO                         |
| Sell YES | NO (the swapped leg)       |
| Sell NO  | YES                        |

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
      fee    = total output fee (YES units)
  reserveNo  += C
  reserveYes -= yesOut
  protocolFee = fee · 20%
  reserveYes -= protocolFee
  treasury receives protocolFee YES
  user receives C + yesOut YES
```

The LP share (`fee - protocolFee`) remains in `reserveYes`. Buying NO is symmetric: add `C` YES to
the pool, swap for NO, send `C + noOut` NO to the user, and send the protocol share in NO to the
treasury. After the transfers, the market's token balances equal the tracked reserves.

## Selling

A sell swaps the sold leg for the opposite leg, merges the resulting complete set, and pays USDC.

```text
sell(outcome = YES, sharesIn = S):
  swap S YES for NO in the pool, but merge n YES + n NO:
      n = collateralOut
      input = S - n                 // YES actually sold into the pool
      gross = input · reserveNo / (reserveYes + input)
      fee   = gross - n             // NO units
  reserveYes += input
  reserveNo  -= n
  protocolFee = fee · 20%
  reserveNo  -= protocolFee
  treasury receives protocolFee NO
  burn n YES + n NO from the market
  user receives n USDC
```

The LP share (`fee - protocolFee`) remains in `reserveNo`. The no-fee relation is
`n = reserveOpp · (S - n) / (reserveSold + S - n)`. With fee `f`:

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

## Liquidity provision

The market deploys one `LPToken` (ERC-20, 6 decimals, market-only mint/burn) per market. LP shares
represent a pro-rata claim on both reserves and on fees that have accrued into them.

```text
addLiquidity(usdcAmount = A):
  split A USDC → A YES + A NO (minted to the market)
  lpFromYes = A · totalSupply / reserveYes
  lpFromNo  = A · totalSupply / reserveNo
  mint min(lpFromYes, lpFromNo) LP to the provider
  reserveYes += A
  reserveNo  += A

removeLiquidity(lpAmount = P):
  yesOut = reserveYes · P / totalSupply
  noOut  = reserveNo  · P / totalSupply
  burn P LP
  send yesOut YES + noOut NO to the provider
```

Minting at the smaller of the two reserve ratios prevents an imbalanced pool from diluting existing
LPs. Removing liquidity returns outcome tokens, not USDC; call `merge(min(yesOut, noOut))` to
convert the complete-set portion to USDC. Both actions are `Active`-only. Removing all liquidity
burns all LP shares and returns all reserves, but outstanding user positions remain fully backed and
claimable at settlement.

## Settlement and claims

After `Finalized`, the market has exactly one winning outcome token. `redeem()` burns the caller's
entire winning balance and pays 1 USDC per share; `redeem(uint256 amount)` does the same for a
partial balance. Losing tokens are worth zero and are not burned by redemption. `claimed[account]`
tracks cumulative winning shares redeemed for indexers and analytics, while the burn itself prevents
double claims.

```text
redeem(amount = S):
  require status == Finalized
  require S > 0 and winningToken.balanceOf(user) >= S
  claimed[user] += S
  burn S winning tokens from user
  transfer S USDC to user
```

LPs settle their share of the final reserves with `redeemLiquidity(lpAmount)`:

```text
redeemLiquidity(lpAmount = P):
  yesOut = reserveYes · P / totalSupply
  noOut  = reserveNo  · P / totalSupply
  payout = proposedOutcome == Yes ? yesOut : noOut
  reserveYes -= yesOut
  reserveNo  -= noOut
  burn P LP and burn yesOut YES + noOut NO held by the market
  transfer payout USDC to the LP
```

The losing reserve is worthless, so only the winning reserve is paid. Rounding dust from partial
settlements stays in the pool for remaining LPs; a full settlement (`P == totalSupply`) returns the
entire winning reserve. User claims and LP settlement can happen in either order.

Before finalization, `isFullyBacked()` requires equal YES/NO supplies and collateral covering YES.
After finalization it only requires collateral to cover the outstanding winning supply, because
losing tokens have no claim. This keeps backing true through user redemptions and LP settlement.

## Invariants

- `reserveYes · reserveNo >= k₀` after every buy/sell while LP supply is unchanged; fees only
  increase `k`. Removing liquidity intentionally decreases reserves and `k`.
- `market.balanceOf(YES) == reserveYes` and `market.balanceOf(NO) == reserveNo`.
- Before finalization, `totalSupply(YES) == totalSupply(NO)` and
  `collateral.balanceOf(market) >= totalSupply(YES)`; after finalization,
  `collateral.balanceOf(market) >= winningSupply` (`isFullyBacked()`).
- `0 < priceYes < 1e18` while the pool is non-empty.
- Buying YES raises `priceYes`; buying NO lowers it. Selling YES lowers it; selling NO raises it.
- No buy → sell round trip returns more USDC than it cost.
- LP supply is zero iff both reserves are zero after a full exit; the market never holds LP tokens.
- LP redemption is proportional and can never exceed the pool's reserves.
- Post-finalization payouts plus remaining collateral equal the collateral at finalization; no
  sequence of user redemptions and LP settlements can overdraw the market.

These are covered by `test/AMM.t.sol`, `test/Trading.t.sol`, `test/Liquidity.t.sol`,
`test/Settlement.t.sol`, and the stateful suites `test/AMMInvariant.t.sol` (`k`, backing,
reserve/balance sync, price range), `test/LiquidityInvariant.t.sol` (LP solvency, backing,
reserve/balance sync), and `test/SettlementInvariant.t.sol` (payout bound, winning claims covered,
reserve/balance sync).

## API

| Function                                   | Kind  | Notes                                                                                     |
| ------------------------------------------ | ----- | ----------------------------------------------------------------------------------------- |
| `seedLiquidity()`                          | write | Creator-only, `Created` → `Active`; deposits `L`, mints LP                                |
| `buy(Outcome, uint256, uint256, uint256)`  | write | `Active` only; `(outcome, collateralIn, minSharesOut, deadline)`; returns `sharesOut`     |
| `sell(Outcome, uint256, uint256, uint256)` | write | `Active` only; `(outcome, sharesIn, minCollateralOut, deadline)`; returns `collateralOut` |
| `addLiquidity(uint256)`                    | write | `Active` only; splits USDC and mints LP                                                   |
| `removeLiquidity(uint256)`                 | write | `Active` only; burns LP and returns proportional YES/NO                                   |
| `redeem()`                                 | write | `Finalized` only; burns the caller's winning balance and pays 1 USDC/share                |
| `redeem(uint256)`                          | write | `Finalized` only; partial winning-share redemption                                        |
| `redeemLiquidity(uint256)`                 | write | `Finalized` only; burns LP and pays the winning reserve share in USDC                     |
| `claimed(address)`                         | view  | Cumulative winning shares redeemed by an account                                          |
| `quoteBuy(Outcome, uint256)`               | view  | Returns `(sharesOut, fee)`; `fee` is in outcome-token units                               |
| `quoteSell(Outcome, uint256)`              | view  | Returns `(collateralOut, fee)`; `fee` is in outcome-token units                           |
| `getAmountOut(uint256,uint256,uint256)`    | view  | `(reserveIn, reserveOut, amountIn)` → net output                                          |
| `getReserves()`                            | view  | Returns `(reserveYes, reserveNo)`                                                         |
| `priceYes()`                               | view  | WAD probability; reverts on an empty pool                                                 |
| `lpToken()`                                | view  | Per-market `LPToken` address                                                              |

## Events

| Event                                                                  | Meaning                                                                                                  |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `Trade(user, marketId, outcome, side, shares, collateral, fee, price)` | Canonical trade event. `fee` is USDC-valued at the pre-trade price; `price` is the post-trade WAD price. |
| `ProtocolFee(treasury, feeOutcome, amount)`                            | Protocol share transferred in the fee outcome token.                                                     |
| `LiquidityAdded(provider, collateral, lpAmount)`                       | USDC deposited and LP minted.                                                                            |
| `LiquidityRemoved(provider, lpAmount, yesOut, noOut)`                  | LP burned and outcome tokens returned.                                                                   |
| `Redeemed(user, marketId, outcome, shares, payout)`                    | Winning shares burned and USDC paid (payout equals shares).                                              |
| `LiquiditySettled(provider, lpAmount, payout)`                         | Post-finalization LP burn and winning-reserve payout.                                                    |

## Related

- `docs/adr/0004-pricing-amm.md`
- `docs/state-machine.md`
- `packages/contracts/src/AMM.sol`, `packages/contracts/src/PredictionMarket.sol`,
  `packages/contracts/src/LPToken.sol`, `packages/contracts/src/MarketDeployer.sol`
- `docs/resolution.md`
