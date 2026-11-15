# PredictX Lite — Project Plan (Student Resume Version)

> **Active plan:** PredictX Lite. The original full protocol is intentionally deferred; the
> existing full contract implementation remains in this repo as an advanced reference.
> Execution roadmap: `PHASES.md` (4 phases).
>
> **Status:** contracts, tests, local deploy, and frontend are implemented. Base Sepolia deployment
> is pending funded deployer credentials and a thirdweb client ID.

---

## 1. What is PredictX Lite?

**PredictX Lite** is a small, end-to-end **parimutuel binary prediction market** on **Base Sepolia**
(testnet only). Users:

1. Create YES/NO markets on objective future events.
2. Bet mock USDC on YES or NO.
3. Wait for the deadline.
4. Let a trusted resolver choose YES or NO.
5. Winners claim a pro-rata share of the total pool.

**One-line pitch:** _A student-sized prediction market with USDC betting, manual resolution,
pro-rata payouts, and a Next.js frontend — deployed on Base Sepolia._

This is deliberately **not** a full DeFi protocol. It is a focused portfolio project that can be
built, tested, deployed, and demoed in about four weeks.

---

## 2. Why this version

- It keeps the most interesting part of PredictX: **on-chain money and market settlement**.
- It removes the parts that dominate build time without adding much resume value for a student:
  AMM math, LP accounting, oracle integration, disputes, backend indexing, and queues.
- It is small enough to finish, explain, and defend in an interview.
- It still demonstrates Solidity, ERC-20 handling, access control, state transitions, rounding,
  Foundry testing, deployment, and frontend integration.

**Rule:** if a feature is not required for the loop
`create → bet → resolve → claim`, it is not in Lite.

---

## 3. Scope

### 3.1 In scope

| Area       | Included                                                        |
| ---------- | --------------------------------------------------------------- |
| Markets    | Binary YES/NO, permissionless creation                          |
| Collateral | Mock USDC, 6 decimals                                           |
| Betting    | One or more bets per user on YES or NO                          |
| Pricing    | Parimutuel pools, no AMM                                        |
| Resolution | Trusted resolver address, manual YES/NO choice                  |
| Settlement | Winners split the total pool pro-rata; losers receive nothing   |
| Frontend   | Market list, market detail, create market, bet, resolve, claim  |
| Chain      | Base Sepolia only                                               |
| Ops        | Foundry tests, verified deploy, README, screenshots, demo video |

### 3.2 Explicitly out of scope

| Excluded                        | Reason                                            |
| ------------------------------- | ------------------------------------------------- |
| AMM / CPMM pricing              | Parimutuel pools are enough for the Lite story.   |
| LP tokens / liquidity provision | Removes the hardest accounting surface.           |
| Protocol fees                   | No treasury or fee-split complexity.              |
| Chainlink oracle                | Trusted resolver is acceptable for a student MVP. |
| Disputes / bonded arbitration   | Deferred to the advanced version.                 |
| Backend / indexer / database    | Direct RPC reads are enough for small markets.    |
| Redis / BullMQ / workers        | No background jobs needed.                        |
| SIWE auth / sessions            | Wallet connection is the only identity.           |
| Upgradeable contracts           | Immutable contracts are simpler and safer here.   |
| Mainnet / real money            | Testnet and mock USDC only.                       |
| Multi-outcome markets           | Binary only.                                      |

**Known Lite limitations (document these honestly):**

- The resolver is trusted. If the resolver never acts, funds remain locked.
- There is no dispute path. A wrong resolution cannot be challenged on-chain.
- Rounding dust from pro-rata payouts stays in the market contract.
- Losing stakes are not refunded; they fund the winners.
- The contract is testnet-only and not audited.

---

## 4. System architecture

```text
┌──────────────────────────────────────────────┐
│              Browser (Next.js)               │
│  thirdweb SDK · wallet connect · Tailwind    │
│  Markets · Create · Bet · Resolve · Claim    │
└───────────────┬──────────────────────────────┘
                │ direct RPC reads + wallet txs
                ▼
┌──────────────────────────────────────────────┐
│            Base Sepolia (EVM)                │
│  MockUSDC                                    │
│  PredictXFactory ──deploys──► PredictXMarket │
│  PredictXMarket: pools, resolution, claims   │
└──────────────────────────────────────────────┘
```

