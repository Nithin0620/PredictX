// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketDeployer } from "../src/MarketDeployer.sol";
import { MarketConfig } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";

contract MarketDeployerTest is Test {
    MockUSDC internal usdc;
    MarketFactory internal factory;
    MarketDeployer internal deployer;

    function setUp() public {
        usdc = new MockUSDC(address(this));
        factory = new MarketFactory(address(usdc), address(this));
        deployer = factory.marketDeployer();
    }

    function _config() internal view returns (MarketConfig memory config) {
        config = MarketConfig({
            question: "Will it rain tomorrow?",
            resolutionSource: "",
            deadline: uint64(block.timestamp + 1 days),
            resolver: address(this),
            feeBps: 200,
            initialLiquidity: 1_000e6
        });
    }

    function test_FactoryCanDeploy() public {
        vm.prank(address(factory));
        PredictionMarket market =
            deployer.deploy(1, _config(), address(this), address(usdc), address(this));

        assertEq(market.marketId(), 1);
        assertEq(market.factory(), address(factory));
        assertEq(market.creator(), address(this));
        assertEq(address(market.collateral()), address(usdc));
    }

    function test_NonFactoryCannotDeploy() public {
        vm.expectRevert(MarketDeployer.OnlyFactory.selector);
        deployer.deploy(1, _config(), address(this), address(usdc), address(this));
    }
}
