// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, Outcome } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { SettlementHandler } from "./invariant/SettlementHandler.sol";
import { TestConstants } from "./utils/TestConstants.sol";

/**
 * @notice Stateful fuzz test: post-finalization claims and LP settlements must never pay more than
 * the collateral held at finalization, and reserves must stay in sync with market balances.
 */
contract SettlementInvariantTest is Test {
    uint256 internal constant INITIAL_LIQUIDITY = 1_000e6;

    MockUSDC internal usdc;
    MarketFactory internal factory;
    PredictionMarket internal market;
    SettlementHandler internal handler;

    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");
    address internal winner = makeAddr("winner");
    address internal loser = makeAddr("loser");
    address internal treasury = makeAddr("treasury");
    uint64 internal deadline;

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(address(this));
        factory = new MarketFactory(address(usdc), treasury);
        deadline = uint64(vm.getBlockTimestamp() + 30 days);

        vm.prank(creator);
        uint256 marketId = factory.createMarket(_config());
        market = PredictionMarket(factory.marketById(marketId));

        usdc.mint(creator, INITIAL_LIQUIDITY);
        vm.startPrank(creator);
        usdc.approve(address(market), INITIAL_LIQUIDITY);
        market.seedLiquidity();
        vm.stopPrank();

        _fund(winner);
        _fund(loser);

        vm.prank(winner);
        market.buy(Outcome.Yes, 100e6, 0, type(uint256).max);
        vm.prank(loser);
        market.buy(Outcome.No, 50e6, 0, type(uint256).max);

        vm.warp(deadline);
        market.close();
        vm.prank(resolver);
        market.proposeOutcome(Outcome.Yes);
        vm.warp(block.timestamp + market.DISPUTE_WINDOW() + market.FINALIZATION_DELAY());
        market.finalize();

        handler = new SettlementHandler(market, usdc, winner, creator, treasury);
        targetContract(address(handler));
    }

    function _config() internal view returns (MarketConfig memory config) {
        config = MarketConfig({
            question: "Will ETH close above $4,000 on 2026-12-31?",
            resolutionSource: "https://example.com/eth",
            deadline: deadline,
            resolver: resolver,
            feeBps: uint16(TestConstants.DEFAULT_FEE_BPS),
            initialLiquidity: INITIAL_LIQUIDITY
        });
    }

    function _fund(address who) internal {
        usdc.mint(who, 1_000_000e6);
        vm.startPrank(who);
        usdc.approve(address(market), type(uint256).max);
        market.yesToken().approve(address(market), type(uint256).max);
        market.noToken().approve(address(market), type(uint256).max);
        vm.stopPrank();
    }

    function invariant_PayoutsNeverExceedCollateral() public view {
        assertLe(
            handler.totalPayouts(),
            handler.collateralAtFinalization(),
            "payouts exceeded finalization collateral"
        );
    }

    function invariant_WinningClaimsCovered() public view {
        uint256 winningSupply = market.proposedOutcome() == Outcome.Yes
            ? market.yesToken().totalSupply()
            : market.noToken().totalSupply();
        assertGe(usdc.balanceOf(address(market)), winningSupply, "collateral below winning supply");
        assertTrue(market.isFullyBacked(), "market not fully backed");
    }

    function invariant_ReservesMatchBalances() public view {
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(market.yesToken().balanceOf(address(market)), reserveYes, "YES balance mismatch");
        assertEq(market.noToken().balanceOf(address(market)), reserveNo, "NO balance mismatch");
    }

    function invariant_LpSupplyMatchesReserves() public view {
        uint256 supply = market.lpToken().totalSupply();
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        if (supply == 0) {
            assertEq(reserveYes, 0, "empty LP supply with YES reserve");
            assertEq(reserveNo, 0, "empty LP supply with NO reserve");
        } else {
            assertGt(reserveYes, 0, "LP supply without YES reserve");
            assertGt(reserveNo, 0, "LP supply without NO reserve");
        }
    }
}
