# PredictX Lite — 4-Phase Build Plan

> **Active plan:** PredictX Lite. This replaces the original 20-phase full-protocol roadmap for the
> resume-focused build. The full contract implementation in this repo is an advanced reference.
> Product scope and architecture live in `PROJECT_PLAN.md`.

## Current status

- Phase 1 (contracts): complete.
- Phase 2 (tests/local deploy): complete — 39 Foundry tests, 100% source coverage, Anvil flow verified.
- Phase 3 (frontend): implemented — pages, thirdweb wallet, faucet, bet, resolve, claim; `next build` passes.
- Phase 4 (testnet/polish): pending — needs a funded Base Sepolia deployer key, RPC URL, and thirdweb client ID.

---

## 0. How to read this document

Each phase has the same shape:

- **Goal** — one sentence on why this phase exists.
- **Sub-phases** — numbered tasks completed in order.
- **Deliverables** — concrete artifacts.
- **Exit criteria** — what must be true before moving on.
- **Risks / notes** — what usually goes wrong.

Lite is a **4-week, part-time** build. Do not start Phase 2 until Phase 1 compiles and the basic
contract tests pass. Do not start Phase 3 until the contracts are deployed locally and tested.

---

## 1. Scope decisions — locked before Phase 1

| Feature                      | Decision  | Why                                          |
| ---------------------------- | --------- | -------------------------------------------- |
| Binary YES/NO markets        | **Keep**  | Core prediction-market behavior.             |
| Mock USDC collateral         | **Keep**  | Realistic token handling with test funds.    |
| Parimutuel pools             | **Keep**  | Simple payout math; no AMM required.         |
| Trusted resolver             | **Keep**  | Manual YES/NO resolution is enough for Lite. |
| Pro-rata winner claims       | **Keep**  | Demonstrates settlement and rounding.        |
| AMM / CPMM                   | **Cut**   | Too much math and testing for this scope.    |
| LP tokens / liquidity        | **Cut**   | Removes the hardest accounting surface.      |
| Protocol fees                | **Cut**   | No treasury or fee split.                    |
| ERC-20 YES/NO outcome tokens | **Cut**   | Internal stakes are enough for Lite.         |
| Chainlink oracle             | **Cut**   | Trusted resolver is acceptable on testnet.   |
| Disputes / arbitration       | **Cut**   | Deferred to the advanced version.            |
| Backend / indexer / database | **Cut**   | Direct RPC reads are enough.                 |
| Redis / BullMQ / workers     | **Cut**   | No background jobs.                          |
| SIWE / sessions              | **Cut**   | Wallet connection is the only identity.      |
| Upgradeable contracts        | **Cut**   | Immutable contracts are simpler.             |
| Mainnet / real money         | **Never** | Testnet and mock USDC only.                  |

**Golden rule:** if a feature is not needed for `create → bet → resolve → claim`, it is not in Lite.

---

## 2. Phase overview

| #   | Phase                     | Est. (part-time) | Depends on | Primary deliverable                             |
| --- | ------------------------- | ---------------- | ---------- | ----------------------------------------------- |
| 1   | Core contracts            | 5–7 days         | —          | `MockUSDC`, `PredictXMarket`, `PredictXFactory` |
| 2   | Tests and local deploy    | 3–5 days         | 1          | Foundry tests + Anvil deployment                |
| 3   | Frontend                  | 5–7 days         | 2          | Market list, detail, create, bet, claim         |
| 4   | Testnet deploy and polish | 3–5 days         | 3          | Base Sepolia deployment, README, demo           |

**Realistic total:** ~4 weeks part-time.

---

## 3. Detailed phases

---

### Phase 1 — Core Contracts

**Goal:** Implement the smallest complete market: create, bet, resolve, claim.

