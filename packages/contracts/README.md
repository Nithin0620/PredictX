# @predictx/contracts

Solidity contracts for PredictX, built and tested with **Foundry**. Deployed to **Base Sepolia**
via the **thirdweb CLI** (see `docs/adr/0007-thirdweb-deployment.md`).

## Status

Phase 3: Foundry scaffold + toolchain verification. The only contract is `Placeholder.sol`
(replaced by `MockUSDC` / `MarketFactory` / `PredictionMarket` in Phase 4+).

## Prerequisites

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
# make sure ~/.foundry/bin is on PATH
```

## Install dependencies

Dependencies are cloned into `lib/` (git-ignored) and pinned:

```bash
make contracts-deps
# or, from this directory:
forge install foundry-rs/forge-std@v1.17.0 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.7.0 --no-git --shallow
```

## Commands

```bash
forge build          # compile
forge test           # run tests
FOUNDRY_PROFILE=ci forge test   # heavier fuzz/invariant settings
forge fmt --check    # format check
forge fmt            # format
forge snapshot       # gas snapshot
forge coverage --report summary
```

Or via the monorepo:

```bash
pnpm --filter @predictx/contracts build
pnpm --filter @predictx/contracts test
```

## Local chain

```bash
# terminal 1 — deterministic Anvil accounts on chain id 31337
make chain

# terminal 2 — deploy the placeholder
make deploy-local
```

Anvil's well-known account #0 is the default deployer for local runs
(`0xac09...ff80` — test key, never use on a real network). Override with `PRIVATE_KEY`.

## Layout

```
packages/contracts/
├── foundry.toml
├── src/          # Solidity sources
├── test/         # tests (+ test/utils shared helpers)
├── script/       # deploy scripts (Foundry Script)
└── lib/          # dependencies (git-ignored; restore with `make contracts-deps`)
```

## Remappings

- `@openzeppelin/contracts/` → `lib/openzeppelin-contracts/contracts/`
- `forge-std/` → `lib/forge-std/src/`
