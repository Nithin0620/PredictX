# @predictx/contracts

Foundry workspace for **PredictX Lite** on **Base Sepolia**.

The full AMM/LP/oracle/dispute contracts were removed from the Lite branch. Only the reusable
`MockUSDC` collateral token remains. The Lite contracts will be added here:

- `PredictXMarket.sol` — parimutuel YES/NO pools, resolution, pro-rata claims
- `PredictXFactory.sol` — market registry
- `script/DeployLite.s.sol` — deployment script

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

## Local chain

```bash
# terminal 1 — deterministic Anvil accounts on chain id 31337
make chain

# terminal 2 — deploy MockUSDC
make deploy-local
```

Anvil account #0 is the default deployer for local runs. Override with `PRIVATE_KEY`.

## Layout

```text
packages/contracts/
├── foundry.toml
├── src/
│   └── MockUSDC.sol
├── test/
│   └── MockUSDC.t.sol
├── script/
│   └── DeployLite.s.sol
└── lib/          # dependencies (git-ignored; restore with `make contracts-deps`)
```

## Remappings

- `@openzeppelin/contracts/` → `lib/openzeppelin-contracts/contracts/`
- `forge-std/` → `lib/forge-std/src/`
