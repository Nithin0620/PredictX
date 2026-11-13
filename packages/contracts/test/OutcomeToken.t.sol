// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { OutcomeToken } from "../src/OutcomeToken.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract OutcomeTokenTest is Test {
    OutcomeToken internal token;
    address internal market = address(this);
    address internal holder = makeAddr("holder");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        token = new OutcomeToken("PredictX YES #1", "pYES1", market);
    }

    function test_Metadata() public view {
        assertEq(token.name(), "PredictX YES #1");
        assertEq(token.symbol(), "pYES1");
        assertEq(token.decimals(), TestConstants.USDC_DECIMALS);
        assertEq(token.DECIMALS(), TestConstants.USDC_DECIMALS);
        assertEq(token.market(), market);
    }

    function test_RevertWhen_MarketIsZero() public {
        vm.expectRevert(OutcomeToken.ZeroAddress.selector);
        new OutcomeToken("PredictX YES #1", "pYES1", address(0));
    }

    function test_MarketCanMint() public {
        token.mint(holder, 1_000e6);

        assertEq(token.balanceOf(holder), 1_000e6);
        assertEq(token.totalSupply(), 1_000e6);
    }

    function test_MarketCanBurn() public {
        token.mint(holder, 1_000e6);
        token.burn(holder, 400e6);

        assertEq(token.balanceOf(holder), 600e6);
        assertEq(token.totalSupply(), 600e6);
    }

    function test_RevertWhen_NonMarketMints() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(OutcomeToken.OnlyMarket.selector, stranger));
        token.mint(holder, 1);
    }

    function test_RevertWhen_NonMarketBurns() public {
        token.mint(holder, 1);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(OutcomeToken.OnlyMarket.selector, stranger));
        token.burn(holder, 1);
    }

    function testFuzz_MintBurnRoundTrip(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        token.mint(holder, amount);
        assertEq(token.balanceOf(holder), amount);

        token.burn(holder, amount);
        assertEq(token.balanceOf(holder), 0);
        assertEq(token.totalSupply(), 0);
    }
}
