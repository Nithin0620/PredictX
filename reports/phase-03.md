# Phase 03 — Local Chain & Contract Scaffolding

## 1. Phase identity

- Phase: 03 / 20
- Name: Local Chain & Contract Scaffolding
- Project part: **Contracts / local development environment**

## 2. Scope planned

- 3.1 Install Foundry; create `packages/contracts` with `forge init`.
- 3.2 Add OpenZeppelin Contracts dependency.
- 3.3 Configure `foundry.toml` (solc 0.8.24+, optimizer, remappings, fuzz runs).
- 3.4 Set up Anvil + a deploy script + Makefile target to boot a local chain.
- 3.5 Optional: fork Base Sepolia (`anvil --fork-url`) for Chainlink feed testing.
- 3.6 Add `forge fmt` and `forge snapshot` baseline.
- 3.7 Create the directory layout: `src/`, `test/`, `script/`, `test/utils/`.
- 3.8 Add thirdweb CLI for testnet deployment; Foundry stays the source of truth for tests/local.

## 3. What was done

- 3.1 → Installed **Foundry v1.9.0** (`forge`, `cast`, `anvil`, `chisel`, `solar`) via `foundryup`;
  ran `forge init --no-git --use-parent-git --empty` in `packages/contracts` (installed forge-std).
- 3.2 → Installed **OpenZeppelin Contracts v5.7.0** into `lib/openzeppelin-contracts`.
- 3.3 → `foundry.toml`: solc **0.8.24**, `evm_version = cancun`, optimizer (200 runs), remappings for
  OZ + forge-std, fuzz (256) / invariant (64×32) defaults, a heavier `ci` profile, `rpc_endpoints`
  (`local`, `base_sepolia`), etherscan config, and `[fmt]` settings.
- 3.4 → `script/DeployLocal.s.sol` (forge-std `Script`, Anvil account #0 default, `PRIVATE_KEY`
  override) + Makefile targets `chain`, `chain-fork`, `deploy-local`, `contracts-deps`,
  `contracts-test`.
- 3.5 → Added `make chain-fork` (`anvil --fork-url $BASE_SEPOLIA_RPC_URL`). Not exercised yet because
  no Chainlink feed address is wired until Phase 11.
- 3.6 → `forge fmt` applied to all Solidity; `.gas-snapshot` baseline generated.
- 3.7 → Created `src/`, `test/`, `test/utils/`, `script/` with a skeleton contract, test, shared test
  constants, and deploy script.
- 3.8 → Added `docs/adr/0007-thirdweb-deployment.md` (thirdweb CLI for top-level contracts; Foundry
  for tests/local; factory deploys per-market contracts at runtime) and updated the ADR index.

## 4. What was skipped / deferred

- **Real contracts** (`MockUSDC`, `MarketFactory`, `PredictionMarket`, `AMM`, ...) — Phase 4+.
  Phase 3 ships only `Placeholder.sol` to prove the toolchain.
- **Chainlink fork test** (3.5) — target command added, but no feed address/round logic until Phase 11.
- **Actual thirdweb deployment** — needs real contracts (Phase 4) and a thirdweb client id; the
  decision + commands are documented in ADR 0007.
- **Contract dependencies are not committed** — `packages/contracts/lib/` is git-ignored. A fresh
  clone restores it with `make contracts-deps` (pinned: forge-std `v1.17.0`, OZ `v5.7.0`).
- **No Solidity linter beyond `forge fmt`** — Solhint/Slither are introduced in Phase 13.

## 5. File changes

> Phase 2 files are still untracked, so `git diff --stat` does not show these; counts are `wc -l`.
> `packages/contracts/lib/` (dependencies) is ignored and excluded.

