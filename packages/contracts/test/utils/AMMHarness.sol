// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AMM } from "../../src/AMM.sol";
import { Outcome } from "../../src/MarketTypes.sol";

/// @notice External wrappers so tests can assert reverts from the internal AMM library.
contract AMMHarness {
    function getAmountOut(uint256 reserveIn, uint256 reserveOut, uint256 amountIn, uint16 feeBps)
        external
        pure
        returns (uint256 amountOut, uint256 fee)
    {
        return AMM.getAmountOut(reserveIn, reserveOut, amountIn, feeBps);
    }

    function applyBuy(AMM.Pool memory pool, Outcome outcome, uint256 collateralIn, uint16 feeBps)
        external
        pure
        returns (uint256 sharesOut, uint256 fee, AMM.Pool memory next)
    {
        return AMM.applyBuy(pool, outcome, collateralIn, feeBps);
    }

    function applySell(AMM.Pool memory pool, Outcome outcome, uint256 sharesIn, uint16 feeBps)
        external
        pure
        returns (uint256 collateralOut, uint256 fee, AMM.Pool memory next)
    {
        return AMM.applySell(pool, outcome, sharesIn, feeBps);
    }

    function sqrt(uint256 x) external pure returns (uint256) {
        return AMM.sqrt(x);
    }
}
