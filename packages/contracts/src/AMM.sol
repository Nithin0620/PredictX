// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Outcome } from "./MarketTypes.sol";

/**
 * @title AMM
 * @notice Constant-product (`x·y = k`) pricing over a market's YES/NO reserves.
 * @dev The market owns the pool state and token balances; this library owns the math and reserve
 * updates. Fees are taken from the output and retained in the pool (Phase 8 routes LP/protocol
 * shares). See `docs/amm.md` for the formulas and invariants.
 */
library AMM {
    uint256 internal constant BPS = 10_000;

    struct Pool {
        uint256 reserveYes;
        uint256 reserveNo;
    }

    error InsufficientLiquidity();
    error InvalidOutcome();
    error InvalidSell();

    /**
     * @notice CPMM output for `amountIn` of `reserveIn`, with `feeBps` taken from the output.
     * @dev Returns the net output and the fee retained by the pool. Reverts on an empty pool.
     */
    function getAmountOut(uint256 reserveIn, uint256 reserveOut, uint256 amountIn, uint16 feeBps)
        internal
        pure
        returns (uint256 amountOut, uint256 fee)
    {
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        if (amountIn == 0) return (0, 0);

        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        uint256 grossOut = numerator / denominator;
        fee = (numerator * feeBps + denominator * BPS - 1) / (denominator * BPS);
        if (fee > grossOut) fee = grossOut;
        amountOut = grossOut - fee;
    }

    /// @notice Quote a buy: `collateralIn` USDC is split, the opposite leg is swapped for the outcome.
    function quoteBuy(Pool memory pool, Outcome outcome, uint256 collateralIn, uint16 feeBps)
        internal
        pure
        returns (uint256 sharesOut, uint256 fee)
    {
        (sharesOut, fee,) = applyBuy(pool, outcome, collateralIn, feeBps);
    }

    /// @notice Quote a sell: `sharesIn` outcome tokens are swapped for the opposite leg and merged.
    function quoteSell(Pool memory pool, Outcome outcome, uint256 sharesIn, uint16 feeBps)
        internal
        pure
        returns (uint256 collateralOut, uint256 fee)
    {
        (collateralOut, fee,) = applySell(pool, outcome, sharesIn, feeBps);
    }

    /**
     * @notice Apply a buy to a memory copy of the pool.
     * @dev Caller must split `collateralIn` USDC and mint both legs to the market before/atomically
     * with this update. Returns the user's shares (split leg + pool output), the fee, and the pool.
     */
    function applyBuy(Pool memory pool, Outcome outcome, uint256 collateralIn, uint16 feeBps)
        internal
        pure
        returns (uint256 sharesOut, uint256 fee, Pool memory next)
    {
        if (collateralIn == 0) return (0, 0, pool);
        if (pool.reserveYes == 0 || pool.reserveNo == 0) revert InsufficientLiquidity();

        next = pool;
        if (outcome == Outcome.Yes) {
            uint256 yesOut;
            (yesOut, fee) = getAmountOut(pool.reserveNo, pool.reserveYes, collateralIn, feeBps);
            next.reserveNo += collateralIn;
            next.reserveYes -= yesOut;
            sharesOut = collateralIn + yesOut;
        } else if (outcome == Outcome.No) {
            uint256 noOut;
            (noOut, fee) = getAmountOut(pool.reserveYes, pool.reserveNo, collateralIn, feeBps);
            next.reserveYes += collateralIn;
            next.reserveNo -= noOut;
            sharesOut = collateralIn + noOut;
        } else {
            revert InvalidOutcome();
        }
    }

    /**
     * @notice Apply a sell to a memory copy of the pool.
     * @dev Solves the fee-adjusted quadratic for the amount merged (`collateralOut`); the remaining
     * `sharesIn - collateralOut` is the YES/NO leg actually sold into the pool.
     */
    function applySell(Pool memory pool, Outcome outcome, uint256 sharesIn, uint16 feeBps)
        internal
        pure
        returns (uint256 collateralOut, uint256 fee, Pool memory next)
    {
        if (sharesIn == 0) return (0, 0, pool);
        if (pool.reserveYes == 0 || pool.reserveNo == 0) revert InsufficientLiquidity();

        uint256 reserveSold;
        uint256 reserveOpp;
        if (outcome == Outcome.Yes) {
            reserveSold = pool.reserveYes;
            reserveOpp = pool.reserveNo;
        } else if (outcome == Outcome.No) {
            reserveSold = pool.reserveNo;
            reserveOpp = pool.reserveYes;
        } else {
            revert InvalidOutcome();
        }

        uint256 net = _solveSell(reserveSold, reserveOpp, sharesIn, feeBps);
        if (net >= sharesIn || net >= reserveOpp) revert InvalidSell();

        uint256 input = sharesIn - net;
        uint256 gross = (input * reserveOpp) / (reserveSold + input);
        if (net > gross) {
            net = gross;
            input = sharesIn - net;
            gross = (input * reserveOpp) / (reserveSold + input);
        }
        fee = gross - net;

        next = pool;
        if (outcome == Outcome.Yes) {
            next.reserveYes += input;
            next.reserveNo -= net;
        } else {
            next.reserveNo += input;
            next.reserveYes -= net;
        }
        collateralOut = net;
    }

    /**
     * @dev Solve `n = (BPS - feeBps) * reserveOpp * (S - n) / (BPS * (reserveSold + S - n))`.
     * Rearranged to `A·n² - (A·(rSold+S) + B·rOpp)·n + B·rOpp·S = 0`, taking the smaller root.
     */
    function _solveSell(uint256 reserveSold, uint256 reserveOpp, uint256 sharesIn, uint16 feeBps)
        private
        pure
        returns (uint256 net)
    {
        uint256 a = BPS;
        uint256 b = BPS * (reserveSold + sharesIn) + (BPS - feeBps) * reserveOpp;
        uint256 c = (BPS - feeBps) * reserveOpp * sharesIn;
        uint256 discriminant = b * b - 4 * a * c;

        net = (b - sqrt(discriminant)) / (2 * a);
    }

    /// @dev Babylonian square root (floor).
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