There is **no backend**. The chain is the source of truth. The frontend reads factory and market
state directly from Base Sepolia and sends wallet transactions.

**Trust model:** the resolver is trusted to report the correct outcome. Users trust the contract to
hold funds and pay winners according to the parimutuel formula.

---

## 5. Technology stack

| Layer          | Choice                                       | Notes                                |
| -------------- | -------------------------------------------- | ------------------------------------ |
| Chain          | **Base Sepolia**                             | Testnet only                         |
| Contracts      | **Solidity 0.8.24 + Foundry**                | Unit tests and fuzz tests            |
| Contract libs  | **OpenZeppelin Contracts**                   | ERC-20, SafeERC20, ReentrancyGuard   |
| Collateral     | **MockUSDC**                                 | 6 decimals, owner mint / faucet      |
| Frontend       | **Next.js App Router + TypeScript**          | No backend                           |
| Web3 client    | **thirdweb SDK**                             | Wallet, reads, and writes            |
| Wallet UI      | **thirdweb `ConnectButton`**                 | Wallet connection                    |
| Styling        | **Tailwind CSS**                             | Keep the UI small                    |
| Deployment     | **Foundry script + Basescan verification**   | Contracts                            |
| Web deployment | **Vercel**                                   | Frontend                             |
| Repo           | **Existing workspace, contracts + web only** | Keep Lite small; no backend packages |

---

## 6. Repository layout

```text
PredictX/
├── packages/
│   ├── contracts/
│   │   ├── foundry.toml
│   │   ├── remappings.txt
│   │   ├── src/
│   │   │   ├── MockUSDC.sol
│   │   │   ├── PredictXMarket.sol
│   │   │   └── PredictXFactory.sol
│   │   ├── test/
│   │   │   ├── PredictXMarket.t.sol
│   │   │   └── PredictXFactory.t.sol
│   │   └── script/
│   │       └── DeployLite.s.sol
│   └── web/
│       ├── app/
│       │   ├── page.tsx
│       │   ├── create/page.tsx
│       │   └── market/[address]/page.tsx
│       ├── components/
│       │   ├── MarketCard.tsx
│       │   ├── BetForm.tsx
│       │   └── ClaimButton.tsx
│       ├── lib/
│       │   ├── contracts.ts
│       │   └── thirdweb.ts
│       └── .env.local.example
├── PHASES.md
├── PROJECT_PLAN.md
└── README.md
```

The full AMM/oracle/backend version is preserved on `master`. Do not mix those contracts into the
Lite branch.

---

## 7. Smart contract specifications

### 7.1 `MockUSDC.sol`

- ERC-20 with 6 decimals.
- Owner can mint for tests and demos.
- Optional public faucet with a cooldown.
- Never use as a real stablecoin.

### 7.2 `PredictXMarket.sol`

One contract per market.

**State**

```solidity
enum Outcome {
    Unresolved,
    Yes,
    No
}

IERC20 public immutable collateral;
address public immutable creator;
address public immutable resolver;
uint64 public immutable deadline;
string public question;

uint256 public totalYes;
uint256 public totalNo;
Outcome public outcome;

mapping(address => uint256) public yesStake;
mapping(address => uint256) public noStake;
mapping(address => bool) public claimed;
```

**Functions**

```solidity
function bet(Outcome side, uint256 amount) external;
function resolve(Outcome result) external;
function claim() external returns (uint256 payout);
```

**Rules**

- `bet` reverts on zero amount, `Unresolved`, after deadline, or after resolution.
- `bet` pulls USDC with `SafeERC20` and updates the correct pool.
- `resolve` is resolver-only, allowed at or after the deadline, and cannot run twice.
- `resolve` rejects `Unresolved`.
- `claim` is allowed only after resolution.
- Losing users cannot claim.
- A user can claim only once.
- No admin function can withdraw user funds.