**Sub-phases**
1.1 Use `packages/contracts` as the Lite Foundry project. Remove full-protocol contracts and tests.
1.2 Add OpenZeppelin Contracts and configure `foundry.toml` for Solidity 0.8.24.
1.3 Implement `MockUSDC.sol` with 6 decimals, owner mint, and an optional faucet.
1.4 Define `Outcome { Unresolved, Yes, No }`.
1.5 Implement `PredictXMarket.sol` with immutable question, creator, resolver, collateral, and deadline.
1.6 Add `bet(Outcome side, uint256 amount)` with deadline, resolution, zero-amount, and side checks.
1.7 Add `resolve(Outcome result)` with resolver-only, deadline, unresolved, and double-resolve checks.
1.8 Add `claim()` with unresolved, already-claimed, no-winning-stake, and double-claim checks.
1.9 Implement the pro-rata payout formula and `SafeERC20` transfers.
1.10 Add events: `Bet`, `Resolved`, `Claimed`.
1.11 Implement `PredictXFactory.sol` with sequential IDs, market registry, and `getMarkets()`.
1.12 Emit `MarketCreated` with market id, address, creator, resolver, deadline, and question.
1.13 Add a deploy script for `MockUSDC` and `PredictXFactory`.
1.14 Write a short `README.md` with the trust model and known limitations.

**Contract API**

```solidity
function bet(Outcome side, uint256 amount) external;
function resolve(Outcome result) external;
function claim() external returns (uint256 payout);
```

```solidity
function createMarket(
    string calldata question,
    uint64 deadline,
    address resolver
) external returns (address market);
```

**Payout formula**

```text
totalPool = totalYes + totalNo
payout = winningStake * totalPool / winningPool
```

**Deliverables**

- `MockUSDC.sol`
- `PredictXMarket.sol`
- `PredictXFactory.sol`
- `script/DeployLite.s.sol`
- `contracts/README.md`

**Exit criteria**

- `forge build` passes.
- A local script can deploy USDC and the factory.
- A user can create a market, bet YES/NO, resolve, and claim in a Foundry test.
- No admin function can withdraw user funds.

**Risks**

- Scope creep into AMM, fees, or outcome tokens. Stop and re-read §1.
- Rounding mistakes. Use integer division and test the dust case.
- Resolver lock-in. Document that an inactive resolver can freeze funds.

---

### Phase 2 — Tests and Local Deployment

**Goal:** Prove the core flow and edge cases before building UI.

**Sub-phases**
2.1 Add a test fixture with `MockUSDC`, `PredictXFactory`, and 3–4 test users.
2.2 Test factory creation, sequential IDs, registry reads, and event emission.
2.3 Test invalid creation: zero resolver, past deadline, empty question.
2.4 Test YES and NO bets update the correct pools and stakes.
2.5 Test bet reverts: zero amount, `Unresolved`, after deadline, after resolution.
2.6 Test resolve reverts: non-resolver, before deadline, `Unresolved`, twice.
2.7 Test YES winner payout and NO winner payout.
2.8 Test loser cannot claim and double claim reverts.
2.9 Test claim before resolution reverts.
2.10 Test rounding dust remains in the contract and no user is overpaid.
2.11 Add one fuzz test: payout never exceeds the total pool.
2.12 Run `forge fmt`, `forge lint`, `forge test`, and `forge coverage`.
2.13 Deploy to local Anvil and run the full flow manually.

**Minimum test list**

1. Create market
2. Market count increments
3. Zero resolver reverts
4. Past deadline reverts
5. Empty question reverts
6. YES bet accounting
7. NO bet accounting
8. Zero bet reverts
9. Bet after deadline reverts
10. Bet after resolution reverts
11. Only resolver can resolve
12. Resolve before deadline reverts
13. Resolve twice reverts
14. Resolve `Unresolved` reverts
15. YES winner pro-rata payout
16. NO winner pro-rata payout
17. Loser cannot claim
18. Double claim reverts
19. Claim before resolution reverts
20. Rounding never overpays

**Deliverables**

- `test/PredictXMarket.t.sol`
- `test/PredictXFactory.t.sol`
- Passing local Anvil deployment
- Coverage summary in the README

**Exit criteria**

- At least 15 meaningful tests pass.
- Coverage is above 90% on Lite contracts.
- `forge fmt --check` and `forge lint` are clean.
- You can run the full flow on Anvil from the README.

**Risks**

- Testing only the happy path. Add the revert cases first.
- Overbuilding invariant tests. One fuzz test is enough for Lite.

---

### Phase 3 — Frontend

**Goal:** A small Next.js app that lets a wallet use the deployed contracts.

