// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, Outcome, TradeSide } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract TradingTest is Test {
    uint256 internal constant INITIAL_LIQUIDITY = 1_000e6;
    uint256 internal constant ACTOR_BALANCE = 1_000_000e6;

    MockUSDC internal usdc;
    MarketFactory internal factory;
    PredictionMarket internal market;

    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");
    address internal alice = makeAddr("alice");
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

        usdc.mint(alice, ACTOR_BALANCE);
        vm.startPrank(alice);
        usdc.approve(address(market), type(uint256).max);
        market.yesToken().approve(address(market), type(uint256).max);
        market.noToken().approve(address(market), type(uint256).max);
        vm.stopPrank();
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

    function _protocolFee(uint256 fee) internal view returns (uint256) {
        return (fee * market.PROTOCOL_FEE_SHARE_BPS()) / 10_000;
    }

    function _assertReservesMatchBalances() internal view {
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(market.yesToken().balanceOf(address(market)), reserveYes);
        assertEq(market.noToken().balanceOf(address(market)), reserveNo);
        assertTrue(market.isFullyBacked());
    }

    function test_BuyRevertsWhenSlippageExceeded() public {
        (uint256 quoted,) = market.quoteBuy(Outcome.Yes, 100e6);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(PredictionMarket.SlippageExceeded.selector, quoted, quoted + 1)
        );
        market.buy(Outcome.Yes, 100e6, quoted + 1, type(uint256).max);
    }

    function test_BuyRevertsAfterDeadline() public {
        uint256 past = block.timestamp - 1;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.DeadlineExpired.selector, past));
        market.buy(Outcome.Yes, 100e6, 0, past);
    }

    function test_SellRevertsWhenSlippageExceeded() public {
        vm.prank(alice);
        market.split(100e6);

        (uint256 quoted,) = market.quoteSell(Outcome.Yes, 100e6);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(PredictionMarket.SlippageExceeded.selector, quoted, quoted + 1)
        );
        market.sell(Outcome.Yes, 100e6, quoted + 1, type(uint256).max);
    }

    function test_SellRevertsAfterDeadline() public {
        vm.prank(alice);
        market.split(100e6);

        uint256 past = block.timestamp - 1;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.DeadlineExpired.selector, past));
        market.sell(Outcome.Yes, 100e6, 0, past);
    }

    function test_ProtocolFeeRoutedOnBuy() public {
        uint256 amount = 100e6;
        (uint256 quoted, uint256 fee) = market.quoteBuy(Outcome.Yes, amount);
        uint256 protocolFee = _protocolFee(fee);

        vm.expectEmit(true, false, false, true);
        emit PredictionMarket.ProtocolFee(treasury, Outcome.Yes, protocolFee);

        vm.prank(alice);
        market.buy(Outcome.Yes, amount, quoted, type(uint256).max);

        assertEq(market.yesToken().balanceOf(treasury), protocolFee);
        assertEq(market.yesToken().balanceOf(alice), quoted);
        _assertReservesMatchBalances();
    }

    function test_ProtocolFeeRoutedOnSell() public {
        vm.prank(alice);
        market.split(100e6);

        (uint256 quoted, uint256 fee) = market.quoteSell(Outcome.Yes, 100e6);
        uint256 protocolFee = _protocolFee(fee);

        vm.expectEmit(true, false, false, true);
        emit PredictionMarket.ProtocolFee(treasury, Outcome.No, protocolFee);

        vm.prank(alice);
        market.sell(Outcome.Yes, 100e6, quoted, type(uint256).max);

        assertEq(market.noToken().balanceOf(treasury), protocolFee);
        _assertReservesMatchBalances();
    }

    function test_BuyEmitsTradeEvent() public {
        uint256 amount = 100e6;
        uint256 priceBefore = market.priceYes();
        (uint256 quoted, uint256 fee) = market.quoteBuy(Outcome.Yes, amount);
        uint256 protocolFee = _protocolFee(fee);
        uint256 feeValue = (fee * priceBefore) / market.PRICE_SCALE();

        uint256 reserveYesAfter = INITIAL_LIQUIDITY - (quoted - amount) - protocolFee;
        uint256 reserveNoAfter = INITIAL_LIQUIDITY + amount;
        uint256 priceAfter =
            (reserveNoAfter * market.PRICE_SCALE()) / (reserveYesAfter + reserveNoAfter);

        vm.expectEmit(true, true, true, true);
        emit PredictionMarket.Trade(
            alice,
            market.marketId(),
            Outcome.Yes,
            TradeSide.Buy,
            quoted,
            amount,
            feeValue,
            priceAfter
        );

        vm.prank(alice);
        market.buy(Outcome.Yes, amount, quoted, type(uint256).max);
    }

    function test_SellEmitsTradeEvent() public {
        vm.prank(alice);
        market.split(100e6);

        uint256 priceBefore = market.priceYes();
        (uint256 quoted, uint256 fee) = market.quoteSell(Outcome.Yes, 100e6);
        uint256 protocolFee = _protocolFee(fee);
        uint256 feeValue = (fee * (market.PRICE_SCALE() - priceBefore)) / market.PRICE_SCALE();

        uint256 reserveYesAfter = INITIAL_LIQUIDITY + (100e6 - quoted);
        uint256 reserveNoAfter = INITIAL_LIQUIDITY - quoted - protocolFee;
        uint256 priceAfter =
            (reserveNoAfter * market.PRICE_SCALE()) / (reserveYesAfter + reserveNoAfter);

        vm.expectEmit(true, true, true, true);
        emit PredictionMarket.Trade(
            alice,
            market.marketId(),
            Outcome.Yes,
            TradeSide.Sell,
            100e6,
            quoted,
            feeValue,
            priceAfter
        );

        vm.prank(alice);
        market.sell(Outcome.Yes, 100e6, quoted, type(uint256).max);
    }
}
