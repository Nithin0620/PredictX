// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC
 * @notice Testnet-only USDC stand-in: 6 decimals, owner mint, and a rate-limited public faucet.
 * @dev Never deploy this as a real stablecoin. See ADR 0001 (testnet only).
 */
contract MockUSDC is ERC20, Ownable {
    /// @notice USDC uses 6 decimals; outcome tokens match it (ADR 0003).
    uint8 public constant DECIMALS = 6;

    /// @notice Amount a tester receives per faucet call: 10,000 mUSDC.
    uint256 public constant FAUCET_AMOUNT = 10_000 * 10 ** DECIMALS;

    /// @notice Minimum time between faucet calls per address.
    uint256 public constant FAUCET_COOLDOWN = 1 days;

    /// @notice Timestamp of the last faucet call per address (0 = never).
    mapping(address account => uint256 timestamp) public lastFaucetAt;

    error FaucetCooldownActive(address account, uint256 availableAt);

    constructor(address initialOwner) ERC20("Mock USD Coin", "mUSDC") Ownable(initialOwner) { }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /// @notice Public testnet faucet. Mints `FAUCET_AMOUNT` to the caller at most once per day.
    function faucet() external {
        uint256 last = lastFaucetAt[msg.sender];
        // Cooldown is wall-clock based; minor validator timestamp drift is acceptable.
        // forge-lint: disable-next-line(block-timestamp)
        if (last != 0 && block.timestamp < last + FAUCET_COOLDOWN) {
            revert FaucetCooldownActive(msg.sender, last + FAUCET_COOLDOWN);
        }
        lastFaucetAt[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);
    }

    /// @notice Owner mint for seeding testers and deploy scripts.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
