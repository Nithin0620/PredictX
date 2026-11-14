// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, MarketStatus, Outcome } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { ManualResolver } from "../src/ManualResolver.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract ManualResolverTest is Test {
    uint256 internal constant INITIAL_LIQUIDITY = 1_000e6;

    MockUSDC internal usdc;
    ManualResolver internal manual;
    MarketFactory internal factory;
    PredictionMarket internal market;

    address internal creator = makeAddr("creator");
    address internal otherCreator = makeAddr("otherCreator");
    address internal owner = makeAddr("owner");
    address internal treasury = makeAddr("treasury");
    uint64 internal deadline;

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(address(this));
        manual = new ManualResolver(owner);
        factory = new MarketFactory(address(usdc), treasury);
        deadline = uint64(block.timestamp + 30 days);

        vm.prank(creator);
        uint256 marketId = factory.createMarket(_config(address(manual)));
        market = PredictionMarket(factory.marketById(marketId));

        usdc.mint(creator, INITIAL_LIQUIDITY);
        vm.startPrank(creator);
        usdc.approve(address(market), INITIAL_LIQUIDITY);
        market.seedLiquidity();
        vm.stopPrank();
    }

    function _config(address resolver) internal view returns (MarketConfig memory config) {
        config = MarketConfig({
            question: "Will the incumbent win the 2026 election?",
            resolutionSource: "",
            deadline: deadline,
            resolver: resolver,
            feeBps: uint16(TestConstants.DEFAULT_FEE_BPS),
            initialLiquidity: INITIAL_LIQUIDITY
        });
    }

    function _createMarket(address resolver, bool seed)
        internal
        returns (PredictionMarket created)
    {
        usdc.mint(otherCreator, INITIAL_LIQUIDITY);
        vm.startPrank(otherCreator);
        uint256 marketId = factory.createMarket(_config(resolver));
        created = PredictionMarket(factory.marketById(marketId));
        if (seed) {
            usdc.approve(address(created), INITIAL_LIQUIDITY);
            created.seedLiquidity();
        }
        vm.stopPrank();
    }

    function test_OwnerResolvesYes() public {
        vm.warp(deadline);

        vm.expectEmit(true, false, true, true);
        emit ManualResolver.Resolved(address(market), Outcome.Yes, owner);

        vm.prank(owner);
        manual.resolve(market, Outcome.Yes);

        assertEq(uint8(market.status()), uint8(MarketStatus.Proposed));
        assertEq(uint8(market.proposedOutcome()), uint8(Outcome.Yes));
        assertGt(market.proposedAt(), 0);
    }

    function test_OwnerResolvesNo() public {
        vm.warp(deadline);

        vm.prank(owner);
        manual.resolve(market, Outcome.No);

        assertEq(uint8(market.proposedOutcome()), uint8(Outcome.No));
    }

    function test_OwnerClosesActiveMarketFirst() public {
        vm.warp(deadline);
        assertEq(uint8(market.status()), uint8(MarketStatus.Active));

        vm.prank(owner);
        manual.resolve(market, Outcome.Yes);

        assertGt(market.closedAt(), 0);
        assertEq(uint8(market.status()), uint8(MarketStatus.Proposed));
    }

    function test_ResolveAlreadyClosedMarket() public {
        vm.warp(deadline);
        market.close();

        vm.prank(owner);
        manual.resolve(market, Outcome.Yes);

        assertEq(uint8(market.status()), uint8(MarketStatus.Proposed));
    }

    function test_NonOwnerReverts() public {
        vm.warp(deadline);

        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(ManualResolver.NotOwner.selector, creator));
        manual.resolve(market, Outcome.Yes);
    }

    function test_UnresolvedOutcomeReverts() public {
        vm.warp(deadline);

        vm.prank(owner);
        vm.expectRevert(ManualResolver.InvalidOutcome.selector);
        manual.resolve(market, Outcome.Unresolved);
    }

    function test_BeforeDeadlineReverts() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(PredictionMarket.DeadlineNotReached.selector, deadline)
        );
        manual.resolve(market, Outcome.Yes);
    }

    function test_NonResolverMarketReverts() public {
        PredictionMarket other = _createMarket(address(this), false);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ManualResolver.NotResolver.selector, address(other)));
        manual.resolve(other, Outcome.Yes);
    }

    function test_ResolveCreatedMarketReverts() public {
        PredictionMarket created = _createMarket(address(manual), false);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ManualResolver.MarketNotClosed.selector, MarketStatus.Created)
        );
        manual.resolve(created, Outcome.Yes);
    }

    function test_ResolveTwiceReverts() public {
        vm.warp(deadline);
        vm.prank(owner);
        manual.resolve(market, Outcome.Yes);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ManualResolver.MarketNotClosed.selector, MarketStatus.Proposed)
        );
        manual.resolve(market, Outcome.No);
    }

    function test_ResolveFinalizedMarketReverts() public {
        vm.warp(deadline);
        vm.prank(owner);
        manual.resolve(market, Outcome.Yes);
        vm.warp(block.timestamp + market.DISPUTE_WINDOW() + market.FINALIZATION_DELAY());
        market.finalize();

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ManualResolver.MarketNotClosed.selector, MarketStatus.Finalized)
        );
        manual.resolve(market, Outcome.No);
    }

    function test_ConstructorZeroOwnerReverts() public {
        vm.expectRevert(ManualResolver.ZeroAddress.selector);
        new ManualResolver(address(0));
    }
}
