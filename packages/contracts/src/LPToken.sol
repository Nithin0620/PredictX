// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title LPToken
 * @notice ERC-20 representing a pro-rata claim on a market's CPMM reserves and accrued LP fees.
 * @dev Mint/burn is restricted to the market. Uses 6 decimals so one unit tracks one USDC of
 * seeded liquidity (ADR 0003).
 */
contract LPToken is ERC20 {
    /// @notice LP shares use the same 6 decimals as USDC and outcome tokens.
    uint8 public constant DECIMALS = 6;

    /// @notice Distinguishes LP tokens from outcome tokens for indexers and coverage tooling.
    string public constant TOKEN_KIND = "LP";

    /// @notice The only address allowed to mint and burn.
    address public immutable market;

    error ZeroAddress();
    error OnlyMarket(address caller);

    modifier onlyMarket() {
        if (msg.sender != market) revert OnlyMarket(msg.sender);
        _;
    }

    constructor(string memory name_, string memory symbol_, address market_) ERC20(name_, symbol_) {
        if (market_ == address(0)) revert ZeroAddress();
        market = market_;
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /// @notice Mint LP shares. Market-only.
    function mint(address to, uint256 amount) external onlyMarket {
        _mint(to, amount);
    }

    /// @notice Burn LP shares from `from`. Market-only.
    function burn(address from, uint256 amount) external onlyMarket {
        _burn(from, amount);
    }
}
