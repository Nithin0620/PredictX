// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { Placeholder } from "../src/Placeholder.sol";
import { TestConstants } from "./utils/TestConstants.sol";

contract PlaceholderTest is Test {
    Placeholder internal placeholder;

    function setUp() public {
        placeholder = new Placeholder(address(this));
    }

    function test_Metadata() public view {
        assertEq(placeholder.NAME(), "PredictX");
        assertEq(placeholder.VERSION(), 0);
    }

    function test_Ping() public view {
        assertEq(placeholder.ping(), "pong");
    }

    function test_OwnerIsDeployer() public view {
        assertEq(placeholder.owner(), address(this));
    }

    function test_ConstantsMatchSharedConfig() public pure {
        assertEq(TestConstants.USDC_DECIMALS, 6);
        assertEq(TestConstants.DEFAULT_FEE_BPS, 200);
        assertLt(TestConstants.DEFAULT_FEE_BPS, TestConstants.BPS_DENOMINATOR);
    }
}
