// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../../src/MockUSDC.sol";
import { OutcomeToken } from "../../src/OutcomeToken.sol";
import { PredictionMarket } from "../../src/PredictionMarket.sol";
import { Outcome } from "../../src/MarketTypes.sol";

/// @notice Random buys, sells, splits, and merges against a seeded AMM.
contract AMMHandler is Test {
    PredictionMarket public immutable market;
    MockUSDC public immutable usdc;
    address public immutable actor;
    uint256 public immutable initialK;

    constructor(PredictionMarket market_, MockUSDC usdc_, address actor_) {
        market = market_;
        usdc = usdc_;
        actor = actor_;

        (uint256 reserveYes, uint256 reserveNo) = market_.getReserves();
        initialK = reserveYes * reserveNo;
    }

    function buy(uint256 outcomeSeed, uint256 amount) external {
        uint256 balance = usdc.balanceOf(actor);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);

        vm.prank(actor);
        market.buy(outcomeSeed % 2 == 0 ? Outcome.Yes : Outcome.No, amount);
    }

    function sell(uint256 outcomeSeed, uint256 amount) external {
        Outcome outcome = outcomeSeed % 2 == 0 ? Outcome.Yes : Outcome.No;
        OutcomeToken token = outcome == Outcome.Yes ? market.yesToken() : market.noToken();

        uint256 balance = token.balanceOf(actor);
        if (balance < 1e3) return;
        amount = bound(amount, 1e3, balance);

        (uint256 collateralOut,) = market.quoteSell(outcome, amount);
        if (collateralOut == 0) return;

        vm.prank(actor);
        market.sell(outcome, amount);
    }

    function split(uint256 amount) external {
        uint256 balance = usdc.balanceOf(actor);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);

        vm.prank(actor);
        market.split(amount);
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
