// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, MarketStatus, Outcome } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract PredictionMarketTest is Test {
    MockUSDC internal usdc;
    MarketFactory internal factory;
    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(address(this));
        factory = new MarketFactory(address(usdc));
    }

    function _config() internal view returns (MarketConfig memory config) {
        config = MarketConfig({
            question: "Will ETH close above $4,000 on 2026-12-31?",
            resolutionSource: "https://example.com/eth",
            deadline: uint64(vm.getBlockTimestamp() + 30 days),
            resolver: resolver,
            feeBps: 200,
            initialLiquidity: 1_000e6
        });
    }

    function _newMarket() internal returns (PredictionMarket market) {
        vm.warp(vm.getBlockTimestamp() + factory.CREATION_COOLDOWN());
        vm.prank(creator);
        uint256 marketId = factory.createMarket(_config());
        market = PredictionMarket(factory.marketById(marketId));
    }

    function _activate(PredictionMarket market) internal {
        uint256 liquidity = market.initialLiquidity();
        usdc.mint(creator, liquidity);
        vm.startPrank(creator);
        usdc.approve(address(market), liquidity);
        market.seedLiquidity();
        vm.stopPrank();
    }

    function _close(PredictionMarket market) internal {
        if (uint256(market.deadline()) > vm.getBlockTimestamp()) vm.warp(market.deadline());
        market.close();
    }

    function _propose(PredictionMarket market) internal {
        vm.prank(resolver);
        market.proposeOutcome(Outcome.Yes);
    }

    function _finalize(PredictionMarket market) internal {
        uint256 availableAt =
            uint256(market.proposedAt()) + market.DISPUTE_WINDOW() + market.FINALIZATION_DELAY();
        if (availableAt > vm.getBlockTimestamp()) vm.warp(availableAt);
        market.finalize();
    }

    function test_InitialState() public {
        PredictionMarket market = _newMarket();

        assertEq(uint256(market.status()), uint256(MarketStatus.Created));
        assertEq(uint256(market.proposedOutcome()), uint256(Outcome.Unresolved));
        assertEq(market.proposedAt(), 0);
        assertEq(market.closedAt(), 0);
        assertEq(uint256(market.DISPUTE_WINDOW()), TestConstants.DEFAULT_DISPUTE_WINDOW);
        assertEq(uint256(market.FINALIZATION_DELAY()), TestConstants.DEFAULT_FINALIZATION_DELAY);
    }

    function test_SeedLiquidity() public {
        PredictionMarket market = _newMarket();
        uint256 liquidity = market.initialLiquidity();

        _activate(market);

        assertEq(uint256(market.status()), uint256(MarketStatus.Active));
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(reserveYes, liquidity);
        assertEq(reserveNo, liquidity);
        assertEq(market.priceYes(), 0.5e18);
        assertEq(usdc.balanceOf(address(market)), liquidity);
        assertEq(market.yesToken().totalSupply(), liquidity);
        assertEq(market.noToken().totalSupply(), liquidity);
        assertTrue(market.isFullyBacked());
    }

    function test_RevertWhen_NonCreatorSeedsLiquidity() public {
        PredictionMarket market = _newMarket();

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.NotCreator.selector, stranger));
        market.seedLiquidity();
    }

    function test_RevertWhen_SeedLiquidityTwice() public {
        PredictionMarket market = _newMarket();
        _activate(market);

        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Active, MarketStatus.Created
            )
        );
        market.seedLiquidity();
    }

    function test_CloseAfterDeadline() public {
        PredictionMarket market = _newMarket();
        _activate(market);

        uint256 closedAt = market.deadline();
        vm.warp(closedAt);

        vm.expectEmit(true, false, false, true);
        emit PredictionMarket.MarketClosed(market.marketId(), closedAt);
        market.close();

        assertEq(uint256(market.status()), uint256(MarketStatus.Closed));
        assertEq(market.closedAt(), closedAt);
    }

    function test_RevertWhen_CloseBeforeDeadline() public {
        PredictionMarket market = _newMarket();
        _activate(market);

        vm.warp(market.deadline() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.DeadlineNotReached.selector, uint256(market.deadline())
            )
        );
        market.close();
    }

    function test_RevertWhen_CloseFromCreated() public {
        PredictionMarket market = _newMarket();

        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Created, MarketStatus.Active
            )
        );
        market.close();
    }

    function test_RevertWhen_CloseTwice() public {
        PredictionMarket market = _newMarket();
        _activate(market);
        _close(market);

        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Closed, MarketStatus.Active
            )
        );
        market.close();
    }

    function test_ProposeOutcome() public {
        PredictionMarket market = _newMarket();
        _activate(market);
        _close(market);

        vm.expectEmit(true, true, false, true);
        emit PredictionMarket.OutcomeProposed(market.marketId(), Outcome.Yes, resolver);
        _propose(market);

        assertEq(uint256(market.status()), uint256(MarketStatus.Proposed));
        assertEq(uint256(market.proposedOutcome()), uint256(Outcome.Yes));
        assertEq(uint256(market.proposedAt()), vm.getBlockTimestamp());
    }

    function test_RevertWhen_NonResolverProposes() public {
        PredictionMarket market = _newMarket();
        _activate(market);
        _close(market);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.NotResolver.selector, stranger));
        market.proposeOutcome(Outcome.Yes);
    }

    function test_RevertWhen_ProposeUnresolved() public {
        PredictionMarket market = _newMarket();
        _activate(market);
        _close(market);

        vm.prank(resolver);
        vm.expectRevert(PredictionMarket.InvalidOutcome.selector);
        market.proposeOutcome(Outcome.Unresolved);
    }

    function test_RevertWhen_ProposeBeforeClose() public {
        PredictionMarket market = _newMarket();
        _activate(market);

        vm.prank(resolver);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Active, MarketStatus.Closed
            )
        );
        market.proposeOutcome(Outcome.Yes);
    }

    function test_FinalizeAfterDisputeWindow() public {
        PredictionMarket market = _newMarket();
        _activate(market);
        _close(market);
        _propose(market);

        uint256 availableAt =
            uint256(market.proposedAt()) + market.DISPUTE_WINDOW() + market.FINALIZATION_DELAY();
        vm.warp(availableAt);

        vm.expectEmit(true, false, false, true);
        emit PredictionMarket.MarketFinalized(market.marketId(), Outcome.Yes);
        market.finalize();

        assertEq(uint256(market.status()), uint256(MarketStatus.Finalized));
    }

    function test_RevertWhen_FinalizeBeforeWindow() public {
        PredictionMarket market = _newMarket();
        _activate(market);
        _close(market);
        _propose(market);

        uint256 availableAt =
            uint256(market.proposedAt()) + market.DISPUTE_WINDOW() + market.FINALIZATION_DELAY();
        vm.warp(availableAt - 1);

        vm.expectRevert(
            abi.encodeWithSelector(PredictionMarket.DisputeWindowActive.selector, availableAt)
        );
        market.finalize();
    }

    function test_RevertWhen_FinalizeFromCreated() public {
        PredictionMarket market = _newMarket();

        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Created, MarketStatus.Proposed
            )
        );
        market.finalize();
    }

    /// @notice Every state × action pair: exactly one action is legal per state (none in Finalized).
    function test_StateActionMatrix() public {
        MarketStatus[5] memory states = [
            MarketStatus.Created,
            MarketStatus.Active,
            MarketStatus.Closed,
            MarketStatus.Proposed,
            MarketStatus.Finalized
        ];

        for (uint256 s; s < states.length; s++) {
            for (uint256 action; action < 4; action++) {
                PredictionMarket market = _newMarket();
                _reach(market, states[s]);

                bool legal = (states[s] == MarketStatus.Created && action == 0)
                    || (states[s] == MarketStatus.Active && action == 1)
                    || (states[s] == MarketStatus.Closed && action == 2)
                    || (states[s] == MarketStatus.Proposed && action == 3);
                if (legal) {
                    _perform(market, action, false);
                    assertEq(uint256(market.status()), uint256(_nextState(action)));
                } else {
                    _perform(market, action, true);
                }
            }
        }
    }

    function _nextState(uint256 action) internal pure returns (MarketStatus) {
        if (action == 0) return MarketStatus.Active;
        if (action == 1) return MarketStatus.Closed;
        if (action == 2) return MarketStatus.Proposed;
        return MarketStatus.Finalized;
    }

    function _reach(PredictionMarket market, MarketStatus target) internal {
        if (target == MarketStatus.Created) return;
        _activate(market);
        if (target == MarketStatus.Active) return;
        _close(market);
        if (target == MarketStatus.Closed) return;
        _propose(market);
        if (target == MarketStatus.Proposed) return;
        _finalize(market);
    }

    function _perform(PredictionMarket market, uint256 action, bool expectFailure) internal {
        if (action == 0) {
            uint256 liquidity = market.initialLiquidity();
            usdc.mint(creator, liquidity);
            vm.startPrank(creator);
            usdc.approve(address(market), liquidity);
            if (expectFailure) vm.expectRevert();
            market.seedLiquidity();
            vm.stopPrank();
        } else if (action == 1) {
            if (uint256(market.deadline()) > vm.getBlockTimestamp()) vm.warp(market.deadline());
            if (expectFailure) vm.expectRevert();
            market.close();
        } else if (action == 2) {
            vm.prank(resolver);
            if (expectFailure) vm.expectRevert();
            market.proposeOutcome(Outcome.Yes);
        } else {
            uint256 availableAt = uint256(market.proposedAt()) + market.DISPUTE_WINDOW()
                + market.FINALIZATION_DELAY();
            if (availableAt > vm.getBlockTimestamp()) vm.warp(availableAt);
            if (expectFailure) vm.expectRevert();
            market.finalize();
        }
    }
}
