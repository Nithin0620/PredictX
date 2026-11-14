// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, MarketStatus, Outcome } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract LiquidityTest is Test {
    uint256 internal constant INITIAL_LIQUIDITY = 1_000e6;
    uint256 internal constant ACTOR_BALANCE = 1_000_000e6;

    MockUSDC internal usdc;
    MarketFactory internal factory;
    PredictionMarket internal market;

    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal treasury = makeAddr("treasury");
    uint64 internal deadline;

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(address(this));
        factory = new MarketFactory(address(usdc), treasury);
        deadline = uint64(block.timestamp + 30 days);

        vm.prank(creator);
        uint256 marketId = factory.createMarket(_config());
        market = PredictionMarket(factory.marketById(marketId));

        usdc.mint(creator, INITIAL_LIQUIDITY);
        vm.startPrank(creator);
        usdc.approve(address(market), INITIAL_LIQUIDITY);
        market.seedLiquidity();
        vm.stopPrank();

        _fund(alice);
        _fund(bob);
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
        usdc.mint(who, ACTOR_BALANCE);
        vm.startPrank(who);
        usdc.approve(address(market), type(uint256).max);
        market.yesToken().approve(address(market), type(uint256).max);
        market.noToken().approve(address(market), type(uint256).max);
        vm.stopPrank();
    }

    function _buy(address who, Outcome outcome, uint256 amount) internal returns (uint256) {
        vm.prank(who);
        return market.buy(outcome, amount, 0, type(uint256).max);
    }

    function _sell(address who, Outcome outcome, uint256 amount) internal returns (uint256) {
        vm.prank(who);
        return market.sell(outcome, amount, 0, type(uint256).max);
    }

    function test_SeedMintsLpShares() public view {
        assertEq(market.lpToken().balanceOf(creator), INITIAL_LIQUIDITY);
        assertEq(market.lpToken().totalSupply(), INITIAL_LIQUIDITY);
        assertEq(market.lpToken().decimals(), 6);
        assertEq(market.lpToken().TOKEN_KIND(), "LP");
    }

    function test_AddLiquidityMintsProportionalShares() public {
        vm.prank(bob);
        uint256 lpAmount = market.addLiquidity(500e6);

        assertEq(lpAmount, 500e6);
        assertEq(market.lpToken().balanceOf(bob), 500e6);
        assertEq(market.lpToken().totalSupply(), 1_500e6);

        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(reserveYes, 1_500e6);
        assertEq(reserveNo, 1_500e6);
        assertEq(market.yesToken().balanceOf(address(market)), reserveYes);
        assertEq(market.noToken().balanceOf(address(market)), reserveNo);
        assertTrue(market.isFullyBacked());
    }

    function test_TwoLpsAddAndRemoveProportionally() public {
        vm.prank(alice);
        market.addLiquidity(500e6);
        vm.prank(bob);
        market.addLiquidity(1_000e6);

        assertEq(market.lpToken().balanceOf(alice), 500e6);
        assertEq(market.lpToken().balanceOf(bob), 1_000e6);
        assertEq(market.lpToken().totalSupply(), 2_500e6);

        vm.prank(alice);
        (uint256 aliceYes, uint256 aliceNo) = market.removeLiquidity(500e6);
        vm.prank(bob);
        (uint256 bobYes, uint256 bobNo) = market.removeLiquidity(1_000e6);

        assertGt(aliceYes, 0);
        assertEq(aliceYes, aliceNo);
        assertGt(bobYes, 0);
        assertEq(bobYes, bobNo);
        assertEq(market.lpToken().totalSupply(), 1_000e6);
        assertEq(market.lpToken().balanceOf(creator), 1_000e6);
    }

    function test_RemoveLiquidityReturnsProportionalReserves() public {
        vm.prank(bob);
        market.addLiquidity(1_000e6);

        (uint256 reserveYesBefore, uint256 reserveNoBefore) = market.getReserves();
        uint256 supply = market.lpToken().totalSupply();

        vm.prank(bob);
        (uint256 yesOut, uint256 noOut) = market.removeLiquidity(500e6);

        assertEq(yesOut, (reserveYesBefore * 500e6) / supply);
        assertEq(noOut, (reserveNoBefore * 500e6) / supply);
        assertEq(market.lpToken().balanceOf(bob), 500e6);

        (uint256 reserveYesAfter, uint256 reserveNoAfter) = market.getReserves();
        assertEq(reserveYesAfter, reserveYesBefore - yesOut);
        assertEq(reserveNoAfter, reserveNoBefore - noOut);
    }

    function test_LpFeesAccrueViaReserveGrowth() public {
        vm.prank(bob);
        market.addLiquidity(1_000e6);

        uint256 kBefore = _k();
        uint256 shares = _buy(alice, Outcome.Yes, 100e6);
        _sell(alice, Outcome.Yes, shares);

        assertGt(_k(), kBefore);

        uint256 usdcBefore = usdc.balanceOf(bob);
        uint256 lpAmount = market.lpToken().balanceOf(bob);
        vm.prank(bob);
        (uint256 yesOut, uint256 noOut) = market.removeLiquidity(lpAmount);
        uint256 mergeAmount = yesOut < noOut ? yesOut : noOut;

        vm.prank(bob);
        market.merge(mergeAmount);

        assertGt(usdc.balanceOf(bob), usdcBefore);
        assertGt(usdc.balanceOf(bob) - usdcBefore, 1_000e6);
    }

    function test_RemoveAllThenReAdd() public {
        vm.prank(bob);
        market.addLiquidity(500e6);
        uint256 lpAmount = market.lpToken().balanceOf(bob);
        vm.prank(bob);
        market.removeLiquidity(lpAmount);

        vm.prank(alice);
        market.addLiquidity(250e6);

        assertEq(market.lpToken().totalSupply(), 1_000e6 + 250e6);
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(reserveYes, 1_250e6);
        assertEq(reserveNo, 1_250e6);
    }

    function test_RemoveAllLiquidityLeavesOutstandingPositionsBacked() public {
        _buy(alice, Outcome.Yes, 100e6);
        uint256 aliceYes = market.yesToken().balanceOf(alice);
        uint256 lpAmount = market.lpToken().balanceOf(creator);

        vm.prank(creator);
        (uint256 yesOut, uint256 noOut) = market.removeLiquidity(lpAmount);
        vm.prank(creator);
        market.merge(yesOut < noOut ? yesOut : noOut);

        assertEq(market.lpToken().totalSupply(), 0);
        assertEq(market.yesToken().balanceOf(alice), aliceYes);
        assertTrue(market.isFullyBacked());

        vm.warp(deadline);
        market.close();
        vm.prank(resolver);
        market.proposeOutcome(Outcome.Yes);
        vm.warp(block.timestamp + market.DISPUTE_WINDOW() + market.FINALIZATION_DELAY());
        market.finalize();

        assertEq(uint256(market.status()), uint256(MarketStatus.Finalized));
        assertTrue(market.isFullyBacked());
    }

    function test_AddLiquidityBeforeSeedReverts() public {
        vm.warp(block.timestamp + factory.CREATION_COOLDOWN());
        vm.prank(creator);
        uint256 marketId = factory.createMarket(_config());
        PredictionMarket fresh = PredictionMarket(factory.marketById(marketId));

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Created, MarketStatus.Active
            )
        );
        fresh.addLiquidity(100e6);
    }

    function test_AddLiquidityAfterCloseReverts() public {
        vm.warp(market.deadline());
        market.close();

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Closed, MarketStatus.Active
            )
        );
        market.addLiquidity(100e6);
    }

    function test_AddLiquidityZeroReverts() public {
        vm.prank(bob);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.addLiquidity(0);
    }

    function test_RemoveLiquidityZeroReverts() public {
        vm.prank(bob);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.removeLiquidity(0);
    }

    function _k() internal view returns (uint256) {
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        return reserveYes * reserveNo;
    }
}
