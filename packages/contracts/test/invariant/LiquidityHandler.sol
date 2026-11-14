// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../../src/MockUSDC.sol";
import { PredictionMarket } from "../../src/PredictionMarket.sol";

/// @notice Random add/remove-liquidity actions against a seeded market.
contract LiquidityHandler is Test {
    PredictionMarket public immutable market;
    MockUSDC public immutable usdc;
    address public immutable actor;

    constructor(PredictionMarket market_, MockUSDC usdc_, address actor_) {
        market = market_;
        usdc = usdc_;
        actor = actor_;
    }

    function addLiquidity(uint256 amount) external {
        uint256 balance = usdc.balanceOf(actor);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);

        vm.prank(actor);
        market.addLiquidity(amount);
    }

    function removeLiquidity(uint256 amount) external {
        uint256 balance = market.lpToken().balanceOf(actor);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);

        vm.prank(actor);
        market.removeLiquidity(amount);
    }

    function merge(uint256 amount) external {
        uint256 yesBalance = market.yesToken().balanceOf(actor);
        uint256 noBalance = market.noToken().balanceOf(actor);
        uint256 maxAmount = yesBalance < noBalance ? yesBalance : noBalance;
        if (maxAmount == 0) return;
        amount = bound(amount, 1, maxAmount);

        vm.prank(actor);
        market.merge(amount);
    }
}
