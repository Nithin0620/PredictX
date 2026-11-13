// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../../src/MockUSDC.sol";
import { PredictionMarket } from "../../src/PredictionMarket.sol";

/**
 * @notice Bounded split/merge actions for the collateral invariant fuzzer.
 * @dev `bound` keeps calls inside the actor's balances so the fuzzer explores valid state.
 */
contract CollateralHandler is Test {
    PredictionMarket public immutable market;
    MockUSDC public immutable usdc;
    address public immutable actor;

    constructor(PredictionMarket market_, MockUSDC usdc_, address actor_) {
        market = market_;
        usdc = usdc_;
        actor = actor_;
    }

    function split(uint256 amount) external {
        uint256 max = usdc.balanceOf(actor);
        if (max == 0) return;
        amount = bound(amount, 1, max);

        vm.prank(actor);
        market.split(amount);
    }

    function merge(uint256 amount) external {
        uint256 max = market.yesToken().balanceOf(actor);
        if (max == 0) return;
        amount = bound(amount, 1, max);

        vm.prank(actor);
        market.merge(amount);
    }
}
