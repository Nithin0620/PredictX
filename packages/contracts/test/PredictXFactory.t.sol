// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { PredictXFactory } from "../src/PredictXFactory.sol";
import { PredictXMarket } from "../src/PredictXMarket.sol";

contract PredictXFactoryTest is Test {
    MockUSDC internal usdc;
    PredictXFactory internal factory;

    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");

    uint64 internal deadline;

    function setUp() public {
        usdc = new MockUSDC(address(this));
        factory = new PredictXFactory(address(usdc));
        deadline = uint64(block.timestamp + 1 days);
    }

    function test_CreateMarket() public {
        vm.prank(creator);
        PredictXMarket market =
            factory.createMarket("Will ETH close above $4,000?", deadline, resolver);

        assertEq(factory.marketCount(), 1);
        assertEq(factory.markets(1), address(market));
        assertEq(market.marketId(), 1);
        assertEq(market.creator(), creator);
        assertEq(market.resolver(), resolver);
        assertEq(address(market.collateral()), address(usdc));
        assertEq(market.deadline(), deadline);
        assertEq(market.createdAt(), block.timestamp);
        assertEq(market.question(), "Will ETH close above $4,000?");
        assertEq(uint8(market.outcome()), uint8(0));
    }

    function test_CreateMarketEmitsEvent() public {
        address expectedMarket =
            vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

        vm.expectEmit(true, true, true, true, address(factory));
        emit PredictXFactory.MarketCreated(
            1, expectedMarket, creator, resolver, deadline, "Will ETH close above $4,000?"
        );

        vm.prank(creator);
        factory.createMarket("Will ETH close above $4,000?", deadline, resolver);
    }

    function test_CreateMultipleMarkets() public {
        vm.prank(creator);
        PredictXMarket first = factory.createMarket("First?", deadline, resolver);

        vm.prank(creator);
        PredictXMarket second = factory.createMarket("Second?", deadline + 1, resolver);

        assertEq(factory.marketCount(), 2);
        assertEq(factory.markets(1), address(first));
        assertEq(factory.markets(2), address(second));
        assertEq(second.marketId(), 2);
    }

    function test_GetMarkets() public {
        vm.prank(creator);
        PredictXMarket first = factory.createMarket("First?", deadline, resolver);

        vm.prank(creator);
        PredictXMarket second = factory.createMarket("Second?", deadline, resolver);

        address[] memory list = factory.getMarkets();

        assertEq(list.length, 2);
        assertEq(list[0], address(first));
        assertEq(list[1], address(second));
    }

    function test_RevertWhenCollateralIsZero() public {
        vm.expectRevert(PredictXFactory.ZeroAddress.selector);
        new PredictXFactory(address(0));
    }

    function test_RevertWhenResolverIsZero() public {
        vm.expectRevert(PredictXMarket.ZeroAddress.selector);
        factory.createMarket("Question?", deadline, address(0));
    }

    function test_RevertWhenDeadlineIsPast() public {
        uint64 pastDeadline = uint64(block.timestamp);

        vm.expectRevert(
            abi.encodeWithSelector(PredictXMarket.InvalidDeadline.selector, pastDeadline)
        );
        factory.createMarket("Question?", pastDeadline, resolver);
    }

    function test_RevertWhenQuestionIsEmpty() public {
        vm.expectRevert(PredictXMarket.InvalidQuestion.selector);
        factory.createMarket("", deadline, resolver);
    }
}