| Type     | File                                                            | Lines     |
| -------- | --------------------------------------------------------------- | --------- |
| Added    | `packages/contracts/foundry.toml`                               | 43        |
| Added    | `packages/contracts/src/Placeholder.sol`                        | 24        |
| Added    | `packages/contracts/test/Placeholder.t.sol`                     | 33        |
| Added    | `packages/contracts/test/utils/TestConstants.sol`               | 13        |
| Added    | `packages/contracts/script/DeployLocal.s.sol`                   | 28        |
| Added    | `packages/contracts/.gas-snapshot`                              | 4         |
| Added    | `docs/adr/0007-thirdweb-deployment.md`                          | 88        |
| Modified | `packages/contracts/package.json` (placeholder → forge scripts) | 18        |
| Modified | `packages/contracts/turbo.json` (build outputs)                 | 11        |
| Modified | `packages/contracts/README.md` (setup + commands)               | 76        |
| Modified | `docs/adr/README.md` (ADR 0007 row)                             | 33        |
| Modified | `Makefile` (chain/deploy/deps targets)                          | 52        |
| Modified | `.github/workflows/ci.yml` (Foundry + sol lint)                 | 58        |
| Modified | `README.md` (Phase 3 status + Foundry steps)                    | 111       |
| Added    | `reports/phase-03.md`                                           | this file |
| Modified | `reports/PROGRESS.md`                                           | +2 / -1   |

- **Total touched (excluding ignored `lib/`):** ~601 lines across 15 files (+ this report).
- **Dependencies (ignored):** forge-std 1.17.0 + OpenZeppelin 5.7.0 clones under
  `packages/contracts/lib/`.

## 6. Effects / impact

- `packages/contracts` is now a real **Foundry project** that compiles against OpenZeppelin.
- `forge build`, `forge test`, `forge fmt --check`, and `forge snapshot` work.
- A **local Anvil chain** boots deterministically and the deploy script succeeds end to end.
- The monorepo pipeline now compiles and tests Solidity: `pnpm build` runs `forge build`,
  `pnpm test` runs `forge test`, `pnpm typecheck` runs `forge build`.
- CI installs Foundry + contract dependencies and checks Solidity formatting.
- Remappings are set, so Phase 4 can import `@openzeppelin/contracts/...` immediately.
- New operational requirement: `~/.foundry/bin` must be on `PATH`, and fresh clones must run
  `make contracts-deps`.

## 7. Verification

- `forge --version` → **1.9.0**; `anvil --version` → **1.9.0**.
- `forge build` → ✅ compiled **26 files** with Solc **0.8.24**.
- `forge test -vv` → ✅ **4/4 passed** (`test_Metadata`, `test_Ping`, `test_OwnerIsDeployer`,
  `test_ConstantsMatchSharedConfig`).
- `forge fmt --check` → ✅ clean.
- `forge snapshot` → ✅ baseline written to `.gas-snapshot`.
- Anvil smoke test → ✅ `anvil --chain-id 31337` + `forge script ... --broadcast` deployed
  `Placeholder` at `0x5FbDB2315678afecb367f032d93F642f64180aa3`, owner
  `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`.
- Root pipeline → ✅ `pnpm lint`, `pnpm format:check`, `pnpm typecheck`, `pnpm build`, `pnpm test`.
- Total tests now: **11** (5 shared + 2 backend + 4 contracts).

## 8. Progress

- Phases complete: **3 / 20 (15%)**
- Overall estimate: **~14%** (toolchain + contracts scaffold; no real market logic yet).
- Schedule: **on track** (Phase 3 scoped at 3–4 days).
- Remaining: Phase 4 (USDC + factory + registry) through Phase 20 (deploy/launch).

## 9. Blockers & next

- **Operational:** contract deps are git-ignored; run `make contracts-deps` on a fresh clone/CI
  (CI already does). Foundry is installed at `~/.foundry/bin` (add to `PATH`).
- No blocking bugs. Repo changes remain **uncommitted** (per project rule).
- Next phase: **Phase 4 — Collateral, Factory & Market Registry**.
