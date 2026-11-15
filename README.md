# PredictX Lite

A student-sized **parimutuel binary prediction market** on **Base Sepolia** (testnet only).

Users create YES/NO markets, bet mock USDC, a trusted resolver picks the outcome after the
deadline, and winners split the total pool pro-rata. There is no AMM, no LP token, no oracle, no
dispute system, and no backend.

> **Status:** Contracts and frontend are implemented. Foundry has 39 passing tests and 100% source
> coverage. The Next.js app builds successfully. Base Sepolia deployment is pending deployer
> credentials and a thirdweb client ID. The full AMM/oracle/backend version is preserved on
> `master`; the active branch is `main/lite`.

## Stack

| Layer      | Tech                                   |
| ---------- | -------------------------------------- |
| Contracts  | Solidity 0.8.24 + Foundry              |
| Collateral | Mock USDC (6 decimals)                 |
| Frontend   | Next.js 16 + TypeScript + thirdweb SDK |
| Styling    | Tailwind CSS 4                         |
| Chain      | Base Sepolia                           |

## Repository layout

```text
PredictX/
├── packages/
│   ├── contracts/        # MockUSDC, PredictXMarket, PredictXFactory
│   └── web/              # Next.js Lite frontend
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
pnpm build
```

## Local chain

```bash
# terminal 1
make chain

# terminal 2
make deploy-local
```

The deploy script prints the MockUSDC and factory addresses. Copy them into
`packages/web/.env.local` (see `packages/web/.env.example`) along with a thirdweb client ID:

```bash
NEXT_PUBLIC_THIRDWEB_CLIENT_ID=...
NEXT_PUBLIC_USDC_ADDRESS=0x...
NEXT_PUBLIC_FACTORY_ADDRESS=0x...
```

Then run the frontend:

```bash
pnpm --filter @predictx/web dev
```

Open `http://localhost:3000`. Add Base Sepolia to your wallet, use the faucet button to mint mock
USDC, then create or trade a market.

## Contracts

```bash
cd packages/contracts
forge build
forge test
forge coverage
forge fmt --check
forge lint
```

## Base Sepolia deployment

```bash
cp .env.example .env
# fill PRIVATE_KEY and BASE_SEPOLIA_RPC_URL
set -a && . ./.env && set +a
forge script script/DeployLite.s.sol:DeployLite \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" \
  --broadcast \
  --verify
```

Use a dedicated, funded testnet wallet. Never commit `.env`.

## Frontend routes

| Route               | Purpose                                        |
| ------------------- | ---------------------------------------------- |
| `/`                 | Market list, pools, status                     |
| `/market/[address]` | Market detail, bet, resolve, claim             |
| `/create`           | Create a YES/NO market with a trusted resolver |

## Safety

- Testnet only. Mock USDC has no real value.
- The resolver is trusted. If it never resolves, funds stay locked.
- There is no dispute path and no audit.
- Rounding dust from integer division remains locked in the market contract.

See [`PHASES.md`](./PHASES.md) and [`packages/web/README.md`](./packages/web/README.md) for details.
