# @predictx/web

Next.js App Router frontend for **PredictX Lite**.

The app reads Base Sepolia directly and sends wallet transactions with thirdweb. There is no
backend, indexer, or database.

## Routes

| Route               | Contents                                                    |
| ------------------- | ----------------------------------------------------------- |
| `/`                 | Market cards with question, pools, status, and deadline     |
| `/market/[address]` | Full market detail, bet form, resolver controls, claim      |
| `/create`           | Create a YES/NO market with a deadline and trusted resolver |

## Features

- thirdweb `ConnectButton` with Base Sepolia as the target chain
- Wrong-network banner with one-click chain switch
- MockUSDC balance display and faucet button
- ERC-20 approval before betting
- YES/NO parimutuel betting with live pool refreshes
- Resolver-only YES/NO resolution after the deadline
- Pro-rata winner claim with estimated payout
- Setup notice when required env vars are missing
- Loading, pending, success, and error states

## Environment

Copy `packages/web/.env.example` to `packages/web/.env.local` and fill in:

```bash
NEXT_PUBLIC_THIRDWEB_CLIENT_ID=...
NEXT_PUBLIC_USDC_ADDRESS=0x...
NEXT_PUBLIC_FACTORY_ADDRESS=0x...
```

Get a free thirdweb client ID from <https://thirdweb.com/create-api-key>. The app targets Base
Sepolia (`84532`) and shows a setup notice until all three values are present.

## Development

```bash
pnpm install
pnpm --filter @predictx/web dev
```

Open `http://localhost:3000`.

## Build and checks

```bash
pnpm --filter @predictx/web typecheck
pnpm --filter @predictx/web build
```

## Contracts

Deploy the Lite contracts first. From the repository root:

```bash
make deploy-local
```

Or deploy to Base Sepolia with `forge script` as described in the root README. Copy the printed
MockUSDC and factory addresses into `.env.local`.

## Notes

- Testnet only; mock USDC has no value.
- The resolver is trusted and can freeze funds by never resolving.
- No dispute mechanism, no protocol fees, no AMM, and no audit.
- Rounding dust from integer division remains locked in the market contract.
