// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PredictXMarket } from "./PredictXMarket.sol";

contract PredictXFactory {
    IERC20 public immutable collateral;
    uint256 public marketCount;
    mapping(uint256 marketId => address market) public markets;

    event MarketCreated(
        uint256 indexed marketId,
        address indexed market,
        address indexed creator,
        address resolver,
        uint64 deadline,
        string question
    );

    error ZeroAddress();

    constructor(address collateral_) {
        if (collateral_ == address(0)) revert ZeroAddress();
        collateral = IERC20(collateral_);
    }

    function createMarket(string calldata question, uint64 deadline, address resolver)
        external
        returns (PredictXMarket market)
    {
        uint256 marketId = ++marketCount;

        market = new PredictXMarket(
            marketId, msg.sender, address(collateral), resolver, question, deadline
        );
        markets[marketId] = address(market);

        // forge-lint: disable-next-line(reentrancy-events)
        emit MarketCreated(marketId, address(market), msg.sender, resolver, deadline, question);
    }

    function getMarkets() external view returns (address[] memory list) {
        list = new address[](marketCount);
        for (uint256 i; i < marketCount; ++i) {
            list[i] = markets[i + 1];
        }
    }
}
