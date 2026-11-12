// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { MarketConfig, MarketStatus, Outcome } from "./MarketTypes.sol";

/**
 * @title PredictionMarket
 * @notice One binary market: immutable metadata plus the lifecycle state machine.
 * @dev Phase 5 implements `Created → Active → Closed → Proposed → Finalized`. The `Disputed` state
 * is defined but unreachable until the bonded dispute flow lands in Phase 12.
 * See `docs/state-machine.md` for the authoritative diagram and transition table.
 */
contract PredictionMarket {
    /// @notice Time between a proposed outcome and permissionless finalization (testnet: 2 hours).
    uint64 public constant DISPUTE_WINDOW = 2 hours;

    /// @notice Extra delay after the dispute window before finalization (testnet: 0).
    uint64 public constant FINALIZATION_DELAY = 0;

    /// @notice Sequential id assigned by the factory (starts at 1).
    uint256 public immutable marketId;

    /// @notice Factory that deployed this market.
    address public immutable factory;

    /// @notice Account that created the market.
    address public immutable creator;

    /// @notice Collateral token (MockUSDC on testnet).
    IERC20 public immutable collateral;

    string public question;
    string public resolutionSource;

    /// @notice Unix timestamp after which trading closes.
    uint64 public immutable deadline;

    /// @notice Address allowed to propose the outcome.
    address public immutable resolver;

    /// @notice Trading fee in basis points.
    uint16 public immutable feeBps;

    /// @notice Initial USDC liquidity, in 6-decimal base units.
    uint256 public immutable initialLiquidity;

    /// @notice Current lifecycle state.
    MarketStatus private _status;

    /// @notice Outcome proposed by the resolver (Unresolved until proposed).
    Outcome public proposedOutcome;

    /// @notice Timestamp of the proposal (0 until proposed).
    uint64 public proposedAt;

    /// @notice Timestamp when trading closed (0 until closed).
    uint64 public closedAt;

    event MarketActivated(uint256 indexed marketId);
    event MarketClosed(uint256 indexed marketId, uint256 closedAt);
    event OutcomeProposed(uint256 indexed marketId, Outcome outcome, address indexed proposer);
    event MarketFinalized(uint256 indexed marketId, Outcome outcome);

    error ZeroAddress();
    error InvalidState(MarketStatus current, MarketStatus required);
    error NotCreator(address caller);
    error NotResolver(address caller);
    error DeadlineNotReached(uint256 deadline);
    error InvalidOutcome();
    error DisputeWindowActive(uint256 availableAt);

    modifier onlyState(MarketStatus expected) {
        if (_status != expected) revert InvalidState(_status, expected);
        _;
    }

    modifier onlyCreator() {
        if (msg.sender != creator) revert NotCreator(msg.sender);
        _;
    }

    modifier onlyResolver() {
        if (msg.sender != resolver) revert NotResolver(msg.sender);
        _;
    }

    constructor(
        uint256 marketId_,
        MarketConfig memory config,
        address creator_,
        address collateral_,
        address factory_
    ) {
        if (creator_ == address(0) || collateral_ == address(0) || factory_ == address(0)) {
            revert ZeroAddress();
        }

        marketId = marketId_;
        factory = factory_;
        creator = creator_;
        collateral = IERC20(collateral_);

        question = config.question;
        resolutionSource = config.resolutionSource;
        deadline = config.deadline;
        resolver = config.resolver;
        feeBps = config.feeBps;
        initialLiquidity = config.initialLiquidity;

        _status = MarketStatus.Created;
    }

    /// @notice Current lifecycle state.
    function status() external view returns (MarketStatus) {
        return _status;
    }

    /**
     * @notice Move `Created → Active`.
     * @dev Temporary Phase 5 entry point, creator-only. Phase 7 replaces this with
     * `seedLiquidity`, which activates the market only after collateral is deposited.
     */
    function activate() external onlyCreator onlyState(MarketStatus.Created) {
        _status = MarketStatus.Active;
        emit MarketActivated(marketId);
    }

    /**
     * @notice Close trading after the deadline. Permissionless.
     * @dev Allowed once `block.timestamp >= deadline`. Trading code (Phase 8) must reject the
     * `Closed` state.
     */
    function close() external onlyState(MarketStatus.Active) {
        // Deadlines are wall-clock based by design; validator drift is bounded and acceptable.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < deadline) revert DeadlineNotReached(deadline);

        _status = MarketStatus.Closed;
        closedAt = SafeCast.toUint64(block.timestamp);
        emit MarketClosed(marketId, block.timestamp);
    }

    /**
     * @notice Resolver proposes the outcome. Phase 11 wires the oracle to this entry point.
     * @param outcome `Yes` or `No` (`Unresolved` is rejected).
     */
    function proposeOutcome(Outcome outcome) external onlyResolver onlyState(MarketStatus.Closed) {
        if (outcome == Outcome.Unresolved) revert InvalidOutcome();

        proposedOutcome = outcome;
        proposedAt = SafeCast.toUint64(block.timestamp);
        _status = MarketStatus.Proposed;

        emit OutcomeProposed(marketId, outcome, msg.sender);
    }

    /**
     * @notice Finalize an undisputed proposal after the dispute window. Permissionless.
     * @dev Phase 12 adds the dispute path; if a dispute is open the market will be `Disputed` and
     * this function will revert.
     */
    function finalize() external onlyState(MarketStatus.Proposed) {
        uint256 availableAt = uint256(proposedAt) + DISPUTE_WINDOW + FINALIZATION_DELAY;
        // Wall-clock window by design; see ADR 0006.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < availableAt) revert DisputeWindowActive(availableAt);

        _status = MarketStatus.Finalized;
        emit MarketFinalized(marketId, proposedOutcome);
    }
}
