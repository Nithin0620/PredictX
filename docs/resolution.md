# Resolution & Oracles

Phase 11 implements the two-track resolution model from ADR 0005:

1. **`OracleResolver`** — objective price-threshold markets backed by a Chainlink
   `AggregatorV3Interface` feed.
2. **`ManualResolver`** — owner-controlled fallback for markets without a reliable on-chain feed.

Both resolvers only **propose** an outcome. They never pay users directly; the existing
`Closed → Proposed → Finalized` lifecycle and dispute window still apply (ADR 0006).

## Deploy-first workflow

A resolver is configured for one feed/comparator/threshold (or one manual owner). Deploy it first,
then pass its address as `MarketConfig.resolver` when creating markets:

```text
feed (Chainlink AggregatorV3)
        │
        ▼
OracleResolver(feed, comparator, thresholdWad, maxStaleness)
        │  address(oracleResolver)
        ▼
MarketFactory.createMarket({ ..., resolver: address(oracleResolver) })
```

`OracleResolver.resolve(market)` and `ManualResolver.resolve(market, outcome)` both check
`market.resolver() == address(this)`, so one resolver cannot resolve another resolver's market.

## OracleResolver

### Configuration

| Parameter      | Meaning                                                                |
| -------------- | ---------------------------------------------------------------------- |
| `feed`         | Chainlink `AggregatorV3Interface` address.                             |
| `comparator`   | `GreaterThan`, `GreaterThanOrEqual`, `LessThan`, or `LessThanOrEqual`. |
| `thresholdWad` | Threshold normalized to 18 decimals (`1e18` scale).                    |
| `maxStaleness` | Maximum age of the latest round, in seconds. Must be non-zero.         |

The feed answer is normalized to WAD before comparison: feeds with fewer than 18 decimals are
multiplied up; feeds with more than 18 decimals are divided down. More than 36 decimals is rejected
as `InvalidDecimals`.

### Resolution flow

```text
resolve(market):
  require market.resolver() == address(this)
  status = market.status()
  if status == Active:
      market.close()                  // reverts before the deadline
  else if status != Closed:
      revert MarketNotClosed(status)
  read + validate latestRoundData()
  outcome = compare(normalized answer, thresholdWad)
  emit Resolved(...)
  market.proposeOutcome(outcome)
```

`resolve` is permissionless: anyone can trigger it after the deadline. The resolver contract is the
market's authorized proposer, so the market sees `msg.sender == resolver`.

### Feed validation

`latestRoundData()` is rejected when:

- `updatedAt == 0` or `block.timestamp - updatedAt > maxStaleness` → `StalePrice`
- `updatedAt > block.timestamp` or `startedAt > updatedAt` → `InvalidTimestamp`
- `answeredInRound < roundId` → `IncompleteRound`
- `answer <= 0` → `InvalidPrice`

These checks fail closed: a stale or malformed feed delays resolution instead of producing a bad
outcome. `latestAnswer()` exposes the same validation and returns `(normalizedAnswer, updatedAt)`
for monitoring and tests.

### Comparator semantics

| Comparator           | YES when                 |
| -------------------- | ------------------------ |
| `GreaterThan`        | `answer > thresholdWad`  |
| `GreaterThanOrEqual` | `answer >= thresholdWad` |
| `LessThan`           | `answer < thresholdWad`  |
| `LessThanOrEqual`    | `answer <= thresholdWad` |

Example: a market asking whether ETH/USD is at least `$4,000` at the deadline uses
`GreaterThanOrEqual` with `thresholdWad = 4_000e18`.

### Events and errors

| Event                                          | Meaning                                    |
| ---------------------------------------------- | ------------------------------------------ |
| `Resolved(market, answer, outcome, updatedAt)` | Feed answer accepted and outcome proposed. |

