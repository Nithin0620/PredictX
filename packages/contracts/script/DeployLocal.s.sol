// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";

/**
 * @notice Deploys the collateral token and market factory to a local Anvil chain.
 * @dev OracleResolver / DisputeManager are wired in later phases.
 */
contract DeployLocal is Script {
    // Anvil account #0. Well-known test key — local only, never use on a real network.
    uint256 internal constant ANVIL_PK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external returns (MockUSDC usdc, MarketFactory factory) {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", ANVIL_PK);
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        usdc = new MockUSDC(deployer);
        factory = new MarketFactory(address(usdc));
        vm.stopBroadcast();

        console2.log("MockUSDC deployed at:", address(usdc));
        console2.log("MarketFactory deployed at:", address(factory));
        console2.log("Owner:", deployer);
    }
}
