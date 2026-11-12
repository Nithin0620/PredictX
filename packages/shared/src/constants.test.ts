import { describe, expect, it } from "vitest";
import {
  BASE_SEPOLIA,
  BPS_DENOMINATOR,
  DEFAULT_CHAIN,
  DEFAULT_DISPUTE_WINDOW_SECONDS,
  DEFAULT_FEE_BPS,
  OUTCOME_DECIMALS,
  SUPPORTED_CHAINS,
  USDC_DECIMALS,
} from "./constants.js";

describe("chain constants", () => {
  it("targets Base Sepolia (84532)", () => {
    expect(BASE_SEPOLIA.id).toBe(84532);
    expect(DEFAULT_CHAIN).toBe(BASE_SEPOLIA);
    expect(SUPPORTED_CHAINS).toContain(BASE_SEPOLIA);
  });

  it("exposes an explorer URL", () => {
    expect(BASE_SEPOLIA.explorerUrl).toMatch(/^https:\/\//);
  });
});

describe("market constants", () => {
  it("matches USDC and outcome decimals (6)", () => {
    expect(USDC_DECIMALS).toBe(6);
    expect(OUTCOME_DECIMALS).toBe(USDC_DECIMALS);
  });

  it("uses a valid fee in basis points", () => {
    expect(DEFAULT_FEE_BPS).toBeGreaterThan(0);
    expect(DEFAULT_FEE_BPS).toBeLessThan(BPS_DENOMINATOR);
  });

  it("has a positive dispute window", () => {
    expect(DEFAULT_DISPUTE_WINDOW_SECONDS).toBeGreaterThan(0);
  });
});
