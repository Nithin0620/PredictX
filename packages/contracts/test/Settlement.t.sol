// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/IERC6093.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, MarketStatus, Outcome } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { AMM } from "../src/AMM.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract SettlementTest is Test {
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

    function _finalize(Outcome outcome) internal {
        vm.warp(deadline);
        market.close();

        vm.prank(resolver);
        market.proposeOutcome(outcome);

        vm.warp(block.timestamp + market.DISPUTE_WINDOW() + market.FINALIZATION_DELAY());
        market.finalize();
    }

    function test_WinnerRedeemsOneUsdcPerShare() public {
        uint256 shares = _buy(alice, Outcome.Yes, 100e6);
        _finalize(Outcome.Yes);

        uint256 before = usdc.balanceOf(alice);
        vm.expectEmit(true, true, true, true);
        emit PredictionMarket.Redeemed(alice, market.marketId(), Outcome.Yes, shares, shares);

        vm.prank(alice);
        uint256 payout = market.redeem();

        assertEq(payout, shares);
        assertEq(usdc.balanceOf(alice) - before, shares);
        assertEq(market.yesToken().balanceOf(alice), 0);
        assertEq(market.claimed(alice), shares);
        assertTrue(market.isFullyBacked());
    }

    function test_LosingTokenPaysZero() public {
        uint256 noShares = _buy(bob, Outcome.No, 100e6);
        _finalize(Outcome.Yes);

        uint256 before = usdc.balanceOf(bob);
        vm.prank(bob);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.redeem();

        assertEq(usdc.balanceOf(bob), before);
        assertEq(market.noToken().balanceOf(bob), noShares);
        assertEq(market.claimed(bob), 0);
        assertTrue(market.isFullyBacked());
    }

    function test_PartialRedeemAndDoubleClaimReverts() public {
        uint256 shares = _buy(alice, Outcome.Yes, 100e6);
        _finalize(Outcome.Yes);

        uint256 first = shares / 2;
        uint256 second = shares - first;

        vm.prank(alice);
        assertEq(market.redeem(first), first);
        vm.prank(alice);
        assertEq(market.redeem(second), second);

        assertEq(market.claimed(alice), shares);
        assertEq(market.yesToken().balanceOf(alice), 0);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1)
        );
        market.redeem(1);
    }

    function test_RedeemBeforeFinalizeReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Active, MarketStatus.Finalized
            )
        );
        market.redeem();
    }

    function test_RedeemLiquidityBeforeFinalizeReverts() public {
        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Active, MarketStatus.Finalized
            )
        );
        market.redeemLiquidity(1);
    }

    function test_RedeemLiquidityZeroReverts() public {
        _finalize(Outcome.Yes);

        vm.prank(creator);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.redeemLiquidity(0);
    }

    function test_LpSettlementPaysWinningReserveShare() public {
        _buy(alice, Outcome.Yes, 100e6);
        _finalize(Outcome.Yes);

        (uint256 reserveYes,) = market.getReserves();
        uint256 supply = market.lpToken().totalSupply();
        uint256 lpAmount = market.lpToken().balanceOf(creator);
        uint256 expected = (reserveYes * lpAmount) / supply;

        uint256 before = usdc.balanceOf(creator);
        vm.expectEmit(true, true, true, true);
        emit PredictionMarket.LiquiditySettled(creator, lpAmount, expected);

        vm.prank(creator);
        uint256 payout = market.redeemLiquidity(lpAmount);

        assertEq(payout, expected);
        assertEq(usdc.balanceOf(creator) - before, expected);
        assertEq(market.lpToken().balanceOf(creator), 0);
        assertEq(market.lpToken().totalSupply(), 0);
        assertEq(market.yesToken().balanceOf(address(market)), 0);
        assertEq(market.noToken().balanceOf(address(market)), 0);
        assertTrue(market.isFullyBacked());
    }

    function test_LpSettlementUsesNoReserveWhenNoWins() public {
        _buy(alice, Outcome.No, 100e6);
        _finalize(Outcome.No);

        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        uint256 supply = market.lpToken().totalSupply();
        uint256 lpAmount = market.lpToken().balanceOf(creator);
        uint256 expected = (reserveNo * lpAmount) / supply;

        vm.prank(creator);
        uint256 payout = market.redeemLiquidity(lpAmount);

        assertEq(payout, expected);
        assertGt(reserveYes, 0);
        assertEq(payout, reserveNo);
    }

    function test_LpAndTraderBothClaimCorrectly() public {
        uint256 aliceShares = _buy(alice, Outcome.Yes, 100e6);
        _finalize(Outcome.Yes);

        (uint256 reserveYes,) = market.getReserves();
        uint256 lpAmount = market.lpToken().balanceOf(creator);

        vm.prank(alice);
        uint256 alicePayout = market.redeem();
        vm.prank(creator);
        uint256 lpPayout = market.redeemLiquidity(lpAmount);

        uint256 treasuryShares = market.yesToken().balanceOf(treasury);
        vm.prank(treasury);
        uint256 treasuryPayout = market.redeem();

        assertEq(alicePayout, aliceShares);
        assertEq(lpPayout, reserveYes);
        assertEq(treasuryPayout, treasuryShares);
        assertEq(alicePayout + lpPayout + treasuryPayout, INITIAL_LIQUIDITY + 100e6);
        assertEq(usdc.balanceOf(address(market)), 0);
        assertTrue(market.isFullyBacked());
    }

    function test_PartialLpSettlementIsProportional() public {
        _buy(alice, Outcome.Yes, 100e6);
        _finalize(Outcome.Yes);

        uint256 lpAmount = market.lpToken().balanceOf(creator);
        uint256 first = lpAmount / 2;
        uint256 second = lpAmount - first;

        vm.prank(creator);
        uint256 firstPayout = market.redeemLiquidity(first);
        vm.prank(creator);
        uint256 secondPayout = market.redeemLiquidity(second);

        assertGt(firstPayout, 0);
        assertGt(secondPayout, 0);
        assertEq(market.lpToken().totalSupply(), 0);
        assertEq(market.yesToken().balanceOf(address(market)), 0);
        assertEq(market.noToken().balanceOf(address(market)), 0);
        assertTrue(market.isFullyBacked());
    }

    function test_RedeemLiquidityAfterAllSettledReverts() public {
        _finalize(Outcome.Yes);

        uint256 lpAmount = market.lpToken().balanceOf(creator);
        vm.prank(creator);
        market.redeemLiquidity(lpAmount);

        vm.prank(creator);
        vm.expectRevert(AMM.InsufficientLiquidity.selector);
        market.redeemLiquidity(1);
    }

    function test_RedeemLiquidityWithoutLpReverts() public {
        _finalize(Outcome.Yes);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1)
        );
        market.redeemLiquidity(1);
    }
}
