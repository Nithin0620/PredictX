// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { OutcomeToken } from "./OutcomeToken.sol";
import { LPToken } from "./LPToken.sol";
import { AMM } from "./AMM.sol";
import { MarketConfig, MarketStatus, Outcome, TradeSide } from "./MarketTypes.sol";

/**
 * @title PredictionMarket
 * @notice One binary market: immutable metadata plus the lifecycle state machine.
 * @dev Phase 5 implements `Created → Active → Closed → Proposed → Finalized`. The `Disputed` state
 * is defined but unreachable until the bonded dispute flow lands in Phase 12.
 * See `docs/state-machine.md` for the authoritative diagram and transition table.
 */
contract PredictionMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Time between a proposed outcome and permissionless finalization (testnet: 2 hours).
    uint64 public constant DISPUTE_WINDOW = 2 hours;

    /// @notice Extra delay after the dispute window before finalization (testnet: 0).
    uint64 public constant FINALIZATION_DELAY = 0;

    /// @notice Scale used by `priceYes` (1e18 = 100%).
    uint256 public constant PRICE_SCALE = 1e18;

    /// @notice Basis-point denominator for fee math.
    uint256 private constant BPS = 10_000;

    /// @notice Protocol's share of each trading fee (2,000 bps = 20%).
    uint256 public constant PROTOCOL_FEE_SHARE_BPS = 2_000;

    /// @notice Sequential id assigned by the factory (starts at 1).
    uint256 public immutable marketId;

    /// @notice Factory that deployed this market.
    address public immutable factory;

    /// @notice Account that created the market.
    address public immutable creator;

    /// @notice Recipient of the protocol share of trading fees.
    address public immutable treasury;

    /// @notice Collateral token (MockUSDC on testnet).
    IERC20 public immutable collateral;

    /// @notice YES outcome token, fully backed 1:1 by collateral.
    OutcomeToken public immutable yesToken;

    /// @notice NO outcome token, fully backed 1:1 by collateral.
    OutcomeToken public immutable noToken;

    /// @notice LP shares for this market's CPMM reserves.
    LPToken public immutable lpToken;

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

    /// @notice Cumulative winning shares redeemed by each account (payout is 1:1 USDC).
    mapping(address account => uint256 shares) public claimed;

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
    event Redeemed(
        address indexed user,
        uint256 indexed marketId,
        Outcome outcome,
        uint256 shares,
        uint256 payout
    );
    event LiquiditySettled(address indexed provider, uint256 lpAmount, uint256 payout);
    event Split(address indexed account, uint256 amount);
    event Merged(address indexed account, uint256 amount);
    event Trade(
        address indexed user,
        uint256 indexed marketId,
        Outcome indexed outcome,
        TradeSide side,
        uint256 shares,
        uint256 collateral,
        uint256 fee,
        uint256 price
    );
    event ProtocolFee(address indexed treasury, Outcome feeOutcome, uint256 amount);
    event LiquidityAdded(address indexed provider, uint256 collateral, uint256 lpAmount);
    event LiquidityRemoved(
        address indexed provider, uint256 lpAmount, uint256 yesOut, uint256 noOut
    );

    error ZeroAddress();
    error ZeroAmount();
    error InvalidState(MarketStatus current, MarketStatus required);
    error MarketNotOpen();
    error NotCreator(address caller);
    error NotResolver(address caller);
    error DeadlineNotReached(uint256 deadline);
    error InvalidOutcome();
    error InsufficientOutput();
    error DeadlineExpired(uint256 deadline);
    error SlippageExceeded(uint256 actual, uint256 minimum);
    error DisputeWindowActive(uint256 availableAt);

    struct TradeData {
        uint256 shares;
        uint256 collateral;
        uint256 fee;
        uint256 protocolFee;
        uint256 priceBefore;
    }

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
        address factory_,
        address treasury_
    ) {
        if (
            creator_ == address(0) || collateral_ == address(0) || factory_ == address(0)
                || treasury_ == address(0)
        ) {
            revert ZeroAddress();
        }

        marketId = marketId_;
        factory = factory_;
        creator = creator_;
        treasury = treasury_;
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
        lpToken = new LPToken(
            string.concat("PredictX LP #", idString), string.concat("pLP", idString), address(this)
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
    function seedLiquidity() external nonReentrant onlyCreator onlyState(MarketStatus.Created) {
        uint256 amount = initialLiquidity;
        _split(address(this), amount);

        _pool.reserveYes = amount;
        _pool.reserveNo = amount;
        _status = MarketStatus.Active;
        lpToken.mint(msg.sender, amount);

        // forge-lint: disable-next-line(reentrancy-events)
        emit LiquiditySeeded(msg.sender, amount, amount, amount);
        // forge-lint: disable-next-line(reentrancy-events)
        emit LiquidityAdded(msg.sender, amount, amount);
        // forge-lint: disable-next-line(reentrancy-events)
        emit MarketActivated(marketId);
    }

    /**
     * @notice Add USDC liquidity to the CPMM and mint LP shares.
     * @dev Splits the deposit into YES + NO and adds both legs. Shares are minted at the smaller
     * of the two reserve ratios, so an imbalanced pool cannot dilute existing LPs.
     */
    function addLiquidity(uint256 usdcAmount)
        external
        nonReentrant
        onlyState(MarketStatus.Active)
        returns (uint256 lpAmount)
    {
        if (usdcAmount == 0) revert ZeroAmount();

        uint256 supply = lpToken.totalSupply();
        uint256 reserveYes = _pool.reserveYes;
        uint256 reserveNo = _pool.reserveNo;

        if (supply == 0) {
            if (reserveYes != 0 || reserveNo != 0) revert AMM.InsufficientLiquidity();
            lpAmount = usdcAmount;
        } else {
            if (reserveYes == 0 || reserveNo == 0) revert AMM.InsufficientLiquidity();
            uint256 lpFromYes = (usdcAmount * supply) / reserveYes;
            uint256 lpFromNo = (usdcAmount * supply) / reserveNo;
            lpAmount = lpFromYes < lpFromNo ? lpFromYes : lpFromNo;
        }
        if (lpAmount == 0) revert InsufficientOutput();

        _pool.reserveYes = reserveYes + usdcAmount;
        _pool.reserveNo = reserveNo + usdcAmount;
        emit LiquidityAdded(msg.sender, usdcAmount, lpAmount);
        lpToken.mint(msg.sender, lpAmount);

        _split(address(this), usdcAmount);
    }

    /**
     * @notice Burn LP shares and return the proportional YES/NO reserves.
     * @dev Call `merge` afterwards to convert the returned complete sets into USDC.
     */
    function removeLiquidity(uint256 lpAmount)
        external
        nonReentrant
        onlyState(MarketStatus.Active)
        returns (uint256 yesOut, uint256 noOut)
    {
        if (lpAmount == 0) revert ZeroAmount();

        uint256 supply = lpToken.totalSupply();
        if (supply == 0) revert AMM.InsufficientLiquidity();

        yesOut = (_pool.reserveYes * lpAmount) / supply;
        noOut = (_pool.reserveNo * lpAmount) / supply;
        if (yesOut == 0 || noOut == 0) revert InsufficientOutput();

        _pool.reserveYes -= yesOut;
        _pool.reserveNo -= noOut;
        emit LiquidityRemoved(msg.sender, lpAmount, yesOut, noOut);

        lpToken.burn(msg.sender, lpAmount);
        IERC20(address(yesToken)).safeTransfer(msg.sender, yesOut);
        IERC20(address(noToken)).safeTransfer(msg.sender, noOut);
    }

    /// @notice Pool reserves (YES, NO) held by the market.
    function getReserves() external view returns (uint256 reserveYes, uint256 reserveNo) {
        return (_pool.reserveYes, _pool.reserveNo);
    }

    /// @notice Implied probability of YES, scaled by `PRICE_SCALE` (1e18 = 100%).
    function priceYes() external view returns (uint256) {
        return _priceYes();
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
     * @notice Buy `outcome` with `collateralIn` USDC.
     * @dev Splits the collateral, adds the opposite leg to the pool, and pays the caller the desired
     * leg plus the split leg. The protocol share of the output fee is sent to `treasury` in the
     * outcome token; the LP share stays in the pool.
     */
    function buy(Outcome outcome, uint256 collateralIn, uint256 minSharesOut, uint256 deadline_)
        external
        nonReentrant
        onlyState(MarketStatus.Active)
        returns (uint256 sharesOut)
    {
        // Deadlines are wall-clock based by design; validator drift is bounded and acceptable.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > deadline_) revert DeadlineExpired(deadline_);
        if (collateralIn == 0) revert ZeroAmount();
        _validateOutcome(outcome);

        TradeData memory data;
        data.collateral = collateralIn;
        data.priceBefore = _priceYes();

        AMM.Pool memory next;
        (data.shares, data.fee, next) = AMM.applyBuy(_pool, outcome, collateralIn, feeBps);
        if (data.shares < minSharesOut) revert SlippageExceeded(data.shares, minSharesOut);

        data.protocolFee = (data.fee * PROTOCOL_FEE_SHARE_BPS) / BPS;
        _decreaseReserve(next, outcome, data.protocolFee);
        _pool = next;

        if (data.protocolFee > 0) {
            emit ProtocolFee(treasury, outcome, data.protocolFee);
        }
        _emitTrade(msg.sender, outcome, TradeSide.Buy, data);

        _split(address(this), collateralIn);

        OutcomeToken token = outcome == Outcome.Yes ? yesToken : noToken;
        IERC20(address(token)).safeTransfer(msg.sender, data.shares);
        if (data.protocolFee > 0) {
            IERC20(address(token)).safeTransfer(treasury, data.protocolFee);
        }

        return data.shares;
    }

    /**
     * @notice Sell `sharesIn` `outcome` tokens for USDC.
     * @dev Swaps the sold leg for the opposite leg in the pool, burns the merged pair, and pays USDC.
     * The protocol share of the output fee is sent to `treasury` in the opposite outcome token.
     */
    function sell(Outcome outcome, uint256 sharesIn, uint256 minCollateralOut, uint256 deadline_)
        external
        nonReentrant
        onlyState(MarketStatus.Active)
        returns (uint256 collateralOut)
    {
        // Deadlines are wall-clock based by design; validator drift is bounded and acceptable.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > deadline_) revert DeadlineExpired(deadline_);
        if (sharesIn == 0) revert ZeroAmount();
        _validateOutcome(outcome);

        TradeData memory data;
        data.shares = sharesIn;
        data.priceBefore = _priceYes();

        AMM.Pool memory next;
        (data.collateral, data.fee, next) = AMM.applySell(_pool, outcome, sharesIn, feeBps);
        if (data.collateral == 0) revert InsufficientOutput();
        if (data.collateral < minCollateralOut) {
            revert SlippageExceeded(data.collateral, minCollateralOut);
        }

        Outcome feeOutcome = _feeOutcome(outcome, TradeSide.Sell);
        data.protocolFee = (data.fee * PROTOCOL_FEE_SHARE_BPS) / BPS;
        _decreaseReserve(next, feeOutcome, data.protocolFee);
        _pool = next;

        if (data.protocolFee > 0) {
            emit ProtocolFee(treasury, feeOutcome, data.protocolFee);
        }
        _emitTrade(msg.sender, outcome, TradeSide.Sell, data);

        OutcomeToken token = outcome == Outcome.Yes ? yesToken : noToken;
        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), sharesIn);

        yesToken.burn(address(this), data.collateral);
        noToken.burn(address(this), data.collateral);
        collateral.safeTransfer(msg.sender, data.collateral);

        if (data.protocolFee > 0) {
            OutcomeToken feeToken = feeOutcome == Outcome.Yes ? yesToken : noToken;
            IERC20(address(feeToken)).safeTransfer(treasury, data.protocolFee);
        }

        return data.collateral;
    }

    function _validateOutcome(Outcome outcome) internal pure {
        if (outcome == Outcome.Unresolved) revert InvalidOutcome();
    }

    function _priceYes() internal view returns (uint256) {
        uint256 total = _pool.reserveYes + _pool.reserveNo;
        if (total == 0) revert AMM.InsufficientLiquidity();
        return (_pool.reserveNo * PRICE_SCALE) / total;
    }

    function _feeOutcome(Outcome outcome, TradeSide side) internal pure returns (Outcome) {
        if (side == TradeSide.Buy) return outcome;
        return outcome == Outcome.Yes ? Outcome.No : Outcome.Yes;
    }

    function _feeValue(Outcome outcome, TradeSide side, uint256 fee, uint256 priceBefore)
        internal
        pure
        returns (uint256)
    {
        Outcome feeOutcome = _feeOutcome(outcome, side);
        uint256 feePrice = feeOutcome == Outcome.Yes ? priceBefore : PRICE_SCALE - priceBefore;
        return (fee * feePrice) / PRICE_SCALE;
    }

    function _decreaseReserve(AMM.Pool memory pool, Outcome outcome, uint256 amount) internal pure {
        if (outcome == Outcome.Yes) {
            pool.reserveYes -= amount;
        } else {
            pool.reserveNo -= amount;
        }
    }

    function _emitTrade(address user, Outcome outcome, TradeSide side, TradeData memory data)
        internal
    {
        emit Trade(
            user,
            marketId,
            outcome,
            side,
            data.shares,
            data.collateral,
            _feeValue(outcome, side, data.fee, data.priceBefore),
            _priceYes()
        );
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
    function split(uint256 amount)
        external
        nonReentrant
        onlyState(MarketStatus.Active)
        returns (uint256)
    {
        _split(msg.sender, amount);
        return amount;
    }

    /**
     * @notice Burn `amount` YES + `amount` NO from the caller and return `amount` USDC.
     * @dev Allowed from `Active` onward (not while the market is still `Created`). No fee is charged.
     */
    function merge(uint256 amount) external nonReentrant returns (uint256) {
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
     * @notice Redeem the caller's full winning-outcome balance for 1 USDC per share.
     */
    function redeem() external nonReentrant onlyState(MarketStatus.Finalized) returns (uint256) {
        OutcomeToken token = _winningToken();
        return _redeem(msg.sender, token.balanceOf(msg.sender));
    }

    /**
     * @notice Redeem a specific number of winning shares for 1 USDC per share.
     * @dev The winning token is burned, so the same shares cannot be claimed twice.
     */
    function redeem(uint256 amount)
        external
        nonReentrant
        onlyState(MarketStatus.Finalized)
        returns (uint256)
    {
        return _redeem(msg.sender, amount);
    }

    /**
     * @notice Settle LP shares after finalization for the winning reserve's USDC value.
     * @dev Burns the LP's proportional YES/NO reserves and pays `winningReserve × share`.
     * Losing reserve tokens are burned and are worth zero.
     */
    function redeemLiquidity(uint256 lpAmount)
        external
        nonReentrant
        onlyState(MarketStatus.Finalized)
        returns (uint256 payout)
    {
        if (lpAmount == 0) revert ZeroAmount();

        uint256 supply = lpToken.totalSupply();
        if (supply == 0) revert AMM.InsufficientLiquidity();

        uint256 yesOut = (_pool.reserveYes * lpAmount) / supply;
        uint256 noOut = (_pool.reserveNo * lpAmount) / supply;
        payout = proposedOutcome == Outcome.Yes ? yesOut : noOut;
        if (payout == 0) revert InsufficientOutput();

        _pool.reserveYes -= yesOut;
        _pool.reserveNo -= noOut;
        emit LiquiditySettled(msg.sender, lpAmount, payout);

        lpToken.burn(msg.sender, lpAmount);
        yesToken.burn(address(this), yesOut);
        noToken.burn(address(this), noOut);
        collateral.safeTransfer(msg.sender, payout);
    }

    /**
     * @notice True when the market still covers every outstanding winning claim.
     * @dev Before finalization YES/NO supplies must match and collateral must cover YES. After
     * finalization only the winning supply is a claim; losing tokens are worth zero.
     */
    function isFullyBacked() external view returns (bool) {
        uint256 yesSupply = yesToken.totalSupply();
        uint256 noSupply = noToken.totalSupply();
        uint256 collateralBalance = collateral.balanceOf(address(this));

        if (_status != MarketStatus.Finalized) {
            return yesSupply == noSupply && collateralBalance >= yesSupply;
        }

        uint256 winningSupply = proposedOutcome == Outcome.Yes ? yesSupply : noSupply;
        return collateralBalance >= winningSupply;
    }

    function _winningToken() internal view returns (OutcomeToken) {
        return proposedOutcome == Outcome.Yes ? yesToken : noToken;
    }

    function _redeem(address user, uint256 amount) internal returns (uint256 payout) {
        if (amount == 0) revert ZeroAmount();

        OutcomeToken token = _winningToken();
        claimed[user] += amount;
        emit Redeemed(user, marketId, proposedOutcome, amount, amount);

        token.burn(user, amount);
        collateral.safeTransfer(user, amount);
        return amount;
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