**Events**

```solidity
event Bet(address indexed user, Outcome indexed side, uint256 amount);
event Resolved(Outcome indexed outcome, address indexed resolver);
event Claimed(address indexed user, uint256 payout);
```

### 7.3 `PredictXFactory.sol`

- Stores the mock USDC address.
- Deploys a new `PredictXMarket` per market.
- Assigns sequential market IDs.
- Stores `marketId → market address`.
- Emits `MarketCreated`.
- Exposes `getMarkets()` for the frontend.

```solidity
function createMarket(
    string calldata question,
    uint64 deadline,
    address resolver
) external returns (address market);

function getMarkets() external view returns (address[] memory);
```

### 7.4 Deployment model

- One factory for all markets.
- One market contract per question.
- No clones or proxies. Simplicity over gas optimization.
- Factory has no owner privileges over market funds.

---

## 8. Core math

### 8.1 Parimutuel pools

```text
totalPool = totalYes + totalNo
```

All bets are held by the market contract. There is no pricing curve.

### 8.2 Payout

```text
if outcome == Yes:
    payout = yesStake[user] * totalPool / totalYes

if outcome == No:
    payout = noStake[user] * totalPool / totalNo
```

- Winners receive a pro-rata share of the entire pool.
- Losers receive nothing.
- The more the winning side is outnumbered, the larger the winner payout.

### 8.3 Rounding

Solidity integer division rounds down. That means:

```text
sum(all payouts) <= totalPool
```

The difference is **dust** that remains in the market contract. This is acceptable for Lite and must
be documented in the README.

### 8.4 Implied probability display

For UI only:

```text
pYes ≈ totalYes / (totalYes + totalNo)
pNo  ≈ totalNo  / (totalYes + totalNo)
```

This is a pool-implied estimate, not a trade price.

---

## 9. Resolution design

```text
deadline reached
  → resolver calls resolve(Yes or No)
  → outcome is stored
  → winners call claim()
```

- The resolver is an address chosen when the market is created.
- For the demo, the market creator can be the resolver.
- Resolution is allowed at or after the deadline.
- There is no close transaction; the deadline is enforced by `bet`.
- There is no dispute window in Lite.
- If the resolver never resolves, the market stays unresolved and funds stay locked.

This is a deliberate trust tradeoff. Document it clearly and mention oracle/dispute systems as future
work.

---

## 10. Frontend design

### Routes

| Route               | Purpose                                   |
| ------------------- | ----------------------------------------- |
| `/`                 | List markets, show pools and status       |
| `/market/[address]` | Market detail, bet YES/NO, resolve, claim |
| `/create`           | Create a market                           |

### Market list

- Read `factory.marketCount()`.
- Read each `factory.markets(id)`.
- Use `useReadContracts` to batch market details.
- No database and no indexer.

### Market detail

Show:

- question
- deadline
- total YES pool
- total NO pool
- implied percentages
- user’s YES/NO stakes
- bet form
- resolve button if the connected wallet is the resolver
- claim button if resolved and the user has a winning stake

### Create market

Inputs:

- question
- deadline
- resolver address

Submit `factory.createMarket(...)`.

### UX requirements

- Wrong network prompt.
- Transaction pending / success / error states.
- Disable bet buttons after deadline.
- Show “You lose this stake if the other side wins.”
- Show the resolver address and the trust warning.
- Show claimable amount before claiming.

---

## 11. Security and correctness

- Use `SafeERC20` for all token transfers.
- Use `ReentrancyGuard` on `bet` and `claim`.
- Use custom errors with clear names.
- Use checks-effects-interactions ordering.
- No admin withdrawal path.
- No upgradeability.
- No `tx.origin`.
- No unbounded loops in state-changing functions.
- Validate zero addresses, zero amounts, empty questions, and past deadlines.
- Test rounding and double-claim behavior.
- Test with multiple users and both outcomes.
- Document that the contract is unaudited and testnet-only.

---

## 12. Testing strategy

