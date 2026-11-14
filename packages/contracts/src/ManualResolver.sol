// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { PredictionMarket } from "./PredictionMarket.sol";
import { MarketStatus, Outcome } from "./MarketTypes.sol";

/**
 * @title ManualResolver
 * @notice Owner-controlled resolver for markets without a reliable on-chain price feed.
 * @dev Deploy this contract first, then create markets with `resolver = address(manualResolver)`.
 * The owner closes the market (if needed) and proposes YES or NO after the deadline.
 */
contract ManualResolver {
    address public immutable owner;

    event Resolved(address indexed market, Outcome outcome, address indexed resolver);

    error ZeroAddress();
    error NotOwner(address caller);
    error InvalidOutcome();
    error NotResolver(address market);
    error MarketNotClosed(MarketStatus status);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
    }

    /**
     * @notice Close (if needed) and propose `outcome` for `market`.
     * @dev Only the owner may resolve, and only for markets that point at this resolver.
     */
    function resolve(PredictionMarket market, Outcome outcome)
        external
        onlyOwner
        returns (Outcome)
    {
        if (outcome == Outcome.Unresolved) revert InvalidOutcome();
        if (market.resolver() != address(this)) revert NotResolver(address(market));

        MarketStatus status = market.status();
        if (status == MarketStatus.Active) {
            market.close();
        } else if (status != MarketStatus.Closed) {
            revert MarketNotClosed(status);
        }

        // The event is emitted before the final external call; reordering is not user-visible.
        // forge-lint: disable-next-line(reentrancy-events)
        emit Resolved(address(market), outcome, msg.sender);
        market.proposeOutcome(outcome);
        return outcome;
    }
}
