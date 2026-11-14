// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../../src/MockUSDC.sol";
import { PredictionMarket } from "../../src/PredictionMarket.sol";

/// @notice Random winning redemptions and LP settlements after finalization.
contract SettlementHandler is Test {
    PredictionMarket public immutable market;
    MockUSDC public immutable usdc;

    address public immutable winner;
    address public immutable lpProvider;
    address public immutable treasury;

    uint256 public immutable collateralAtFinalization;
    uint256 public totalPayouts;

    constructor(
        PredictionMarket market_,
        MockUSDC usdc_,
        address winner_,
        address lpProvider_,
        address treasury_
    ) {
        market = market_;
        usdc = usdc_;
        winner = winner_;
        lpProvider = lpProvider_;
        treasury = treasury_;
        collateralAtFinalization = usdc_.balanceOf(address(market_));
    }

    function redeemWinner(uint256 amount) external {
        uint256 balance = market.yesToken().balanceOf(winner);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);

        vm.prank(winner);
        totalPayouts += market.redeem(amount);
    }

    function redeemWinnerAll() external {
        uint256 balance = market.yesToken().balanceOf(winner);
        if (balance == 0) return;

        vm.prank(winner);
        totalPayouts += market.redeem();
    }

    function redeemTreasury(uint256 amount) external {
        uint256 balance = market.yesToken().balanceOf(treasury);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);

        vm.prank(treasury);
        totalPayouts += market.redeem(amount);
    }

    function settleLiquidity(uint256 amount) external {
        uint256 balance = market.lpToken().balanceOf(lpProvider);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);

        vm.prank(lpProvider);
        totalPayouts += market.redeemLiquidity(amount);
    }
}
