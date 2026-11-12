// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";

contract MarketFactoryTest is Test {
    MockUSDC internal usdc;
    MarketFactory internal factory;
    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");
    uint64 internal deadline;

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(address(this));
        factory = new MarketFactory(address(usdc));
        deadline = uint64(block.timestamp + 30 days);
    }

    function _config() internal view returns (MarketConfig memory config) {
        config = MarketConfig({
            question: "Will ETH close above $4,000 on 2026-12-31?",
            resolutionSource: "https://example.com/eth",
            deadline: deadline,
            resolver: resolver,
            feeBps: 200,
            initialLiquidity: 1_000e6
        });
    }

    function _create(address who) internal returns (uint256 marketId) {
        vm.prank(who);
        marketId = factory.createMarket(_config());
    }

    function test_CreateMarket() public {
        MarketConfig memory config = _config();
        uint256 expectedId = factory.nextMarketId();
        uint256 nonce = vm.getNonce(address(factory));
        address expectedMarket = vm.computeCreateAddress(address(factory), nonce);

        vm.expectEmit(true, true, true, true);
        emit MarketFactory.MarketCreated(
            expectedId, expectedMarket, creator, config.question, config.deadline
        );

        uint256 marketId = _create(creator);

        assertEq(marketId, expectedId);
        assertEq(factory.nextMarketId(), expectedId + 1);
        assertEq(factory.marketById(marketId), expectedMarket);
        assertEq(factory.marketIdByAddress(expectedMarket), marketId);

        PredictionMarket market = PredictionMarket(expectedMarket);
        assertEq(market.marketId(), marketId);
        assertEq(market.factory(), address(factory));
        assertEq(market.creator(), creator);
        assertEq(address(market.collateral()), address(usdc));
        assertEq(market.question(), config.question);
        assertEq(market.resolutionSource(), config.resolutionSource);
        assertEq(market.deadline(), config.deadline);
        assertEq(market.resolver(), config.resolver);
        assertEq(market.feeBps(), config.feeBps);
        assertEq(market.initialLiquidity(), config.initialLiquidity);

        assertEq(factory.marketCount(), 1);
        assertEq(factory.marketAt(0), expectedMarket);
        address[] memory all = factory.getMarkets();
        assertEq(all.length, 1);
        assertEq(all[0], expectedMarket);
    }

    function test_SequentialIdsAndUniqueAddresses() public {
        uint256 first = _create(creator);
        vm.warp(block.timestamp + factory.CREATION_COOLDOWN());
        uint256 second = _create(creator);

        assertEq(first, 1);
        assertEq(second, 2);
        assertTrue(factory.marketById(first) != factory.marketById(second));
        assertEq(factory.marketCount(), 2);
    }

    function test_CooldownReverts() public {
        _create(creator);

        uint256 availableAt = block.timestamp + factory.CREATION_COOLDOWN();
        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(MarketFactory.CreationTooSoon.selector, creator, availableAt)
        );
        factory.createMarket(_config());
    }

    function test_CooldownExpires() public {
        _create(creator);
        vm.warp(block.timestamp + factory.CREATION_COOLDOWN());

        uint256 second = _create(creator);

        assertEq(second, 2);
    }

    function test_RevertWhen_QuestionEmpty() public {
        MarketConfig memory config = _config();
        config.question = "";

        vm.prank(creator);
        vm.expectRevert(MarketFactory.EmptyQuestion.selector);
        factory.createMarket(config);
    }

    function test_RevertWhen_QuestionTooLong() public {
        MarketConfig memory config = _config();
        config.question = string(new bytes(factory.MAX_QUESTION_LENGTH() + 1));

        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketFactory.QuestionTooLong.selector,
                factory.MAX_QUESTION_LENGTH() + 1,
                factory.MAX_QUESTION_LENGTH()
            )
        );
        factory.createMarket(config);
    }

    function test_RevertWhen_DeadlineInPast() public {
        MarketConfig memory config = _config();
        config.deadline = uint64(block.timestamp);

        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(MarketFactory.DeadlineInPast.selector, config.deadline)
        );
        factory.createMarket(config);
    }

    function test_RevertWhen_ResolverIsZero() public {
        MarketConfig memory config = _config();
        config.resolver = address(0);

        vm.prank(creator);
        vm.expectRevert(MarketFactory.InvalidResolver.selector);
        factory.createMarket(config);
    }

    function test_RevertWhen_FeeTooHigh() public {
        MarketConfig memory config = _config();
        config.feeBps = uint16(factory.MAX_FEE_BPS() + 1);

        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketFactory.FeeTooHigh.selector, config.feeBps, factory.MAX_FEE_BPS()
            )
        );
        factory.createMarket(config);
    }

    function test_RevertWhen_LiquidityIsZero() public {
        MarketConfig memory config = _config();
        config.initialLiquidity = 0;

        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketFactory.LiquidityTooLow.selector, 0, factory.MIN_INITIAL_LIQUIDITY()
            )
        );
        factory.createMarket(config);
    }

    function test_RevertWhen_LiquidityBelowMinimum() public {
        MarketConfig memory config = _config();
        config.initialLiquidity = factory.MIN_INITIAL_LIQUIDITY() - 1;

        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketFactory.LiquidityTooLow.selector,
                config.initialLiquidity,
                factory.MIN_INITIAL_LIQUIDITY()
            )
        );
        factory.createMarket(config);
    }

    function test_MaxFeeAllowed() public {
        MarketConfig memory config = _config();
        config.feeBps = uint16(factory.MAX_FEE_BPS());

        vm.prank(creator);
        uint256 marketId = factory.createMarket(config);

        PredictionMarket market = PredictionMarket(factory.marketById(marketId));
        assertEq(market.feeBps(), factory.MAX_FEE_BPS());
    }

    function test_ZeroUsdcReverts() public {
        vm.expectRevert(MarketFactory.ZeroAddress.selector);
        new MarketFactory(address(0));
    }
}