| Layer                  | Tool       | Target                                      |
| ---------------------- | ---------- | ------------------------------------------- |
| Market unit tests      | Foundry    | create, bet, resolve, claim, reverts        |
| Factory tests          | Foundry    | IDs, registry, invalid inputs               |
| Payout math            | Foundry    | YES winner, NO winner, rounding, no overpay |
| Access control         | Foundry    | resolver-only resolution                    |
| Fuzz                   | Foundry    | payout never exceeds pool                   |
| Frontend smoke test    | Manual     | connect → bet → resolve → claim             |
| Optional frontend test | Playwright | one happy-path flow                         |

Target: **15–25 Foundry tests** and **>90% coverage on Lite contracts**.

---

## 13. Deployment

1. Deploy `MockUSDC` to Base Sepolia.
2. Deploy `PredictXFactory` with the USDC address.
3. Verify both contracts on Basescan.
4. Set frontend environment variables:

```bash
NEXT_PUBLIC_THIRDWEB_CLIENT_ID=...
NEXT_PUBLIC_FACTORY_ADDRESS=0x...
NEXT_PUBLIC_USDC_ADDRESS=0x...
```

5. Create 3–5 demo markets.
6. Bet from 2–3 wallets.
7. Resolve one market YES and one market NO.
8. Claim from both winning wallets.
9. Record a 2-minute demo.

---

## 14. Roadmap mapping

The 4 phases in `PHASES.md` map to this plan as:

| Plan area                  | Phase |
| -------------------------- | ----- |
| Core contracts             | 1     |
| Tests and local deployment | 2     |
| Frontend                   | 3     |
| Testnet deploy and polish  | 4     |

---

## 15. Success criteria

A reviewer should be able to, unaided:

1. Open the deployed app and connect a Base Sepolia wallet.
2. Get mock USDC from the faucet.
3. Create a market with a question, deadline, and resolver.
4. Bet YES or NO.
5. See the pools update.
6. Resolve a matured market as the resolver.
7. Claim winnings as a winner.
8. See the losing side receive nothing.
9. Inspect the transactions on Basescan.

If all nine work smoothly, PredictX Lite is a success.

---

## 16. Resume / interview framing

- **"Built and deployed PredictX Lite, a parimutuel binary prediction market on Base Sepolia, with
  USDC betting, manual resolution, and pro-rata winner claims."**
- **"Wrote a Foundry test suite covering market creation, betting, resolution, double-claim
  prevention, access control, and payout rounding."**
- **"Built a Next.js + thirdweb frontend that reads markets directly from chain and supports
  wallet-based betting, resolution, and claiming without a backend."**
- **"Documented the trust model and known limitations of a trusted-resolver prediction market."**

Interview talking points:

- Why parimutuel instead of an AMM for a first version.
- Why the contract holds funds and why there is no admin withdrawal.
- How rounding works and why dust remains.
- Why a trusted resolver is acceptable for a testnet MVP.
- What you would add next: outcome tokens, AMM, oracle, disputes, indexer.

---

## 17. Relationship to full PredictX

The full PredictX code in this repo is the **advanced reference**:

- AMM pricing
- LP tokens
- outcome tokens
- oracle resolution
- dispute/finalization flow
- backend indexer and workers
- full web app

Do not try to strip the full contracts in place. Build Lite as a separate, clean project. If Lite
ships successfully, the full version becomes a “future work / advanced version” section in your
portfolio.

---

## 18. Glossary

| Term             | Meaning                                                    |
| ---------------- | ---------------------------------------------------------- |
| Parimutuel       | Winners split the total pool proportional to their stake   |
| Collateral       | Mock USDC locked in the market                             |
| Resolver         | Address allowed to choose the final outcome                |
| Outcome          | `Unresolved`, `Yes`, or `No`                               |
| Claim            | Winner withdraws their pro-rata payout                     |
| Rounding dust    | Tiny remainder left in the contract after integer division |
| Trusted resolver | A known address, not a decentralized oracle                |
| Testnet-only     | No real money; Base Sepolia and mock USDC only             |
