// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { PredictXFactory } from "../src/PredictXFactory.sol";

contract DeployLite is Script {
    uint256 internal constant ANVIL_PK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external returns (MockUSDC usdc, PredictXFactory factory) {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", ANVIL_PK);
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        usdc = new MockUSDC(deployer);
        factory = new PredictXFactory(address(usdc));
        vm.stopBroadcast();

        console2.log("MockUSDC deployed at:", address(usdc));
        console2.log("PredictXFactory deployed at:", address(factory));
        console2.log("Owner:", deployer);
    }
}
