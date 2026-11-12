export enum Outcome {
  Yes = "YES",
  No = "NO",
}

export enum MarketStatus {
  Created = "CREATED",
  Active = "ACTIVE",
  Closed = "CLOSED",
  Proposed = "PROPOSED",
  Disputed = "DISPUTED",
  Finalized = "FINALIZED",
}

export type Address = `0x${string}`;

export interface MarketConfig {
  question: string;
  /** Where the outcome comes from (URL, feed description, or "" for manual). */
  resolutionSource: string;
  /** Unix timestamp (seconds) after which trading closes. */
  deadline: number;
  resolver: Address;
  /** Trading fee in basis points. */
  feeBps: number;
  /** Initial liquidity in USDC base units (6 decimals). */
  initialLiquidity: bigint;
}

export interface MarketSummary {
  /** On-chain market id as a decimal string. */
  id: string;
  question: string;
  status: MarketStatus;
  /** Unix timestamp (seconds). */
  deadline: number;
  /** Implied probability of YES, in the range (0, 1). */
  probabilityYes: number;
}
