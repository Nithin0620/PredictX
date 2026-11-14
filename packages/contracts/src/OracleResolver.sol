// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IAggregatorV3 } from "./interfaces/IAggregatorV3.sol";
import { PredictionMarket } from "./PredictionMarket.sol";
import { MarketStatus, Outcome } from "./MarketTypes.sol";

/**
 * @title OracleResolver
 * @notice Resolves price-threshold markets from a Chainlink AggregatorV3 feed.
 * @dev One resolver instance represents one feed + comparator + threshold configuration. Deploy it
 * first, then create markets with `resolver = address(oracleResolver)`. Anyone may call `resolve`
 * once the market deadline has passed; the resolver contract is the market's authorized proposer.
 */
contract OracleResolver {
    /// @notice Price comparison used to decide YES/NO.
    enum Comparator {
        GreaterThan,
        GreaterThanOrEqual,
        LessThan,
        LessThanOrEqual
    }

    /// @notice Chainlink feed used for resolution.
    IAggregatorV3 public immutable feed;

    /// @notice Comparison against `thresholdWad`.
    Comparator public immutable comparator;

    /// @notice Threshold normalized to 18 decimals (WAD).
    int256 public immutable thresholdWad;

    /// @notice Maximum age of the latest feed round, in seconds.
    uint256 public immutable maxStaleness;

    event Resolved(address indexed market, int256 answer, Outcome outcome, uint256 updatedAt);

    error ZeroAddress();
    error InvalidStaleness();
    error InvalidDecimals(uint8 decimals);
    error NotResolver(address market);
    error MarketNotClosed(MarketStatus status);
    error StalePrice(uint256 updatedAt, uint256 maxStaleness);
    error InvalidTimestamp(uint256 updatedAt);
    error IncompleteRound(uint80 roundId, uint80 answeredInRound);
    error InvalidPrice(int256 answer);

    constructor(
        address feed_,
        Comparator comparator_,
        int256 thresholdWad_,
        uint256 maxStaleness_
    ) {
        if (feed_ == address(0)) revert ZeroAddress();
        if (maxStaleness_ == 0) revert InvalidStaleness();

        feed = IAggregatorV3(feed_);
        comparator = comparator_;
        thresholdWad = thresholdWad_;
        maxStaleness = maxStaleness_;
    }

    /**
     * @notice Close (if needed) and propose the feed-derived outcome for `market`.
     * @dev Reverts if this contract is not the market's resolver, the market is not Active/Closed,
     * or the feed is stale/incomplete/non-positive.
     */
    function resolve(PredictionMarket market) external returns (Outcome outcome) {
        if (market.resolver() != address(this)) revert NotResolver(address(market));

        MarketStatus status = market.status();
        if (status == MarketStatus.Active) {
            market.close();
        } else if (status != MarketStatus.Closed) {
            revert MarketNotClosed(status);
        }

        (int256 answer, uint256 updatedAt) = _read();
        outcome = _outcome(_toWad(answer));
        // The event is emitted before the final external call; reordering is not user-visible.
        // forge-lint: disable-next-line(reentrancy-events)
        emit Resolved(address(market), answer, outcome, updatedAt);

        market.proposeOutcome(outcome);
    }

    /// @notice Read and validate the latest feed round, returning the normalized WAD answer.
    function latestAnswer() external view returns (int256 normalizedAnswer, uint256 updatedAt) {
        (int256 answer, uint256 updatedAt_) = _read();
        return (_toWad(answer), updatedAt_);
    }

    function _read() internal view returns (int256 answer, uint256 updatedAt) {
        (
            uint80 roundId,
            int256 answer_,
            uint256 startedAt_,
            uint256 updatedAt_,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        if (startedAt_ > updatedAt_) revert InvalidTimestamp(startedAt_);
        if (updatedAt_ == 0) revert StalePrice(updatedAt_, maxStaleness);
        // Feed timestamps are wall-clock based; validator drift is acceptable.
        // forge-lint: disable-next-line(block-timestamp)
        if (updatedAt_ > block.timestamp) revert InvalidTimestamp(updatedAt_);
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp - updatedAt_ > maxStaleness) {
            revert StalePrice(updatedAt_, maxStaleness);
        }
        if (answeredInRound < roundId) revert IncompleteRound(roundId, answeredInRound);
        if (answer_ <= 0) revert InvalidPrice(answer_);

        return (answer_, updatedAt_);
    }

    function _toWad(int256 answer) internal view returns (int256) {
        uint8 feedDecimals = feed.decimals();
        if (feedDecimals == 18) return answer;
        if (feedDecimals < 18) {
            return answer * int256(10 ** (18 - feedDecimals));
        }

        uint8 diff = feedDecimals - 18;
        if (diff > 18) revert InvalidDecimals(feedDecimals);
        return answer / int256(10 ** diff);
    }

    function _outcome(int256 normalizedAnswer) internal view returns (Outcome) {
        bool yes;
        if (comparator == Comparator.GreaterThan) {
            yes = normalizedAnswer > thresholdWad;
        } else if (comparator == Comparator.GreaterThanOrEqual) {
            yes = normalizedAnswer >= thresholdWad;
        } else if (comparator == Comparator.LessThan) {
            yes = normalizedAnswer < thresholdWad;
        } else {
            yes = normalizedAnswer <= thresholdWad;
        }
        return yes ? Outcome.Yes : Outcome.No;
    }
}
