// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Lifecycle states. Authoritative diagram: `docs/state-machine.md` (ADR 0006).
enum MarketStatus {
    Created,
    Active,
    Closed,
    Proposed,
    Disputed,
    Finalized
}

/// @notice Binary outcome. `Unresolved` is the pre-resolution sentinel.
enum Outcome {
    Unresolved,
    Yes,
    No
}

/**
 * @title MarketConfig
 * @notice Immutable parameters supplied when a market is created.
 * @param question Human-readable question, e.g. "Will ETH close above $4,000 on 2026-12-31?".
 * @param resolutionSource Where the outcome comes from (URL, feed description, or "" for manual).
 * @param deadline Unix timestamp (seconds) after which trading closes.
 * @param resolver Address allowed to propose the outcome.
 * @param feeBps Trading fee in basis points (200 = 2%).
 * @param initialLiquidity Initial USDC liquidity, in 6-decimal base units.
 */
struct MarketConfig {
    string question;
    string resolutionSource;
    uint64 deadline;
    address resolver;
    uint16 feeBps;
    uint256 initialLiquidity;
}
