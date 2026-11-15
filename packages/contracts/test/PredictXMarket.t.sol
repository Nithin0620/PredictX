// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { PredictXFactory } from "../src/PredictXFactory.sol";
import { PredictXMarket } from "../src/PredictXMarket.sol";
import { Outcome } from "../src/PredictXTypes.sol";

contract PredictXMarketTest is Test {
    MockUSDC internal usdc;
    PredictXFactory internal factory;
    PredictXMarket internal market;

    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");

    uint64 internal deadline;

    function setUp() public {
        usdc = new MockUSDC(address(this));
        factory = new PredictXFactory(address(usdc));
        deadline = uint64(block.timestamp + 1 days);

        vm.prank(creator);
        market = factory.createMarket("Will ETH close above $4,000?", deadline, resolver);

        _fund(alice);
        _fund(bob);
        _fund(carol);
        _fund(dave);
    }

    function test_BetYesUpdatesPools() public {
        _bet(alice, Outcome.Yes, 100e6);

        assertEq(market.yesStake(alice), 100e6);
        assertEq(market.noStake(alice), 0);
        assertEq(market.totalYes(), 100e6);
        assertEq(market.totalNo(), 0);
        assertEq(usdc.balanceOf(address(market)), 100e6);
    }

    function test_BetNoUpdatesPools() public {
        _bet(alice, Outcome.No, 250e6);

        assertEq(market.yesStake(alice), 0);
        assertEq(market.noStake(alice), 250e6);
        assertEq(market.totalYes(), 0);
        assertEq(market.totalNo(), 250e6);
        assertEq(usdc.balanceOf(address(market)), 250e6);
    }

    function test_BetAccumulates() public {
        _bet(alice, Outcome.Yes, 100e6);
        _bet(alice, Outcome.Yes, 50e6);

        assertEq(market.yesStake(alice), 150e6);
        assertEq(market.totalYes(), 150e6);
    }

    function test_BetEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(market));
        emit PredictXMarket.Bet(alice, Outcome.Yes, 100e6);

        _bet(alice, Outcome.Yes, 100e6);
    }

    function test_ResolveAtDeadline() public {
        vm.warp(deadline);

        _resolve(Outcome.Yes);

        assertEq(uint8(market.outcome()), uint8(Outcome.Yes));
    }

    function test_ResolveEmitsEvent() public {
        vm.warp(deadline);

        vm.expectEmit(true, true, false, true, address(market));
        emit PredictXMarket.Resolved(Outcome.No, resolver);

        _resolve(Outcome.No);
    }

    function test_ClaimYesWinnerProRata() public {
        _bet(alice, Outcome.Yes, 100e6);
        _bet(bob, Outcome.Yes, 300e6);
        _bet(carol, Outcome.No, 400e6);

        vm.warp(deadline);
        _resolve(Outcome.Yes);

        assertEq(_claim(alice), 200e6);
        assertEq(_claim(bob), 600e6);
        assertEq(usdc.balanceOf(address(market)), 0);
    }

    function test_ClaimNoWinnerProRata() public {
        _bet(alice, Outcome.No, 100e6);
        _bet(bob, Outcome.No, 300e6);
        _bet(carol, Outcome.Yes, 400e6);

        vm.warp(deadline);
        _resolve(Outcome.No);

        assertEq(_claim(alice), 200e6);
        assertEq(_claim(bob), 600e6);
        assertEq(usdc.balanceOf(address(market)), 0);
    }

    function test_RoundingDustStaysInContract() public {
        _bet(alice, Outcome.Yes, 1);
        _bet(bob, Outcome.Yes, 1);
        _bet(carol, Outcome.Yes, 1);
        _bet(dave, Outcome.No, 2);

        vm.warp(deadline);
        _resolve(Outcome.Yes);

        assertEq(_claim(alice), 1);
        assertEq(_claim(bob), 1);
        assertEq(_claim(carol), 1);
        assertEq(usdc.balanceOf(address(market)), 2);
    }

    function test_ClaimEmitsEvent() public {
        _bet(alice, Outcome.Yes, 100e6);
        _bet(bob, Outcome.Yes, 100e6);

        vm.warp(deadline);
        _resolve(Outcome.Yes);

        vm.expectEmit(true, false, false, true, address(market));
        emit PredictXMarket.Claimed(alice, 100e6);

        _claim(alice);
    }

    function testFuzz_ClaimNeverExceedsPool(uint96 yesAmount, uint96 noAmount) public {
        uint256 yes = bound(uint256(yesAmount), 1, 1_000_000e6);
        uint256 no = bound(uint256(noAmount), 1, 1_000_000e6);

        _bet(alice, Outcome.Yes, yes);
        _bet(bob, Outcome.No, no);

        vm.warp(deadline);
        _resolve(Outcome.Yes);

        uint256 payout = _claim(alice);

        assertLe(payout, yes + no);
        assertEq(usdc.balanceOf(address(market)), yes + no - payout);
    }

    function test_RevertWhenBetZero() public {
        vm.expectRevert(PredictXMarket.ZeroAmount.selector);
        _bet(alice, Outcome.Yes, 0);
    }

    function test_RevertWhenBetUnresolved() public {
        vm.expectRevert(PredictXMarket.InvalidOutcome.selector);
        _bet(alice, Outcome.Unresolved, 1);
    }

    function test_RevertWhenBetAtDeadline() public {
        vm.warp(deadline);

        vm.expectRevert(abi.encodeWithSelector(PredictXMarket.MarketClosed.selector, deadline));
        _bet(alice, Outcome.Yes, 1);
    }

    function test_RevertWhenBetAfterResolution() public {
        vm.warp(deadline);
        _resolve(Outcome.Yes);

        vm.expectRevert(abi.encodeWithSelector(PredictXMarket.MarketResolved.selector, Outcome.Yes));
        _bet(alice, Outcome.Yes, 1);
    }

    function test_RevertWhenCallerIsNotResolver() public {
        vm.warp(deadline);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PredictXMarket.NotResolver.selector, alice));
        market.resolve(Outcome.Yes);
    }

    function test_RevertWhenResolveBeforeDeadline() public {
        vm.expectRevert(
            abi.encodeWithSelector(PredictXMarket.DeadlineNotReached.selector, deadline)
        );
        _resolve(Outcome.Yes);
    }

    function test_RevertWhenResolveUnresolved() public {
        vm.warp(deadline);

        vm.expectRevert(PredictXMarket.InvalidOutcome.selector);
        _resolve(Outcome.Unresolved);
    }

    function test_RevertWhenResolveTwice() public {
        vm.warp(deadline);
        _resolve(Outcome.Yes);

        vm.prank(resolver);
        vm.expectRevert(
            abi.encodeWithSelector(PredictXMarket.AlreadyResolved.selector, Outcome.Yes)
        );
        market.resolve(Outcome.No);
    }

    function test_RevertWhenClaimBeforeResolution() public {
        vm.expectRevert(PredictXMarket.NotResolved.selector);
        _claim(alice);
    }

    function test_RevertWhenLoserClaims() public {
        _bet(carol, Outcome.No, 100e6);

        vm.warp(deadline);
        _resolve(Outcome.Yes);

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(PredictXMarket.NothingToClaim.selector, carol));
        market.claim();
    }

    function test_RevertWhenNoPositionClaims() public {
        _bet(alice, Outcome.Yes, 100e6);

        vm.warp(deadline);
        _resolve(Outcome.Yes);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PredictXMarket.NothingToClaim.selector, bob));
        market.claim();
    }

    function test_RevertWhenDoubleClaim() public {
        _bet(alice, Outcome.Yes, 100e6);

        vm.warp(deadline);
        _resolve(Outcome.Yes);
        _claim(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PredictXMarket.AlreadyClaimed.selector, alice));
        market.claim();
    }

    function _fund(address user) internal {
        usdc.mint(user, 1_000_000e6);
        vm.prank(user);
        usdc.approve(address(market), type(uint256).max);
    }

    function _bet(address user, Outcome side, uint256 amount) internal {
        vm.prank(user);
        market.bet(side, amount);
    }

    function _resolve(Outcome result) internal {
        vm.prank(resolver);
        market.resolve(result);
    }

    function _claim(address user) internal returns (uint256 payout) {
        vm.prank(user);
        payout = market.claim();
    }
}
