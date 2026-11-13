// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { AMMHandler } from "./invariant/AMMHandler.sol";
import { TestConstants } from "./utils/TestConstants.sol";

/**
 * @notice Stateful fuzz test: trading must never reduce `k`, break backing, or desync reserves.
 */
contract AMMInvariantTest is Test {
    MockUSDC internal usdc;
    MarketFactory internal factory;
    PredictionMarket internal market;
    AMMHandler internal handler;

    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");
    address internal actor = makeAddr("actor");
    uint64 internal deadline;

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(address(this));
        factory = new MarketFactory(address(usdc));
        deadline = uint64(block.timestamp + 30 days);

        vm.prank(creator);
        uint256 marketId = factory.createMarket(_config());
        market = PredictionMarket(factory.marketById(marketId));

        usdc.mint(creator, 1_000e6);
        vm.startPrank(creator);
        usdc.approve(address(market), 1_000e6);
        market.seedLiquidity();
        vm.stopPrank();

        usdc.mint(actor, 1_000_000e6);
        vm.startPrank(actor);
        usdc.approve(address(market), type(uint256).max);
        market.yesToken().approve(address(market), type(uint256).max);
        market.noToken().approve(address(market), type(uint256).max);
        vm.stopPrank();

        handler = new AMMHandler(market, usdc, actor);
        targetContract(address(handler));
    }

    function _config() internal view returns (MarketConfig memory config) {
        config = MarketConfig({
            question: "Will ETH close above $4,000 on 2026-12-31?",
            resolutionSource: "https://example.com/eth",
            deadline: deadline,
            resolver: resolver,
            feeBps: uint16(TestConstants.DEFAULT_FEE_BPS),
            initialLiquidity: 1_000e6
        });
    }

    function invariant_KNeverDecreases() public view {
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertGe(reserveYes * reserveNo, handler.initialK(), "k decreased");
    }

    function invariant_ReservesMatchBalances() public view {
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        assertEq(market.yesToken().balanceOf(address(market)), reserveYes, "YES balance mismatch");
        assertEq(market.noToken().balanceOf(address(market)), reserveNo, "NO balance mismatch");
    }

    function invariant_FullyBacked() public view {
        uint256 yesSupply = market.yesToken().totalSupply();
        assertEq(yesSupply, market.noToken().totalSupply(), "YES/NO supply mismatch");
        assertGe(usdc.balanceOf(address(market)), yesSupply, "collateral below supply");
        assertTrue(market.isFullyBacked(), "market not fully backed");
    }

    function invariant_PriceInRange() public view {
        (uint256 reserveYes, uint256 reserveNo) = market.getReserves();
        if (reserveYes + reserveNo == 0) return;

        uint256 price = market.priceYes();
        assertGt(price, 0, "price must be > 0");
        assertLt(price, 1e18, "price must be < 1");
    }
}
