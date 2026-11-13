// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, MarketStatus, Outcome } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { AMM } from "../src/AMM.sol";
import { AMMHarness } from "./utils/AMMHarness.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract AMMTest is Test {
    uint256 internal constant INITIAL_LIQUIDITY = 1_000e6;
    uint256 internal constant ACTOR_BALANCE = 1_000_000e6;

    MockUSDC internal usdc;
    MarketFactory internal factory;
    PredictionMarket internal market;
    AMMHarness internal harness;

    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");
    address internal alice = makeAddr("alice");
    uint64 internal deadline;

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(address(this));
        factory = new MarketFactory(address(usdc));
        harness = new AMMHarness();
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

    function _k() internal view returns (uint256) {
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        return reserveYes * reserveNo;
    }

    function _assertReservesMatchBalances() internal view {
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(market.yesToken().balanceOf(address(market)), reserveYes);
        assertEq(market.noToken().balanceOf(address(market)), reserveNo);
        assertTrue(market.isFullyBacked());
    }

    function test_SeedLiquiditySetsPool() public view {
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(reserveYes, INITIAL_LIQUIDITY);
        assertEq(reserveNo, INITIAL_LIQUIDITY);
        assertEq(market.priceYes(), 0.5e18);
        assertEq(usdc.balanceOf(address(market)), INITIAL_LIQUIDITY);
        assertEq(market.yesToken().totalSupply(), INITIAL_LIQUIDITY);
        assertEq(market.noToken().totalSupply(), INITIAL_LIQUIDITY);
    }

    function test_GetAmountOutMatchesFormula() public view {
        uint256 amountIn = 100e6;
        uint256 expectedGross = (amountIn * INITIAL_LIQUIDITY) / (INITIAL_LIQUIDITY + amountIn);
        uint256 expectedFee =
            (amountIn
                    * INITIAL_LIQUIDITY
                    * market.feeBps()
                    + (INITIAL_LIQUIDITY + amountIn)
                    * 10_000
                    - 1) / ((INITIAL_LIQUIDITY + amountIn) * 10_000);

        assertEq(
            market.getAmountOut(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, amountIn),
            expectedGross - expectedFee
        );
    }

    function test_BuyYesRaisesPrice() public {
        uint256 amountIn = 100e6;
        uint256 priceBefore = market.priceYes();
        (uint256 quotedShares, uint256 quotedFee) = market.quoteBuy(Outcome.Yes, amountIn);
        uint256 kBefore = _k();

        vm.prank(alice);
        uint256 sharesOut = market.buy(Outcome.Yes, amountIn);

        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(sharesOut, quotedShares);
        assertEq(market.yesToken().balanceOf(alice), quotedShares);
        assertEq(reserveNo, INITIAL_LIQUIDITY + amountIn);
        assertEq(reserveYes, INITIAL_LIQUIDITY - (quotedShares - amountIn));
        assertGt(quotedFee, 0);
        assertGt(market.priceYes(), priceBefore);
        assertGe(_k(), kBefore);
        _assertReservesMatchBalances();
    }

    function test_BuyNoLowersYesPrice() public {
        uint256 amountIn = 100e6;
        uint256 priceBefore = market.priceYes();
        (uint256 quotedShares,) = market.quoteBuy(Outcome.No, amountIn);

        vm.prank(alice);
        uint256 sharesOut = market.buy(Outcome.No, amountIn);

        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(sharesOut, quotedShares);
        assertEq(market.noToken().balanceOf(alice), quotedShares);
        assertEq(reserveYes, INITIAL_LIQUIDITY + amountIn);
        assertEq(reserveNo, INITIAL_LIQUIDITY - (quotedShares - amountIn));
        assertLt(market.priceYes(), priceBefore);
        _assertReservesMatchBalances();
    }

    function test_QuoteBuyMatchesExecution() public {
        uint256 amountIn = 250e6;
        (uint256 quotedShares, uint256 quotedFee) = market.quoteBuy(Outcome.Yes, amountIn);
        uint256 kBefore = _k();

        vm.prank(alice);
        uint256 sharesOut = market.buy(Outcome.Yes, amountIn);

        assertEq(sharesOut, quotedShares);
        assertGt(quotedFee, 0);
        assertGt(_k(), kBefore);
    }

    function test_SellYesLowersPrice() public {
        vm.prank(alice);
        market.split(100e6);

        uint256 priceBefore = market.priceYes();
        (uint256 quotedCollateral, uint256 quotedFee) = market.quoteSell(Outcome.Yes, 100e6);
        uint256 kBefore = _k();

        vm.prank(alice);
        uint256 collateralOut = market.sell(Outcome.Yes, 100e6);

        assertEq(collateralOut, quotedCollateral);
        assertGt(quotedCollateral, 0);
        assertGt(quotedFee, 0);
        assertLt(market.priceYes(), priceBefore);
        assertGe(_k(), kBefore);
        assertEq(market.yesToken().balanceOf(alice), 0);
        assertEq(market.noToken().balanceOf(alice), 100e6);
        _assertReservesMatchBalances();
    }

    function test_QuoteSellMatchesExecution() public {
        vm.prank(alice);
        market.split(500e6);

        (uint256 quotedCollateral, uint256 quotedFee) = market.quoteSell(Outcome.Yes, 500e6);
        uint256 usdcBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        uint256 collateralOut = market.sell(Outcome.Yes, 500e6);

        assertEq(collateralOut, quotedCollateral);
        assertEq(usdc.balanceOf(alice), usdcBefore + quotedCollateral);
        assertGt(quotedFee, 0);
        _assertReservesMatchBalances();
    }

    function test_BuySellRoundTripPaysFees() public {
        uint256 amountIn = 100e6;
        uint256 usdcBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        uint256 sharesOut = market.buy(Outcome.Yes, amountIn);

        (uint256 quotedCollateral,) = market.quoteSell(Outcome.Yes, sharesOut);
        vm.prank(alice);
        uint256 collateralOut = market.sell(Outcome.Yes, sharesOut);

        assertEq(collateralOut, quotedCollateral);
        assertLt(collateralOut, amountIn);
        assertEq(usdc.balanceOf(alice), usdcBefore - amountIn + collateralOut);
        assertEq(market.yesToken().balanceOf(alice), 0);
        assertGt(_k(), INITIAL_LIQUIDITY * INITIAL_LIQUIDITY);
        _assertReservesMatchBalances();
    }

    function test_NoFreeMoneyOnRepeatedTrades() public {
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 kBefore = _k();

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(alice);
            uint256 sharesOut = market.buy(Outcome.Yes, 50e6);
            vm.prank(alice);
            market.sell(Outcome.Yes, sharesOut);
        }

        assertLe(usdc.balanceOf(alice), usdcBefore);
        assertGe(_k(), kBefore);
        _assertReservesMatchBalances();
    }

    function test_BothSidesKeepReservesBacked() public {
        vm.prank(alice);
        market.buy(Outcome.Yes, 100e6);
        vm.prank(alice);
        market.buy(Outcome.No, 200e6);

        _assertReservesMatchBalances();
        assertGt(market.yesToken().balanceOf(alice), 0);
        assertGt(market.noToken().balanceOf(alice), 0);
    }

    function test_RevertWhen_BuyZero() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.buy(Outcome.Yes, 0);
    }

    function test_RevertWhen_SellZero() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.sell(Outcome.Yes, 0);
    }

    function test_RevertWhen_BuyUnresolved() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.InvalidOutcome.selector);
        market.buy(Outcome.Unresolved, 100e6);
    }

    function test_RevertWhen_SellUnresolved() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.InvalidOutcome.selector);
        market.sell(Outcome.Unresolved, 100e6);
    }

    function test_RevertWhen_QuoteBuyZero() public {
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.quoteBuy(Outcome.Yes, 0);
    }

    function test_RevertWhen_QuoteSellZero() public {
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.quoteSell(Outcome.Yes, 0);
    }

    function test_RevertWhen_QuoteBuyUnresolved() public {
        vm.expectRevert(PredictionMarket.InvalidOutcome.selector);
        market.quoteBuy(Outcome.Unresolved, 100e6);
    }

    function test_RevertWhen_QuoteSellUnresolved() public {
        vm.expectRevert(PredictionMarket.InvalidOutcome.selector);
        market.quoteSell(Outcome.Unresolved, 100e6);
    }

    function test_RevertWhen_BuyBeforeSeed() public {
        PredictionMarket fresh = _freshMarket();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Created, MarketStatus.Active
            )
        );
        fresh.buy(Outcome.Yes, 100e6);
    }

    function test_RevertWhen_BuyAfterClose() public {
        vm.warp(market.deadline());
        market.close();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Closed, MarketStatus.Active
            )
        );
        market.buy(Outcome.Yes, 100e6);
    }

    function test_RevertWhen_SellAfterClose() public {
        vm.prank(alice);
        market.split(100e6);
        vm.warp(market.deadline());
        market.close();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Closed, MarketStatus.Active
            )
        );
        market.sell(Outcome.Yes, 100e6);
    }

    function test_RevertWhen_BuyWithoutApproval() public {
        address stranger = makeAddr("stranger");
        usdc.mint(stranger, 100e6);

        vm.prank(stranger);
        vm.expectRevert();
        market.buy(Outcome.Yes, 100e6);
    }

    function test_RevertWhen_SellWithoutApproval() public {
        address stranger = makeAddr("stranger");
        usdc.mint(stranger, 100e6);
        vm.startPrank(stranger);
        usdc.approve(address(market), type(uint256).max);
        market.split(100e6);
        vm.stopPrank();

        vm.prank(stranger);
        vm.expectRevert();
        market.sell(Outcome.Yes, 100e6);
    }

    function test_RevertWhen_PriceYesEmpty() public {
        PredictionMarket fresh = _freshMarket();
        vm.expectRevert(AMM.InsufficientLiquidity.selector);
        fresh.priceYes();
    }

    function test_RevertWhen_GetAmountOutEmpty() public {
        vm.expectRevert(AMM.InsufficientLiquidity.selector);
        market.getAmountOut(0, INITIAL_LIQUIDITY, 1);
    }

    function testFuzz_BuyRaisesPrice(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e3, 1_000e6);
        uint256 priceBefore = market.priceYes();
        uint256 kBefore = _k();
        (uint256 quotedShares,) = market.quoteBuy(Outcome.Yes, amountIn);

        vm.prank(alice);
        uint256 sharesOut = market.buy(Outcome.Yes, amountIn);

        assertEq(sharesOut, quotedShares);
        assertGe(market.priceYes(), priceBefore);
        assertGe(_k(), kBefore);
        _assertReservesMatchBalances();
    }

    function testFuzz_SellLowersPrice(uint256 splitAmount, uint256 sellAmount) public {
        splitAmount = bound(splitAmount, 1e6, 1_000e6);
        sellAmount = bound(sellAmount, 1e6, splitAmount);

        vm.prank(alice);
        market.split(splitAmount);

        uint256 priceBefore = market.priceYes();
        (uint256 quotedCollateral,) = market.quoteSell(Outcome.Yes, sellAmount);
        vm.assume(quotedCollateral > 0);

        vm.prank(alice);
        uint256 collateralOut = market.sell(Outcome.Yes, sellAmount);

        assertEq(collateralOut, quotedCollateral);
        assertLt(market.priceYes(), priceBefore);
        _assertReservesMatchBalances();
    }

    function test_LibraryGetAmountOutEdgeCases() public view {
        (uint256 zeroOut, uint256 zeroFee) =
            harness.getAmountOut(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 200);
        assertEq(zeroOut, 0);
        assertEq(zeroFee, 0);

        (uint256 noFeeOut, uint256 noFee) =
            harness.getAmountOut(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 100e6, 0);
        uint256 gross = (100e6 * INITIAL_LIQUIDITY) / (INITIAL_LIQUIDITY + 100e6);
        assertEq(noFeeOut, gross);
        assertEq(noFee, 0);

        (uint256 maxFeeOut, uint256 maxFee) =
            harness.getAmountOut(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 100e6, 10_000);
        assertEq(maxFeeOut, 0);
        assertEq(maxFee, gross);
    }

    function test_RevertWhen_LibraryReserveInZero() public {
        vm.expectRevert(AMM.InsufficientLiquidity.selector);
        harness.getAmountOut(0, INITIAL_LIQUIDITY, 1, 200);
    }

    function test_RevertWhen_LibraryReserveOutZero() public {
        vm.expectRevert(AMM.InsufficientLiquidity.selector);
        harness.getAmountOut(INITIAL_LIQUIDITY, 0, 1, 200);
    }

    function test_LibraryApplyBuyZero() public view {
        AMM.Pool memory pool = AMM.Pool(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        (uint256 sharesOut, uint256 fee, AMM.Pool memory next) =
            harness.applyBuy(pool, Outcome.Yes, 0, 200);

        assertEq(sharesOut, 0);
        assertEq(fee, 0);
        assertEq(next.reserveYes, INITIAL_LIQUIDITY);
        assertEq(next.reserveNo, INITIAL_LIQUIDITY);
    }

    function test_RevertWhen_LibraryApplyBuyEmpty() public {
        AMM.Pool memory pool;
        vm.expectRevert(AMM.InsufficientLiquidity.selector);
        harness.applyBuy(pool, Outcome.Yes, 100e6, 200);
    }

    function test_RevertWhen_LibraryApplyBuyInvalidOutcome() public {
        AMM.Pool memory pool = AMM.Pool(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        vm.expectRevert(AMM.InvalidOutcome.selector);
        harness.applyBuy(pool, Outcome.Unresolved, 100e6, 200);
    }

    function test_LibraryApplySellZero() public view {
        AMM.Pool memory pool = AMM.Pool(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        (uint256 collateralOut, uint256 fee, AMM.Pool memory next) =
            harness.applySell(pool, Outcome.Yes, 0, 200);

        assertEq(collateralOut, 0);
        assertEq(fee, 0);
        assertEq(next.reserveYes, INITIAL_LIQUIDITY);
        assertEq(next.reserveNo, INITIAL_LIQUIDITY);
    }

    function test_RevertWhen_LibraryApplySellEmpty() public {
        AMM.Pool memory pool;
        vm.expectRevert(AMM.InsufficientLiquidity.selector);
        harness.applySell(pool, Outcome.Yes, 100e6, 200);
    }

    function test_RevertWhen_LibraryApplySellInvalidOutcome() public {
        AMM.Pool memory pool = AMM.Pool(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        vm.expectRevert(AMM.InvalidOutcome.selector);
        harness.applySell(pool, Outcome.Unresolved, 100e6, 200);
    }

    function test_LibrarySqrt() public view {
        assertEq(harness.sqrt(0), 0);
        assertEq(harness.sqrt(1), 1);
        assertEq(harness.sqrt(15), 3);
        assertEq(harness.sqrt(16), 4);
        assertEq(harness.sqrt(17), 4);
    }

    function _freshMarket() internal returns (PredictionMarket fresh) {
        vm.warp(vm.getBlockTimestamp() + factory.CREATION_COOLDOWN());
        address other = makeAddr("other");
        vm.prank(other);
        uint256 marketId = factory.createMarket(_config());
        fresh = PredictionMarket(factory.marketById(marketId));
    }
}
