// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MarketConfig } from "./MarketTypes.sol";
import { PredictionMarket } from "./PredictionMarket.sol";

/**
 * @title MarketDeployer
 * @notice Deploys `PredictionMarket` instances on behalf of `MarketFactory`.
 * @dev Keeping market creation bytecode here keeps `MarketFactory` below the EIP-170 runtime limit
 * as the market contract grows.
 */
contract MarketDeployer {
    address public immutable factory;

    error OnlyFactory();

    constructor() {
        factory = msg.sender;
    }

    function deploy(
        uint256 marketId,
        MarketConfig calldata config,
        address creator,
        address collateral,
        address treasury
    ) external returns (PredictionMarket market) {
        if (msg.sender != factory) revert OnlyFactory();
        market = new PredictionMarket(marketId, config, creator, collateral, factory, treasury);
    }
}
