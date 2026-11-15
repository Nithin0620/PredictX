# @predictx/contracts

Foundry workspace for **PredictX Lite** on **Base Sepolia**.

The full AMM/LP/oracle/dispute contracts were removed from the Lite branch. The Lite protocol is:

- `PredictXMarket.sol` — parimutuel YES/NO pools, resolution, pro-rata claims
- `PredictXFactory.sol` — market registry
- `PredictXTypes.sol` — shared outcome enum
- `MockUSDC.sol` — 6-decimal test collateral
- `script/DeployLite.s.sol` — deploy MockUSDC and the factory

## Prerequisites

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
# make sure ~/.foundry/bin is on PATH
```

## Install dependencies

```bash
make contracts-deps
# or, from this directory:
forge install foundry-rs/forge-std@v1.17.0 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.7.0 --no-git --shallow
```

## Commands

```bash
forge build
forge test
forge fmt --check
forge fmt
forge snapshot
forge coverage --report summary
```

Via the workspace:

```bash
pnpm --filter @predictx/contracts build
pnpm --filter @predictx/contracts test
```

Coverage is 100% for lines, statements, branches, and functions in the three Lite source contracts.
`script/DeployLite.s.sol` is exercised by the local deployment flow, not by unit tests.

## Trust model

- The resolver is trusted and can resolve only after the deadline.
- Winners split the entire pool pro-rata; rounding dust stays in the market.
- There is no admin withdrawal, upgrade path, oracle, or dispute mechanism.
- Testnet only. Mock USDC has no real value.

## Local chain

```bash
# terminal 1 — deterministic Anvil accounts on chain id 31337
make chain

# terminal 2 — deploy MockUSDC and PredictXFactory
make deploy-local
```

Anvil account #0 is the default deployer for local runs. Override with `PRIVATE_KEY`.

## Layout

```text
packages/contracts/
├── foundry.toml
├── src/
│   ├── MockUSDC.sol
│   ├── PredictXFactory.sol
│   ├── PredictXMarket.sol
│   └── PredictXTypes.sol
├── test/
│   ├── MockUSDC.t.sol
│   ├── PredictXFactory.t.sol
│   └── PredictXMarket.t.sol
├── script/
│   └── DeployLite.s.sol
└── lib/          # dependencies (git-ignored; restore with `make contracts-deps`)
```

## Remappings

- `@openzeppelin/contracts/` → `lib/openzeppelin-contracts/contracts/`
- `forge-std/` → `lib/forge-std/src/`
