// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MockUSDC } from "../src/MockUSDC.sol";

contract MockUSDCTest is Test {
    MockUSDC internal usdc;
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");

    function setUp() public {
        usdc = new MockUSDC(owner);
    }

    function test_Metadata() public view {
        assertEq(usdc.name(), "Mock USD Coin");
        assertEq(usdc.symbol(), "mUSDC");
        assertEq(usdc.decimals(), 6);
        assertEq(usdc.owner(), owner);
    }

    function test_OwnerCanMint() public {
        vm.prank(owner);
        usdc.mint(alice, 1_000e6);

        assertEq(usdc.balanceOf(alice), 1_000e6);
        assertEq(usdc.totalSupply(), 1_000e6);
    }

    function test_NonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        usdc.mint(alice, 1);
    }

    function test_ZeroOwnerReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new MockUSDC(address(0));
    }

    function test_FaucetMintsOnce() public {
        vm.prank(alice);
        usdc.faucet();

        assertEq(usdc.balanceOf(alice), usdc.FAUCET_AMOUNT());
        assertEq(usdc.lastFaucetAt(alice), block.timestamp);
    }

    function test_FaucetCooldownReverts() public {
        vm.prank(alice);
        usdc.faucet();

        uint256 availableAt = block.timestamp + usdc.FAUCET_COOLDOWN();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MockUSDC.FaucetCooldownActive.selector, alice, availableAt)
        );
        usdc.faucet();
    }

    function test_FaucetWorksAfterCooldown() public {
        vm.prank(alice);
        usdc.faucet();

        vm.warp(block.timestamp + usdc.FAUCET_COOLDOWN());

        vm.prank(alice);
        usdc.faucet();

        assertEq(usdc.balanceOf(alice), 2 * usdc.FAUCET_AMOUNT());
    }

    function test_FaucetIsPerAddress() public {
        address bob = makeAddr("bob");

        vm.prank(alice);
        usdc.faucet();

        vm.prank(bob);
        usdc.faucet();

        assertEq(usdc.balanceOf(alice), usdc.FAUCET_AMOUNT());
        assertEq(usdc.balanceOf(bob), usdc.FAUCET_AMOUNT());
    }
}
