// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Placeholder
 * @notice Temporary contract used to prove the Foundry + OpenZeppelin toolchain works.
 * @dev Replaced by MockUSDC / MarketFactory / PredictionMarket in Phase 4+.
 */
contract Placeholder is Ownable {
    string public constant NAME = "PredictX";
    uint256 public constant VERSION = 0;

    event Initialized(address indexed owner);

    constructor(address initialOwner) Ownable(initialOwner) {
        emit Initialized(initialOwner);
    }

    function ping() external pure returns (string memory) {
        return "pong";
    }
}