| Error                              | Cause                                             |
| ---------------------------------- | ------------------------------------------------- |
| `ZeroAddress`                      | Zero feed in the constructor.                     |
| `InvalidStaleness`                 | `maxStaleness == 0`.                              |
| `InvalidDecimals(uint8)`           | Feed decimals greater than 36.                    |
| `NotResolver(address)`             | Market points at a different resolver.            |
| `MarketNotClosed(status)`          | Market is `Created`, `Proposed`, or later.        |
| `StalePrice(updatedAt, max)`       | Zero, old, or otherwise unusable round timestamp. |
| `InvalidTimestamp(uint256)`        | Future `updatedAt` or `startedAt > updatedAt`.    |
| `IncompleteRound(round, answered)` | `answeredInRound < roundId`.                      |
| `InvalidPrice(int256)`             | Zero or negative answer.                          |

## ManualResolver

`ManualResolver` has an immutable `owner`. Only the owner may resolve, and only for markets whose
`resolver` is this contract.

```text
resolve(market, outcome):
  require msg.sender == owner
  require outcome == Yes or No
  require market.resolver() == address(this)
  if Active: market.close()          // reverts before the deadline
  else if not Closed: revert MarketNotClosed(status)
  emit Resolved(market, outcome, msg.sender)
  market.proposeOutcome(outcome)
```

`Unresolved` is rejected with `InvalidOutcome`. Non-owners get `NotOwner(caller)`. The owner can
resolve an already-`Closed` market without calling `close()` separately.

## State interactions

| Market state | `OracleResolver.resolve`             | `ManualResolver.resolve`             |
| ------------ | ------------------------------------ | ------------------------------------ |
| `Created`    | Reverts `MarketNotClosed(Created)`   | Reverts `MarketNotClosed(Created)`   |
| `Active`     | Closes, then proposes                | Closes, then proposes                |
| `Closed`     | Proposes                             | Proposes                             |
| `Proposed`   | Reverts `MarketNotClosed(Proposed)`  | Reverts `MarketNotClosed(Proposed)`  |
| `Disputed`   | Reverts `MarketNotClosed(Disputed)`  | Reverts `MarketNotClosed(Disputed)`  |
| `Finalized`  | Reverts `MarketNotClosed(Finalized)` | Reverts `MarketNotClosed(Finalized)` |

A `Created` market must be seeded before it can be resolved. Resolution before the deadline reverts
with `PredictionMarket.DeadlineNotReached`.

## Disputes

Resolution is only a proposal. The dispute window (`DISPUTE_WINDOW = 2 hours` on testnet) and
permissionless finalization are unchanged. Bonded disputes and arbiter finalization are Phase 12;
see `docs/adr/0006-dispute-and-trust.md`.

## Testing

- `test/OracleResolver.t.sol` — 25 tests: all comparators, threshold boundaries, close/propose flow,
  state guards, non-resolver, stale/zero/future timestamps, incomplete rounds, non-positive answers,
  decimal normalization (6/8/20), invalid decimals, and constructor guards.
- `test/ManualResolver.t.sol` — 12 tests: owner/non-owner, YES/NO, active/closed, unresolved,
  non-resolver, created/proposed/finalized guards, and zero-owner construction.
- `test/OracleResolverFork.t.sol` — optional Base Sepolia fork test against the live Chainlink
  ETH/USD feed. It skips unless both `BASE_SEPOLIA_RPC_URL` and `CHAINLINK_ETH_USD_FEED` are set.
- `test/utils/MockAggregatorV3.sol` — configurable feed mock used by unit tests.

Run the fork test with:

```bash
export BASE_SEPOLIA_RPC_URL="https://..."
export CHAINLINK_ETH_USD_FEED="0x..."
forge test --match-path 'test/OracleResolverFork.t.sol' -vv
```

## Trust assumptions

- The Chainlink feed is honest and timely; stale or malformed rounds cause a revert, not a wrong
  outcome.
- The `ManualResolver` owner is trusted for non-price markets.
- Anyone can trigger resolution, but cannot choose the outcome for a correctly configured resolver.
- Finalization still requires the dispute window, so a proposal is not immediately payable.

## Related

- `docs/adr/0005-oracle-resolution.md`, `docs/adr/0006-dispute-and-trust.md`
- `docs/amm.md`, `docs/state-machine.md`
- `packages/contracts/src/OracleResolver.sol`
- `packages/contracts/src/ManualResolver.sol`
- `packages/contracts/src/interfaces/IAggregatorV3.sol`
