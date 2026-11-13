// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title OutcomeToken
 * @notice YES or NO ERC-20 for a single market. Mint/burn is restricted to the market contract.
 * @dev Uses 6 decimals to match USDC and the 1:1 collateral model (ADR 0003).
 */
contract OutcomeToken is ERC20 {
    /// @notice USDC uses 6 decimals; outcome tokens match it (ADR 0003).
    uint8 public constant DECIMALS = 6;

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

    /// @notice Mint outcome tokens. Market-only.
    function mint(address to, uint256 amount) external onlyMarket {
        _mint(to, amount);
    }

    /// @notice Burn outcome tokens from `from`. Market-only (used by `merge`).
    function burn(address from, uint256 amount) external onlyMarket {
        _burn(from, amount);
    }
}
