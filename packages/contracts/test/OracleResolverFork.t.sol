// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { MarketConfig, MarketStatus, Outcome } from "../src/MarketTypes.sol";
import { PredictionMarket } from "../src/PredictionMarket.sol";
import { OracleResolver } from "../src/OracleResolver.sol";
import { TestConstants } from "./utils/TestConstants.sol";

/**
 * @notice Optional Base Sepolia fork test against the live Chainlink ETH/USD feed.
 * @dev Skipped unless `BASE_SEPOLIA_RPC_URL` and `CHAINLINK_ETH_USD_FEED` are set.
 */
contract OracleResolverForkTest is Test {
    uint256 internal constant INITIAL_LIQUIDITY = 1_000e6;
    uint256 internal constant MAX_STALENESS = 7 days;

    function test_ForkResolveEthUsd() public {
        string memory rpcUrl = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
        address feed = vm.envOr("CHAINLINK_ETH_USD_FEED", address(0));

        if (bytes(rpcUrl).length == 0 || feed == address(0)) {
            vm.skip(true);
            return;
        }

        vm.createSelectFork(rpcUrl);

        MockUSDC usdc = new MockUSDC(address(this));
        OracleResolver oracle =
            new OracleResolver(feed, OracleResolver.Comparator.GreaterThan, 0, MAX_STALENESS);
        MarketFactory factory = new MarketFactory(address(usdc), address(this));

        uint64 deadline = uint64(block.timestamp + 1 days);
        MarketConfig memory config = MarketConfig({
            question: "Is ETH/USD above zero?",
            resolutionSource: "chainlink:ETH/USD",
            deadline: deadline,
            resolver: address(oracle),
            feeBps: uint16(TestConstants.DEFAULT_FEE_BPS),
            initialLiquidity: INITIAL_LIQUIDITY
        });

        uint256 marketId = factory.createMarket(config);
        PredictionMarket market = PredictionMarket(factory.marketById(marketId));

        usdc.mint(address(this), INITIAL_LIQUIDITY);
        usdc.approve(address(market), INITIAL_LIQUIDITY);
        market.seedLiquidity();

        vm.warp(deadline);
        oracle.resolve(market);

        assertEq(uint8(market.status()), uint8(MarketStatus.Proposed));
        assertEq(uint8(market.proposedOutcome()), uint8(Outcome.Yes));
    }
}
