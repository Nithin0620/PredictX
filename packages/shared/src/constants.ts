export const PROJECT_NAME = "PredictX";

export interface ChainConfig {
  /** EVM chain id. */
  id: number;
  /** Human-readable chain name. */
  name: string;
  /** Environment variable that holds the RPC URL. */
  rpcUrlEnv: string;
  /** Block explorer base URL. */
  explorerUrl: string;
  /** Native currency symbol (for gas display). */
  nativeCurrency: string;
}

export const BASE_SEPOLIA: ChainConfig = {
  id: 84532,
  name: "Base Sepolia",
  rpcUrlEnv: "BASE_SEPOLIA_RPC_URL",
  explorerUrl: "https://sepolia.basescan.org",
  nativeCurrency: "ETH",
};

export const DEFAULT_CHAIN = BASE_SEPOLIA;

export const SUPPORTED_CHAINS: readonly ChainConfig[] = [BASE_SEPOLIA];

/** USDC uses 6 decimals; outcome tokens intentionally match it (see ADR 0003). */
export const USDC_DECIMALS = 6;
export const OUTCOME_DECIMALS = 6;

/** Fee denominator for basis-point math. */
export const BPS_DENOMINATOR = 10_000;

/** Default trading fee: 200 bps = 2%. */
export const DEFAULT_FEE_BPS = 200;

/** Default dispute window (2 hours on testnet). */
export const DEFAULT_DISPUTE_WINDOW_SECONDS = 2 * 60 * 60;

/** Default finalization delay after the dispute window (0 on testnet). */
export const DEFAULT_FINALIZATION_DELAY_SECONDS = 0;
