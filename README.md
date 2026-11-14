# PredictX Lite

A student-sized **parimutuel binary prediction market** on **Base Sepolia** (testnet only).

Users create YES/NO markets, bet mock USDC, a trusted resolver picks the outcome after the
deadline, and winners split the total pool pro-rata. There is no AMM, no LP token, no oracle, no
dispute system, and no backend.

> **Status:** Lite cleanup complete. The full AMM/oracle/backend version is preserved on `master`.
> The active branch is `main/lite`.

## Stack

| Layer      | Tech                              |
| ---------- | --------------------------------- |
| Contracts  | Solidity 0.8.24 + Foundry         |
| Collateral | Mock USDC (6 decimals)            |
| Frontend   | Next.js + TypeScript + wagmi/viem |
| Chain      | Base Sepolia                      |

## Repository layout

```text
PredictX/
├── packages/
│   ├── contracts/        # MockUSDC + Lite contracts (in progress)
│   └── web/              # Next.js Lite frontend (placeholder)
├── PHASES.md             # 4-phase Lite roadmap
├── PROJECT_PLAN.md       # Lite product plan
└── .github/workflows/    # CI
```

## Prerequisites

- Node.js >= 20
- pnpm 11
- Foundry (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)

## Setup

```bash
pnpm install
make contracts-deps
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
```

## Local chain

```bash
# terminal 1
make chain

# terminal 2
make deploy-local
```

## Contracts

```bash
cd packages/contracts
forge build
forge test
forge fmt --check
```

## What is next

1. Implement `PredictXMarket` and `PredictXFactory`.
2. Add 15–20 Foundry tests.
3. Build the Next.js frontend.
4. Deploy to Base Sepolia and record the demo.

See [`PHASES.md`](./PHASES.md) for the detailed plan.

## Safety

- Testnet only. Mock USDC has no real value.
- The resolver is trusted. If it never resolves, funds stay locked.
- There is no dispute path and no audit.
