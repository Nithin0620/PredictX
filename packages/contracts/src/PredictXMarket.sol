// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Outcome } from "./PredictXTypes.sol";

contract PredictXMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public immutable marketId;
    address public immutable creator;
    address public immutable resolver;
    IERC20 public immutable collateral;
    uint64 public immutable deadline;
    uint64 public immutable createdAt;
    string public question;

    uint256 public totalYes;
    uint256 public totalNo;
    Outcome public outcome;

    mapping(address account => uint256 amount) public yesStake;
    mapping(address account => uint256 amount) public noStake;
    mapping(address account => bool) public claimed;

    event Bet(address indexed user, Outcome indexed side, uint256 amount);
    event Resolved(Outcome indexed outcome, address indexed resolver);
    event Claimed(address indexed user, uint256 payout);

    error ZeroAddress();
    error ZeroAmount();
    error InvalidQuestion();
    error InvalidDeadline(uint64 deadline);
    error InvalidOutcome();
    error MarketClosed(uint64 deadline);
    error MarketResolved(Outcome outcome);
    error NotResolver(address caller);
    error DeadlineNotReached(uint64 deadline);
    error AlreadyResolved(Outcome outcome);
    error NotResolved();
    error AlreadyClaimed(address user);
    error NothingToClaim(address user);

    constructor(
        uint256 marketId_,
        address creator_,
        address collateral_,
        address resolver_,
        string memory question_,
        uint64 deadline_
    ) {
        if (creator_ == address(0) || collateral_ == address(0) || resolver_ == address(0)) {
            revert ZeroAddress();
        }
        if (bytes(question_).length == 0) revert InvalidQuestion();
        // forge-lint: disable-next-line(block-timestamp)
        if (deadline_ <= block.timestamp) revert InvalidDeadline(deadline_);

        marketId = marketId_;
        creator = creator_;
        resolver = resolver_;
        collateral = IERC20(collateral_);
        question = question_;
        deadline = deadline_;
        createdAt = SafeCast.toUint64(block.timestamp);
    }

    function bet(Outcome side, uint256 amount) external nonReentrant {
        if (outcome != Outcome.Unresolved) revert MarketResolved(outcome);
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= deadline) revert MarketClosed(deadline);
        if (side == Outcome.Unresolved) revert InvalidOutcome();
        if (amount == 0) revert ZeroAmount();

        collateral.safeTransferFrom(msg.sender, address(this), amount);

        if (side == Outcome.Yes) {
            yesStake[msg.sender] += amount;
            totalYes += amount;
        } else {
            noStake[msg.sender] += amount;
            totalNo += amount;
        }

        emit Bet(msg.sender, side, amount);
    }

    function resolve(Outcome result) external {
        if (msg.sender != resolver) revert NotResolver(msg.sender);
        if (outcome != Outcome.Unresolved) revert AlreadyResolved(outcome);
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < deadline) revert DeadlineNotReached(deadline);
        if (result == Outcome.Unresolved) revert InvalidOutcome();

        outcome = result;
        emit Resolved(result, msg.sender);
    }

    function claim() external nonReentrant returns (uint256 payout) {
        if (outcome == Outcome.Unresolved) revert NotResolved();
        if (claimed[msg.sender]) revert AlreadyClaimed(msg.sender);

        uint256 stake = outcome == Outcome.Yes ? yesStake[msg.sender] : noStake[msg.sender];
        if (stake == 0) revert NothingToClaim(msg.sender);

        uint256 winningPool = outcome == Outcome.Yes ? totalYes : totalNo;
        uint256 totalPool = totalYes + totalNo;

        claimed[msg.sender] = true;
        payout = stake * totalPool / winningPool;

        collateral.safeTransfer(msg.sender, payout);
        emit Claimed(msg.sender, payout);
    }
}
