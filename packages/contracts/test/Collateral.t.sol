// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/IERC6093.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, MarketStatus, Outcome } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract CollateralTest is Test {
    uint256 internal constant STARTING_BALANCE = 1_000_000e6;
    uint256 internal constant INITIAL_LIQUIDITY = 1_000e6;

    MockUSDC internal usdc;
    MarketFactory internal factory;
    PredictionMarket internal market;

    address internal creator = makeAddr("creator");
    address internal resolver = makeAddr("resolver");
    address internal alice = makeAddr("alice");
    uint64 internal deadline;

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(address(this));
        factory = new MarketFactory(address(usdc));
        deadline = uint64(block.timestamp + 30 days);

        vm.prank(creator);
        uint256 marketId = factory.createMarket(_config());
        market = PredictionMarket(factory.marketById(marketId));

        usdc.mint(creator, INITIAL_LIQUIDITY);
        vm.prank(creator);
        usdc.approve(address(market), INITIAL_LIQUIDITY);
        vm.prank(creator);
        market.seedLiquidity();

        usdc.mint(alice, STARTING_BALANCE);
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
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

    function _finalize() internal {
        vm.warp(deadline);
        market.close();

        vm.prank(resolver);
        market.proposeOutcome(Outcome.Yes);

        vm.warp(block.timestamp + market.DISPUTE_WINDOW());
        market.finalize();
    }

    function test_TokensDeployed() public view {
        assertTrue(address(market.yesToken()) != address(0));
        assertTrue(address(market.noToken()) != address(0));
        assertTrue(address(market.yesToken()) != address(market.noToken()));

        assertEq(market.yesToken().name(), "PredictX YES #1");
        assertEq(market.yesToken().symbol(), "pYES1");
        assertEq(market.noToken().name(), "PredictX NO #1");
        assertEq(market.noToken().symbol(), "pNO1");

        assertEq(market.yesToken().decimals(), TestConstants.USDC_DECIMALS);
        assertEq(market.noToken().decimals(), TestConstants.USDC_DECIMALS);
        assertEq(market.yesToken().market(), address(market));
        assertEq(market.noToken().market(), address(market));
    }

    function test_Split() public {
        uint256 amount = 1_000e6;
        uint256 aliceBefore = usdc.balanceOf(alice);

        vm.expectEmit(true, false, false, true);
        emit PredictionMarket.Split(alice, amount);

        vm.prank(alice);
        market.split(amount);

        assertEq(usdc.balanceOf(alice), aliceBefore - amount);
        assertEq(usdc.balanceOf(address(market)), INITIAL_LIQUIDITY + amount);
        assertEq(market.yesToken().balanceOf(alice), amount);
        assertEq(market.noToken().balanceOf(alice), amount);
        assertEq(market.yesToken().totalSupply(), INITIAL_LIQUIDITY + amount);
        assertEq(market.noToken().totalSupply(), INITIAL_LIQUIDITY + amount);
        assertTrue(market.isFullyBacked());
    }

    function test_Merge() public {
        uint256 amount = 1_000e6;
        uint256 aliceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        market.split(amount);

        vm.expectEmit(true, false, false, true);
        emit PredictionMarket.Merged(alice, amount);

        vm.prank(alice);
        market.merge(amount);

        assertEq(usdc.balanceOf(alice), aliceBefore);
        assertEq(usdc.balanceOf(address(market)), INITIAL_LIQUIDITY);
        assertEq(market.yesToken().balanceOf(alice), 0);
        assertEq(market.noToken().balanceOf(alice), 0);
        assertEq(market.yesToken().totalSupply(), INITIAL_LIQUIDITY);
        assertEq(market.noToken().totalSupply(), INITIAL_LIQUIDITY);
        assertTrue(market.isFullyBacked());
    }

    function test_MergeAfterClose() public {
        uint256 amount = 500e6;
        uint256 aliceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        market.split(amount);

        vm.warp(deadline);
        market.close();

        vm.prank(alice);
        market.merge(amount);

        assertEq(usdc.balanceOf(alice), aliceBefore);
        assertTrue(market.isFullyBacked());
    }

    function test_MergeAfterFinalize() public {
        uint256 amount = 500e6;
        uint256 aliceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        market.split(amount);
        _finalize();

        vm.prank(alice);
        market.merge(amount);

        assertEq(usdc.balanceOf(alice), aliceBefore);
        assertTrue(market.isFullyBacked());
    }

    function test_RevertWhen_SplitNotActive() public {
        PredictionMarket fresh = _newMarket();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Created, MarketStatus.Active
            )
        );
        fresh.split(1e6);
    }

    function test_RevertWhen_SplitAfterClose() public {
        vm.warp(deadline);
        market.close();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Closed, MarketStatus.Active
            )
        );
        market.split(1e6);
    }

    function test_RevertWhen_SplitZero() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.split(0);
    }

    function test_RevertWhen_MergeZero() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.merge(0);
    }

    function test_RevertWhen_MergeWhileCreated() public {
        PredictionMarket fresh = _newMarket();

        vm.prank(alice);
        vm.expectRevert(PredictionMarket.MarketNotOpen.selector);
        fresh.merge(1e6);
    }

    function test_RevertWhen_SplitWithoutApproval() public {
        uint256 amount = 100e6;
        vm.prank(alice);
        usdc.approve(address(market), 0);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(market), 0, amount
            )
        );
        market.split(amount);
    }

    function test_RevertWhen_MergeWithoutTokens() public {
        uint256 amount = 100e6;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, amount)
        );
        market.merge(amount);
    }

    function test_RedeemStubRevertsBeforeFinalize() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                PredictionMarket.InvalidState.selector, MarketStatus.Active, MarketStatus.Finalized
            )
        );
        market.redeem();
    }

    function test_RedeemStubRevertsAfterFinalize() public {
        _finalize();

        vm.expectRevert(PredictionMarket.RedeemNotImplemented.selector);
        market.redeem();
    }

    function testFuzz_SplitMergeRoundTrip(uint256 amount) public {
        amount = bound(amount, 1, STARTING_BALANCE);
        uint256 aliceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        market.split(amount);
        assertTrue(market.isFullyBacked());

        vm.prank(alice);
        market.merge(amount);
        assertTrue(market.isFullyBacked());

        assertEq(usdc.balanceOf(alice), aliceBefore);
        assertEq(market.yesToken().totalSupply(), INITIAL_LIQUIDITY);
        assertEq(market.noToken().totalSupply(), INITIAL_LIQUIDITY);
    }

    function testFuzz_MultipleSplitsAndMerges(uint256 first, uint256 second, uint256 merged)
        public
    {
        first = bound(first, 1, STARTING_BALANCE / 2);
        second = bound(second, 1, STARTING_BALANCE / 2);
        merged = bound(merged, 1, first + second);

        vm.prank(alice);
        market.split(first);
        vm.prank(alice);
        market.split(second);

        assertTrue(market.isFullyBacked());
        assertEq(market.yesToken().totalSupply(), INITIAL_LIQUIDITY + first + second);

        vm.prank(alice);
        market.merge(merged);

        assertTrue(market.isFullyBacked());
        assertEq(market.yesToken().totalSupply(), INITIAL_LIQUIDITY + first + second - merged);
        assertEq(market.noToken().totalSupply(), INITIAL_LIQUIDITY + first + second - merged);
    }

    function _newMarket() internal returns (PredictionMarket fresh) {
        address other = makeAddr("other");
        vm.prank(other);
        uint256 marketId = factory.createMarket(_config());
        fresh = PredictionMarket(factory.marketById(marketId));
    }
}
