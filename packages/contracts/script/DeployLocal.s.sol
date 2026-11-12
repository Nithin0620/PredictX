// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Placeholder } from "../src/Placeholder.sol";

/**
 * @notice Deploys the Phase 3 placeholder contract to a local Anvil chain.
 * @dev Real deploy scripts (USDC + MarketFactory + OracleResolver) arrive in Phase 4+.
 */
contract DeployLocal is Script {
    // Anvil account #0. Well-known test key — local only, never use on a real network.
    uint256 internal constant ANVIL_PK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external returns (Placeholder placeholder) {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", ANVIL_PK);
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        placeholder = new Placeholder(deployer);
        vm.stopBroadcast();

        console2.log("Placeholder deployed at:", address(placeholder));
        console2.log("Owner:", deployer);
    }
}
