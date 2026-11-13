# @predictx/contracts

Solidity contracts for PredictX, built and tested with **Foundry**. Deployed to **Base Sepolia**
via the **thirdweb CLI** (see `docs/adr/0007-thirdweb-deployment.md`).

## Status

Phase 7: `MockUSDC` (6-decimal testnet faucet), `MarketFactory` (validated, permissionless
creation with a per-creator cooldown, sequential ids, enumerable registry), `PredictionMarket` with
the lifecycle state machine (`Created → Active → Closed → Proposed → Finalized`), per-market
`OutcomeToken` YES/NO ERC-20s, 1:1 collateral `split`/`merge`, and a constant-product AMM
(`seedLiquidity`, `buy`, `sell`, `quoteBuy`, `quoteSell`, `getReserves`, `priceYes`). Fees stay in
the pool in Phase 7; slippage/deadline, LP tokens, and fee routing arrive in Phases 8–9. Redemption
is Phase 10; the dispute path is Phase 12. See `docs/amm.md` and `docs/state-machine.md`.

99 contract tests cover the factory, tokens, collateral, lifecycle matrix, AMM quotes/trades, and
two stateful invariants (collateral backing + CPMM `k`/reserve sync).

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

# terminal 2 — deploy MockUSDC + MarketFactory
make deploy-local
```

Anvil's well-known account #0 is the default deployer for local runs
(`0xac09...ff80` — test key, never use on a real network). Override with `PRIVATE_KEY`.

## Layout

```
packages/contracts/
├── foundry.toml
├── src/          # Solidity sources
├── test/         # tests (+ test/utils helpers, test/invariant handlers)
├── script/       # deploy scripts (Foundry Script)
└── lib/          # dependencies (git-ignored; restore with `make contracts-deps`)
```

## Remappings

- `@openzeppelin/contracts/` → `lib/openzeppelin-contracts/contracts/`
- `forge-std/` → `lib/forge-std/src/`