**Sub-phases**
3.1 Scaffold `packages/web` with Next.js App Router and TypeScript.
3.2 Add Tailwind CSS.
3.3 Add the thirdweb SDK and `ConnectButton` for wallet connection.
3.4 Configure Base Sepolia, the thirdweb client ID, and the contract addresses.
3.5 Generate or copy the contract ABIs into `lib/contracts.ts`.
3.6 Build the market list page.
3.7 Build the market detail page with pools, deadline, and user positions.
3.8 Build the create market page.
3.9 Add the bet form with USDC approval and `bet`.
3.10 Add the resolve button for the resolver.
3.11 Add the claim button for winners.
3.12 Add loading, pending, success, and error states.
3.13 Add a faucet button if `MockUSDC` exposes one.
3.14 Add a wrong-network warning.

**Pages**

| Route               | Contents                                            |
| ------------------- | --------------------------------------------------- |
| `/`                 | Market cards, pools, status, create button          |
| `/market/[address]` | Question, pools, deadline, bet form, resolve, claim |
| `/create`           | Question, deadline, resolver, submit                |

**Reads**

- `factory.marketCount()`
- `factory.markets(id)`
- `market.question()`
- `market.deadline()`
- `market.totalYes()`
- `market.totalNo()`
- `market.outcome()`
- `market.yesStake(user)`
- `market.noStake(user)`
- `market.claimed(user)`

Use `useReadContracts` to batch reads.

**Writes**

- `usdc.approve(market, amount)`
- `market.bet(Outcome.Yes or Outcome.No, amount)`
- `market.resolve(Outcome.Yes or Outcome.No)`
- `market.claim()`
- `factory.createMarket(question, deadline, resolver)`

**Deliverables**

- Working local frontend
- Three pages
- Wallet connection
- Bet, resolve, and claim flows
- Screenshots in the README

**Exit criteria**

- A user can connect a wallet on Base Sepolia.
- A user can create a market.
- A user can approve USDC and bet.
- The resolver can resolve after the deadline.
- A winner can claim.
- A loser sees that they have nothing to claim.

**Risks**

- Building a backend you do not need. Read directly from chain.
- Overdesigning the UI. Three pages are enough.
- Forgetting token approval. Handle approval before betting.

---

### Phase 4 — Testnet Deploy and Polish

**Goal:** Turn the local demo into a public, resume-ready project.

**Sub-phases**
4.1 Deploy `MockUSDC` to Base Sepolia.
4.2 Deploy `PredictXFactory` to Base Sepolia.
4.3 Verify both contracts on Basescan.
4.4 Put the addresses in the frontend environment.
4.5 Deploy the frontend to Vercel.
4.6 Create 3–5 demo markets.
4.7 Bet from 2–3 wallets.
4.8 Resolve at least one YES market and one NO market.
4.9 Claim from both winning wallets.
4.10 Write the README with architecture, setup, deployment, tests, and limitations.
4.11 Add screenshots and a 2-minute demo video.
4.12 Add a “What I would build next” section.
4.13 Run a final end-to-end check from a fresh wallet.

**README sections**

```text
What it does
Architecture
How resolution works
Trust model and limitations
Local setup
Deployment
Tests
Screenshots
Demo video
What I would build next
```

**Deliverables**

- Verified Base Sepolia contracts
- Deployed Vercel app
- 3–5 demo markets with real transactions
- README + screenshots + demo video
- Final end-to-end walkthrough

**Exit criteria**

- A stranger can open the app and use it without help.
- The contract addresses on Basescan match the frontend.
- At least one YES and one NO market are fully resolved and claimed.
- The README explains the trusted resolver and the lack of disputes.
- The demo video is under 3 minutes.

**Risks**

- Deployment/env mistakes. Test with a fresh wallet.
- Claiming the project is production-ready. Say “testnet MVP” clearly.
- Hiding limitations. Document them; it looks stronger.

---

## 4. Optional extensions (after Lite ships)

Only start these after the four phases are complete and the demo works:

