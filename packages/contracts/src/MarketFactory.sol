// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MarketConfig } from "./MarketTypes.sol";
import { PredictionMarket } from "./PredictionMarket.sol";

/**
 * @title MarketFactory
 * @notice Creates markets, assigns sequential ids, and keeps an enumerable registry.
 * @dev Creation is permissionless with a simple per-creator cooldown as an anti-spam guard.
 */
contract MarketFactory {
    /// @notice Minimum seconds between two market creations by the same account.
    uint256 public constant CREATION_COOLDOWN = 60;

    /// @notice Upper bound on the trading fee: 1,000 bps = 10%.
    uint256 public constant MAX_FEE_BPS = 1_000;

    /// @notice Minimum initial liquidity: 1 USDC (6 decimals).
    uint256 public constant MIN_INITIAL_LIQUIDITY = 1e6;

    /// @notice Maximum question length in bytes.
    uint256 public constant MAX_QUESTION_LENGTH = 512;

    /// @notice Collateral token all markets use.
    IERC20 public immutable usdc;

    /// @notice Id that the next market will receive.
    uint256 public nextMarketId = 1;

    mapping(uint256 marketId => address market) public marketById;
    mapping(address market => uint256 marketId) public marketIdByAddress;
    mapping(address creator => uint256 timestamp) public lastCreationAt;

    address[] private _markets;

    event MarketCreated(
        uint256 indexed marketId,
        address indexed market,
        address indexed creator,
        string question,
        uint256 deadline
    );

    error ZeroAddress();
    error EmptyQuestion();
    error QuestionTooLong(uint256 length, uint256 maximum);
    error DeadlineInPast(uint256 deadline);
    error InvalidResolver();
    error FeeTooHigh(uint16 feeBps, uint256 maximum);
    error LiquidityTooLow(uint256 provided, uint256 minimum);
    error CreationTooSoon(address creator, uint256 availableAt);

    constructor(address usdc_) {
        if (usdc_ == address(0)) revert ZeroAddress();
        usdc = IERC20(usdc_);
    }

    /**
     * @notice Deploy a new market and register it.
     * @param config Validated market parameters.
     * @return marketId Sequential id assigned to the new market.
     */
    function createMarket(MarketConfig calldata config) external returns (uint256 marketId) {
        _validateConfig(config);
        _checkCooldown(msg.sender);

        lastCreationAt[msg.sender] = block.timestamp;
        marketId = nextMarketId++;

        PredictionMarket market =
            new PredictionMarket(marketId, config, msg.sender, address(usdc), address(this));
        address marketAddress = address(market);

        marketById[marketId] = marketAddress;
        marketIdByAddress[marketAddress] = marketId;
        _markets.push(marketAddress);

        // The market constructor makes no external calls, so it cannot reenter the factory.
        // forge-lint: disable-next-line(reentrancy-events)
        emit MarketCreated(marketId, marketAddress, msg.sender, config.question, config.deadline);
    }

    /// @notice Number of markets created so far.
    function marketCount() external view returns (uint256) {
        return _markets.length;
    }

    /// @notice Market address at `index` (0-based), for enumeration.
    function marketAt(uint256 index) external view returns (address) {
        return _markets[index];
    }

    /// @notice All market addresses, for enumeration.
    function getMarkets() external view returns (address[] memory) {
        return _markets;
    }

    function _validateConfig(MarketConfig calldata config) private view {
        uint256 questionLength = bytes(config.question).length;
        if (questionLength == 0) revert EmptyQuestion();
        if (questionLength > MAX_QUESTION_LENGTH) {
            revert QuestionTooLong(questionLength, MAX_QUESTION_LENGTH);
        }
        // Deadlines are wall-clock based by design; validator drift is bounded and acceptable.
        // forge-lint: disable-next-line(block-timestamp)
        if (config.deadline <= block.timestamp) revert DeadlineInPast(config.deadline);
        if (config.resolver == address(0)) revert InvalidResolver();
        if (config.feeBps > MAX_FEE_BPS) revert FeeTooHigh(config.feeBps, MAX_FEE_BPS);
        if (config.initialLiquidity < MIN_INITIAL_LIQUIDITY) {
            revert LiquidityTooLow(config.initialLiquidity, MIN_INITIAL_LIQUIDITY);
        }
    }

    function _checkCooldown(address creator) private view {
        uint256 last = lastCreationAt[creator];
        // Cooldown is wall-clock based; minor validator timestamp drift is acceptable.
        // forge-lint: disable-next-line(block-timestamp)
        if (last != 0 && block.timestamp < last + CREATION_COOLDOWN) {
            revert CreationTooSoon(creator, last + CREATION_COOLDOWN);
        }
    }
}
