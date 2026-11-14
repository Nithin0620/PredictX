// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, MarketStatus, Outcome } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { OracleResolver } from "../src/OracleResolver.sol";
import { MockAggregatorV3 } from "./utils/MockAggregatorV3.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract OracleResolverTest is Test {
    uint256 internal constant INITIAL_LIQUIDITY = 1_000e6;
    uint256 internal constant MAX_STALENESS = 1 hours;

    MockUSDC internal usdc;
    MockAggregatorV3 internal feed;
    OracleResolver internal oracle;
    MarketFactory internal factory;
    PredictionMarket internal market;

    address internal creator = makeAddr("creator");
    address internal otherCreator = makeAddr("otherCreator");
    address internal treasury = makeAddr("treasury");
    uint64 internal deadline;

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(address(this));
        feed = new MockAggregatorV3(8);
        oracle = new OracleResolver(
            address(feed), OracleResolver.Comparator.GreaterThanOrEqual, 4_000e18, MAX_STALENESS
        );
        factory = new MarketFactory(address(usdc), treasury);
        deadline = uint64(block.timestamp + 30 days);

        vm.prank(creator);
        uint256 marketId = factory.createMarket(_config(address(oracle)));
        market = PredictionMarket(factory.marketById(marketId));

        usdc.mint(creator, INITIAL_LIQUIDITY);
        vm.startPrank(creator);
        usdc.approve(address(market), INITIAL_LIQUIDITY);
        market.seedLiquidity();
        vm.stopPrank();

        _setRound(4_000e8, deadline, 1, 1);
    }

    function _config(address resolver) internal view returns (MarketConfig memory config) {
        config = MarketConfig({
            question: "Will ETH close above $4,000 on 2026-12-31?",
            resolutionSource: "chainlink:ETH/USD",
            deadline: deadline,
            resolver: resolver,
            feeBps: uint16(TestConstants.DEFAULT_FEE_BPS),
            initialLiquidity: INITIAL_LIQUIDITY
        });
    }

    function _setRound(int256 answer, uint256 updatedAt, uint80 roundId, uint80 answeredInRound)
        internal
    {
        feed.setRoundData(roundId, answer, updatedAt, updatedAt, answeredInRound);
    }

    function _warpToDeadline() internal {
        vm.warp(deadline);
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

    function test_GreaterThanOrEqualAtThresholdResolvesYes() public {
        _warpToDeadline();
        oracle.resolve(market);

        assertEq(uint8(market.status()), uint8(MarketStatus.Proposed));
        assertEq(uint8(market.proposedOutcome()), uint8(Outcome.Yes));
    }

    function test_GreaterThanResolvesNoAtThreshold() public {
        OracleResolver gt = new OracleResolver(
            address(feed), OracleResolver.Comparator.GreaterThan, 4_000e18, MAX_STALENESS
        );
        PredictionMarket gtMarket = _createMarket(address(gt), true);

        _warpToDeadline();
        gt.resolve(gtMarket);
        assertEq(uint8(gtMarket.proposedOutcome()), uint8(Outcome.No));
    }

    function test_GreaterThanResolvesYesAboveThreshold() public {
        _warpToDeadline();
        _setRound(4_001e8, block.timestamp, 1, 1);
        oracle.resolve(market);
        assertEq(uint8(market.proposedOutcome()), uint8(Outcome.Yes));
    }

    function test_LessThanResolvesYesBelowThreshold() public {
        OracleResolver lt = new OracleResolver(
            address(feed), OracleResolver.Comparator.LessThan, 4_000e18, MAX_STALENESS
        );
        PredictionMarket ltMarket = _createMarket(address(lt), true);

        _warpToDeadline();
        _setRound(3_999e8, block.timestamp, 1, 1);
        lt.resolve(ltMarket);
        assertEq(uint8(ltMarket.proposedOutcome()), uint8(Outcome.Yes));
    }

    function test_LessThanOrEqualResolvesYesAtThreshold() public {
        OracleResolver lte = new OracleResolver(
            address(feed), OracleResolver.Comparator.LessThanOrEqual, 4_000e18, MAX_STALENESS
        );
        PredictionMarket lteMarket = _createMarket(address(lte), true);

        _warpToDeadline();
        lte.resolve(lteMarket);
        assertEq(uint8(lteMarket.proposedOutcome()), uint8(Outcome.Yes));
    }

    function test_ResolveEmitsEvent() public {
        _warpToDeadline();

        vm.expectEmit(true, true, true, true);
        emit OracleResolver.Resolved(address(market), 4_000e8, Outcome.Yes, block.timestamp);
        oracle.resolve(market);
    }

    function test_ResolveClosesActiveMarketFirst() public {
        _warpToDeadline();
        assertEq(uint8(market.status()), uint8(MarketStatus.Active));

        oracle.resolve(market);

        assertGt(market.closedAt(), 0);
        assertEq(uint8(market.status()), uint8(MarketStatus.Proposed));
    }

    function test_ResolveAlreadyClosedMarket() public {
        _warpToDeadline();
        market.close();

        oracle.resolve(market);

        assertEq(uint8(market.status()), uint8(MarketStatus.Proposed));
    }

    function test_ResolveBeforeDeadlineReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(PredictionMarket.DeadlineNotReached.selector, deadline)
        );
        oracle.resolve(market);
    }

    function test_ResolveCreatedMarketReverts() public {
        PredictionMarket created = _createMarket(address(oracle), false);

        vm.expectRevert(
            abi.encodeWithSelector(OracleResolver.MarketNotClosed.selector, MarketStatus.Created)
        );
        oracle.resolve(created);
    }

    function test_ResolveNonResolverMarketReverts() public {
        PredictionMarket other = _createMarket(address(this), false);

        vm.expectRevert(abi.encodeWithSelector(OracleResolver.NotResolver.selector, address(other)));
        oracle.resolve(other);
    }

    function test_ResolveTwiceReverts() public {
        _warpToDeadline();
        oracle.resolve(market);

        vm.expectRevert(
            abi.encodeWithSelector(OracleResolver.MarketNotClosed.selector, MarketStatus.Proposed)
        );
        oracle.resolve(market);
    }

    function test_ResolveFinalizedMarketReverts() public {
        _warpToDeadline();
        oracle.resolve(market);
        vm.warp(block.timestamp + market.DISPUTE_WINDOW() + market.FINALIZATION_DELAY());
        market.finalize();

        vm.expectRevert(
            abi.encodeWithSelector(OracleResolver.MarketNotClosed.selector, MarketStatus.Finalized)
        );
        oracle.resolve(market);
    }

    function test_StalePriceReverts() public {
        _warpToDeadline();
        uint256 staleAt = block.timestamp - MAX_STALENESS - 1;
        _setRound(4_000e8, staleAt, 1, 1);

        vm.expectRevert(
            abi.encodeWithSelector(OracleResolver.StalePrice.selector, staleAt, MAX_STALENESS)
        );
        oracle.resolve(market);
    }

    function test_ZeroUpdatedAtReverts() public {
        _setRound(4_000e8, 0, 1, 1);
        _warpToDeadline();

        vm.expectRevert(
            abi.encodeWithSelector(OracleResolver.StalePrice.selector, 0, MAX_STALENESS)
        );
        oracle.resolve(market);
    }

    function test_FutureTimestampReverts() public {
        _warpToDeadline();
        _setRound(4_000e8, block.timestamp + 1, 1, 1);

        vm.expectRevert(
            abi.encodeWithSelector(OracleResolver.InvalidTimestamp.selector, block.timestamp + 1)
        );
        oracle.resolve(market);
    }

    function test_IncompleteRoundReverts() public {
        _warpToDeadline();
        _setRound(4_000e8, block.timestamp, 2, 1);

        vm.expectRevert(abi.encodeWithSelector(OracleResolver.IncompleteRound.selector, 2, 1));
        oracle.resolve(market);
    }

    function test_ZeroPriceReverts() public {
        _warpToDeadline();
        _setRound(0, block.timestamp, 1, 1);

        vm.expectRevert(abi.encodeWithSelector(OracleResolver.InvalidPrice.selector, 0));
        oracle.resolve(market);
    }

    function test_NegativePriceReverts() public {
        _warpToDeadline();
        _setRound(-1, block.timestamp, 1, 1);

        vm.expectRevert(abi.encodeWithSelector(OracleResolver.InvalidPrice.selector, -1));
        oracle.resolve(market);
    }

    function test_DecimalNormalizationSixDecimals() public {
        MockAggregatorV3 sixFeed = new MockAggregatorV3(6);
        OracleResolver sixOracle = new OracleResolver(
            address(sixFeed), OracleResolver.Comparator.GreaterThanOrEqual, 4_000e18, MAX_STALENESS
        );
        PredictionMarket sixMarket = _createMarket(address(sixOracle), true);

        _warpToDeadline();
        sixFeed.setRoundData(1, 4_000e6, block.timestamp, block.timestamp, 1);
        sixOracle.resolve(sixMarket);
        assertEq(uint8(sixMarket.proposedOutcome()), uint8(Outcome.Yes));
    }

    function test_DecimalNormalizationTwentyDecimals() public {
        MockAggregatorV3 twentyFeed = new MockAggregatorV3(20);
        OracleResolver twentyOracle = new OracleResolver(
            address(twentyFeed),
            OracleResolver.Comparator.GreaterThanOrEqual,
            4_000e18,
            MAX_STALENESS
        );
        PredictionMarket twentyMarket = _createMarket(address(twentyOracle), true);

        _warpToDeadline();
        twentyFeed.setRoundData(1, 4_000e20, block.timestamp, block.timestamp, 1);
        twentyOracle.resolve(twentyMarket);
        assertEq(uint8(twentyMarket.proposedOutcome()), uint8(Outcome.Yes));
    }

    function test_InvalidDecimalsReverts() public {
        MockAggregatorV3 weirdFeed = new MockAggregatorV3(37);
        OracleResolver weirdOracle = new OracleResolver(
            address(weirdFeed), OracleResolver.Comparator.GreaterThan, 0, MAX_STALENESS
        );
        PredictionMarket weirdMarket = _createMarket(address(weirdOracle), true);

        _warpToDeadline();
        weirdFeed.setRoundData(1, 1, block.timestamp, block.timestamp, 1);
        vm.expectRevert(abi.encodeWithSelector(OracleResolver.InvalidDecimals.selector, 37));
        weirdOracle.resolve(weirdMarket);
    }

    function test_LatestAnswerReturnsWad() public {
        _setRound(4_123e8, block.timestamp, 1, 1);
        (int256 answer, uint256 updatedAt) = oracle.latestAnswer();

        assertEq(answer, 4_123e18);
        assertEq(updatedAt, block.timestamp);
    }

    function test_ConstructorZeroFeedReverts() public {
        vm.expectRevert(OracleResolver.ZeroAddress.selector);
        new OracleResolver(address(0), OracleResolver.Comparator.GreaterThan, 0, MAX_STALENESS);
    }

    function test_ConstructorZeroStalenessReverts() public {
        vm.expectRevert(OracleResolver.InvalidStaleness.selector);
        new OracleResolver(address(feed), OracleResolver.Comparator.GreaterThan, 0, 0);
    }
}