1. **ERC-20 YES/NO outcome tokens** — more composable, more accounting.
2. **AMM pricing** — replace parimutuel pools with CPMM.
3. **LP tokens** — add liquidity and fees.
4. **Chainlink oracle** — automate objective resolution.
5. **Dispute window** — bonded challenge and arbiter.
6. **Backend indexer** — only if the market list becomes too large for direct RPC reads.
7. **Realtime updates** — only if the UI needs live pool changes.

Each extension should be its own branch and its own demo. Do not merge them into Lite just to make the
resume bullet longer.

---

## 5. Global Definition of Done

PredictX Lite is done when all of these are true:

- [ ] Contracts compile and deploy to Base Sepolia.
- [ ] Contracts are verified on Basescan.
- [ ] A user can create a market.
- [ ] A user can bet YES or NO with mock USDC.
- [ ] A resolver can resolve after the deadline.
- [ ] A winner can claim a pro-rata payout.
- [ ] A loser cannot claim.
- [ ] Double claims revert.
- [ ] Rounding never overpays.
- [ ] At least 15 Foundry tests pass.
- [ ] Frontend is deployed and works from a fresh wallet.
- [ ] README documents the trust model and limitations.
- [ ] Demo video and screenshots exist.

---

## 6. Working rules for every phase

1. **One phase = one PR.** Do not start the next phase until the exit criteria pass.
2. **Test before moving on.** Every phase ends with tests or a manual verification.
3. **Update `PROJECT_PLAN.md`** if a scope decision changes.
4. **Never add real money.** Base Sepolia + mock USDC only.
5. **Commit messages reference the phase:** `feat(phase-01): parimutuel market core`.
6. **Timebox.** If a phase overruns by more than 50%, cut scope and write down what was cut.
7. **Write the phase report before marking a phase done.**

---

## 7. Phase Completion Report

At the end of every phase, write `reports/lite-phase-XX.md` and append a short summary to
`reports/PROGRESS.md`.

**Required sections:**

| #   | Section                         | What to answer                                     |
| --- | ------------------------------- | -------------------------------------------------- |
| 1   | **Phase identity**              | Phase number + name; which part of Lite it covers. |
| 2   | **Scope planned**               | Sub-phases and deliverables from this file.        |
| 3   | **What was done**               | What shipped, mapped to sub-phase numbers.         |
| 4   | **What was skipped / deferred** | Anything cut and why.                              |
| 5   | **File changes**                | Added / modified files and lines changed.          |
| 6   | **Effects / impact**            | What now works, new risks, tech debt.              |
| 7   | **Verification**                | Tests, coverage, manual checks, deployment status. |
| 8   | **Progress**                    | Phases complete / 4 and rough % done.              |
| 9   | **Blockers & next**             | Open issues and the next phase.                    |

**Copy-paste template:**

```markdown
# Lite Phase XX — <Name>

## 1. Phase identity

- Phase: XX / 4
- Name: <phase name>
- Project part: <contracts / frontend / deployment>

## 2. Scope planned

- <sub-phase 1>
- <sub-phase 2>

## 3. What was done

- <what shipped, per sub-phase>

## 4. What was skipped / deferred

- <item> — reason: <why> (or "None")

## 5. File changes

| Type     | File           | Lines +/- |
| -------- | -------------- | --------- |
| Added    | `path/to/file` | +120      |
| Modified | `path/to/file` | +18 / -4  |

## 6. Effects / impact

- <what now works>
- <behavior changes>
- <new risks / tech debt>

## 7. Verification

- Tests: <pass/fail counts>
- Coverage: <X%>
- Manual: <what you clicked/ran>
- Deployment: <local / Base Sepolia / not deployed>

## 8. Progress

- Phases complete: XX / 4 (<%>)
- Overall estimate: <%> done
- Schedule: <on track / X days behind>
- Remaining: <summary>

## 9. Blockers & next

- Blockers: <none / list>
- Next phase: Phase YY — <name>
```

---

## 8. What to show in the demo

Keep the demo under 3 minutes:

1. Connect wallet.
2. Get mock USDC.
3. Create a market.
4. Bet YES from wallet A.
5. Bet NO from wallet B.
6. Show the pools.
7. Resolve as the resolver.
8. Claim from the winning wallet.
9. Show the losing wallet cannot claim.
10. Open Basescan and show the transactions.

That is the entire project story. Do not add features before this works.
