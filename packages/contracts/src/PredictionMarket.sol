// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { OutcomeToken } from "./OutcomeToken.sol";
import { AMM } from "./AMM.sol";
import { MarketConfig, MarketStatus, Outcome } from "./MarketTypes.sol";

/**
 * @title PredictionMarket
 * @notice One binary market: immutable metadata plus the lifecycle state machine.
 * @dev Phase 5 implements `Created → Active → Closed → Proposed → Finalized`. The `Disputed` state
 * is defined but unreachable until the bonded dispute flow lands in Phase 12.
 * See `docs/state-machine.md` for the authoritative diagram and transition table.
 */
contract PredictionMarket {
    using SafeERC20 for IERC20;

    /// @notice Time between a proposed outcome and permissionless finalization (testnet: 2 hours).
    uint64 public constant DISPUTE_WINDOW = 2 hours;

    /// @notice Extra delay after the dispute window before finalization (testnet: 0).
    uint64 public constant FINALIZATION_DELAY = 0;

    /// @notice Scale used by `priceYes` (1e18 = 100%).
    uint256 public constant PRICE_SCALE = 1e18;

    /// @notice Sequential id assigned by the factory (starts at 1).
    uint256 public immutable marketId;

    /// @notice Factory that deployed this market.
    address public immutable factory;

    /// @notice Account that created the market.
    address public immutable creator;

    /// @notice Collateral token (MockUSDC on testnet).
    IERC20 public immutable collateral;

    /// @notice YES outcome token, fully backed 1:1 by collateral.
    OutcomeToken public immutable yesToken;

    /// @notice NO outcome token, fully backed 1:1 by collateral.
    OutcomeToken public immutable noToken;

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

    /// @notice CPMM reserves (YES/NO) held by this market.
    AMM.Pool private _pool;

    /// @notice Outcome proposed by the resolver (Unresolved until proposed).
    Outcome public proposedOutcome;

    /// @notice Timestamp of the proposal (0 until proposed).
    uint64 public proposedAt;

    /// @notice Timestamp when trading closed (0 until closed).
    uint64 public closedAt;

    event MarketActivated(uint256 indexed marketId);
    event LiquiditySeeded(
        address indexed creator, uint256 collateral, uint256 reserveYes, uint256 reserveNo
    );
    event MarketClosed(uint256 indexed marketId, uint256 closedAt);
    event OutcomeProposed(uint256 indexed marketId, Outcome outcome, address indexed proposer);
    event MarketFinalized(uint256 indexed marketId, Outcome outcome);
    event Split(address indexed account, uint256 amount);
    event Merged(address indexed account, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error InvalidState(MarketStatus current, MarketStatus required);
    error MarketNotOpen();
    error NotCreator(address caller);
    error NotResolver(address caller);
    error DeadlineNotReached(uint256 deadline);
    error InvalidOutcome();
    error InsufficientOutput();
    error DisputeWindowActive(uint256 availableAt);
    error RedeemNotImplemented();

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

        string memory idString = _toString(marketId_);
        yesToken = new OutcomeToken(
            string.concat("PredictX YES #", idString),
            string.concat("pYES", idString),
            address(this)
        );
        noToken = new OutcomeToken(
            string.concat("PredictX NO #", idString), string.concat("pNO", idString), address(this)
        );

        _status = MarketStatus.Created;
    }

    /// @notice Current lifecycle state.
    function status() external view returns (MarketStatus) {
        return _status;
    }

    /**
     * @notice Seed the CPMM with the configured initial liquidity and activate trading.
     * @dev Creator-only. Pulls `initialLiquidity` USDC, splits it into YES + NO, and deposits both
     * legs into the pool at a 50/50 starting price. Replaces the Phase 5 temporary `activate()`.
     */
    function seedLiquidity() external onlyCreator onlyState(MarketStatus.Created) {
        uint256 amount = initialLiquidity;
        _split(address(this), amount);

        _pool.reserveYes = amount;
        _pool.reserveNo = amount;
        _status = MarketStatus.Active;

        // forge-lint: disable-next-line(reentrancy-events)
        emit LiquiditySeeded(msg.sender, amount, amount, amount);
        // forge-lint: disable-next-line(reentrancy-events)
        emit MarketActivated(marketId);
    }

    /// @notice Pool reserves (YES, NO) held by the market.
    function getReserves() external view returns (uint256 reserveYes, uint256 reserveNo) {
        return (_pool.reserveYes, _pool.reserveNo);
    }

    /// @notice Implied probability of YES, scaled by `PRICE_SCALE` (1e18 = 100%).
    function priceYes() external view returns (uint256) {
        uint256 total = _pool.reserveYes + _pool.reserveNo;
        if (total == 0) revert AMM.InsufficientLiquidity();
        return (_pool.reserveNo * PRICE_SCALE) / total;
    }

    /// @notice CPMM output for arbitrary reserves, using this market's fee.
    function getAmountOut(uint256 reserveIn, uint256 reserveOut, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        (uint256 amountOut,) = AMM.getAmountOut(reserveIn, reserveOut, amountIn, feeBps);
        return amountOut;
    }

    /// @notice Quote a buy of `outcome` with `collateralIn` USDC.
    function quoteBuy(Outcome outcome, uint256 collateralIn)
        external
        view
        returns (uint256 sharesOut, uint256 fee)
    {
        if (collateralIn == 0) revert ZeroAmount();
        _validateOutcome(outcome);
        return AMM.quoteBuy(_pool, outcome, collateralIn, feeBps);
    }

    /// @notice Quote a sell of `sharesIn` outcome tokens.
    function quoteSell(Outcome outcome, uint256 sharesIn)
        external
        view
        returns (uint256 collateralOut, uint256 fee)
    {
        if (sharesIn == 0) revert ZeroAmount();
        _validateOutcome(outcome);
        return AMM.quoteSell(_pool, outcome, sharesIn, feeBps);
    }

    /**
     * @notice Buy `outcome` with `collateralIn` USDC. Phase 8 adds slippage/deadline + fee routing.
     * @dev Splits the collateral, adds the opposite leg to the pool, and pays the caller the desired
     * leg plus the split leg. Fees are retained in the pool.
     */
    function buy(Outcome outcome, uint256 collateralIn)
        external
        onlyState(MarketStatus.Active)
        returns (uint256 sharesOut)
    {
        if (collateralIn == 0) revert ZeroAmount();
        _validateOutcome(outcome);

        AMM.Pool memory next;
        (sharesOut,, next) = AMM.applyBuy(_pool, outcome, collateralIn, feeBps);
        _pool.reserveYes = next.reserveYes;
        _pool.reserveNo = next.reserveNo;

        _split(address(this), collateralIn);

        OutcomeToken token = outcome == Outcome.Yes ? yesToken : noToken;
        IERC20(address(token)).safeTransfer(msg.sender, sharesOut);
    }

    /**
     * @notice Sell `sharesIn` `outcome` tokens for USDC. Phase 8 adds slippage/deadline + fee routing.
     * @dev Swaps the sold leg for the opposite leg in the pool, burns the merged pair, and pays USDC.
     */
    function sell(Outcome outcome, uint256 sharesIn)
        external
        onlyState(MarketStatus.Active)
        returns (uint256 collateralOut)
    {
        if (sharesIn == 0) revert ZeroAmount();
        _validateOutcome(outcome);

        AMM.Pool memory next;
        (collateralOut,, next) = AMM.applySell(_pool, outcome, sharesIn, feeBps);
        if (collateralOut == 0) revert InsufficientOutput();

        _pool.reserveYes = next.reserveYes;
        _pool.reserveNo = next.reserveNo;

        OutcomeToken token = outcome == Outcome.Yes ? yesToken : noToken;
        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), sharesIn);

        yesToken.burn(address(this), collateralOut);
        noToken.burn(address(this), collateralOut);
        collateral.safeTransfer(msg.sender, collateralOut);
    }

    function _validateOutcome(Outcome outcome) internal pure {
        if (outcome == Outcome.Unresolved) revert InvalidOutcome();
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

    /**
     * @notice Lock `amount` USDC and mint `amount` YES + `amount` NO to the caller.
     * @dev Trading must be open (`Active`). No fee is charged on split.
     */
    function split(uint256 amount) external onlyState(MarketStatus.Active) returns (uint256) {
        _split(msg.sender, amount);
        return amount;
    }

    /**
     * @notice Burn `amount` YES + `amount` NO from the caller and return `amount` USDC.
     * @dev Allowed from `Active` onward (not while the market is still `Created`). No fee is charged.
     */
    function merge(uint256 amount) external returns (uint256) {
        if (_status == MarketStatus.Created) revert MarketNotOpen();
        if (amount == 0) revert ZeroAmount();

        yesToken.burn(msg.sender, amount);
        noToken.burn(msg.sender, amount);
        collateral.safeTransfer(msg.sender, amount);

        // Collateral is the trusted MockUSDC (no transfer hooks on testnet).
        // forge-lint: disable-next-line(reentrancy-events)
        emit Merged(msg.sender, amount);
        return amount;
    }

    /**
     * @notice Placeholder for Phase 10; always reverts until redemption is implemented.
     */
    function redeem() external view onlyState(MarketStatus.Finalized) returns (uint256) {
        revert RedeemNotImplemented();
    }

    /// @notice True when YES/NO supplies match and collateral covers the outstanding YES claims.
    function isFullyBacked() external view returns (bool) {
        uint256 supply = yesToken.totalSupply();
        return supply == noToken.totalSupply() && collateral.balanceOf(address(this)) >= supply;
    }

    /**
     * @dev Pull `amount` collateral from `msg.sender` and mint a complete set to `account`.
     * Phase 7 reuses this to seed the AMM from the creator's deposit.
     */
    function _split(address account, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();

        collateral.safeTransferFrom(msg.sender, address(this), amount);
        // forge-lint: disable-next-line(reentrancy-no-eth)
        yesToken.mint(account, amount);
        // forge-lint: disable-next-line(reentrancy-no-eth)
        noToken.mint(account, amount);

        // Collateral is the trusted MockUSDC (no transfer hooks on testnet).
        // forge-lint: disable-next-line(reentrancy-events)
        emit Split(account, amount);
    }

    /// @dev Minimal decimal string conversion; OZ `Strings` requires solc >= 0.8.31.
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits = 0;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(SafeCast.toUint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
