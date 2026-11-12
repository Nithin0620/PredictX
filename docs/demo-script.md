# PredictX — Demo Script

The exact end-to-end story to show at the end of the project (and to test after Phase 19/20).
Target length: **3 minutes**. Everything runs on **Base Sepolia** with **test USDC**.

## Cast / roles

| Role                          | Who                   | Needs                                           |
| ----------------------------- | --------------------- | ----------------------------------------------- |
| Trader                        | A fresh wallet        | Base Sepolia ETH for gas, test USDC from faucet |
| Liquidity provider (optional) | Same or second wallet | Test USDC                                       |
| Resolver                      | Admin/resolver wallet | Resolver role, bond                             |
| Arbiter (optional)            | Admin wallet          | Arbiter role                                    |

## Pre-demo checklist

- [ ] Contracts deployed to Base Sepolia and verified on Basescan.
- [ ] Backend + indexer + workers running; indexer caught up (lag ≈ 0).
- [ ] Frontend deployed; wrong-network guard works.
- [ ] Faucet funded with mock USDC.
- [ ] At least one **price-threshold market** seeded with liquidity, deadline already near/past
      for the resolution part (or use a "demo market" with a short deadline).
- [ ] Realtime connection working; probability chart updates.

## Script

### 1. Onboard (20s)

1. Open the app URL.
2. Click **Connect** (thirdweb `ConnectButton`) → connect Base Sepolia wallet.
3. Sign the **SIWE** message → session created; address appears in the nav.
4. Go to **Faucet** → mint test USDC → balance updates.

> Say: "Wallet is identity — sign-in with Ethereum, no passwords."

### 2. Discover a market (20s)

1. Open **Markets**.
2. Point out cards: question, **implied probability bar**, volume, deadline, status.
3. Open _"Will ETH/USD be ≥ $5,000 on …?"_
4. Show the market detail: probability chart, resolution criteria (feed + comparator + threshold +
   timestamp), liquidity, and the trade form.

> Say: "The price _is_ the crowd's probability estimate."

### 3. Trade (30s)

1. Enter an amount of USDC, choose **YES**.
2. Show the live quote (expected shares, price impact, fee, slippage bound).
3. **Approve USDC** (if needed) → **Buy YES**.
4. Confirm the transaction in the wallet.
5. Watch the **probability bar move up** in real time (WebSocket) and the portfolio update.

> Say: "This is a CPMM — buying YES raises its price and the implied probability."

### 4. (Optional) Provide liquidity (20s)

1. Open the **Liquidity** tab on the market.
2. Add USDC → receive LP tokens.
3. Show that trades now accrue fees to LPs.

### 5. Resolve (40s)

1. Advance to a market whose deadline has passed (or use the seeded demo market).
2. Show status → **Closed**.
3. Resolver clicks **Propose outcome** (or show it auto-resolved from the Chainlink feed).
4. Show the **dispute window** countdown and the evidence/criteria.
5. (Optional) Show a **dispute** with a bond, then arbiter finalization.
6. After the window, click **Finalize** → status **Finalized**.

> Say: "Resolution is oracle-driven; the dispute window prevents instant bad payouts."

### 6. Claim (25s)

1. Go to **Portfolio** → show **Claimable**.
2. Click **Redeem** → winning shares burn for 1 USDC each.
3. Show the updated USDC balance and the payout transaction.
4. Open **Basescan** and show the trade + redeem transactions.

> Say: "Winning shares redeem 1:1 for USDC; the contract prevents double claims."

### 7. Wrap-up (15s)

1. Show the **Analytics** page (volume, probability history, top traders).
2. Show the architecture slide: chain = authority, backend = index, frontend = UX.

## Fallbacks (if something fails live)

| Failure                      | Fallback                                                                |
| ---------------------------- | ----------------------------------------------------------------------- |
| Testnet congestion / slow tx | Pre-recorded short clip of the trade + claim.                           |
| Chainlink feed stale         | Use the **manual resolver** path to propose the outcome.                |
| Indexer lag                  | Show the data still loads; explain it catches up via cursor + backfill. |
| Wallet popup issue           | Use a pre-funded demo wallet imported into the browser.                 |

## What the demo must prove

- [ ] Real on-chain trades (not mocked).
- [ ] Probability updates in real time.
- [ ] Oracle/feed-based resolution (not an admin toggle).
- [ ] A dispute window exists before payout.
- [ ] Claim works and is verifiable on Basescan.
- [ ] The backend is indexing real events, not hardcoded data.
