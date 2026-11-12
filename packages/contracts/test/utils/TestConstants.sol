// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @notice Shared constants for tests. Mirrors `@predictx/shared` values so contract tests and the
 * off-chain packages agree on the same numbers.
 */
library TestConstants {
    uint256 internal constant USDC_DECIMALS = 6;
    uint256 internal constant DEFAULT_FEE_BPS = 200;
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant DEFAULT_DISPUTE_WINDOW = 2 hours;
    uint256 internal constant DEFAULT_FINALIZATION_DELAY = 0;
}
