# Gwent Card Game - Complete Project Documentation

## Project Overview
An on-chain Gwent card game built on Solidity using Foundry. Players own cards as NFTs (ERC1155), can open packs via Chainlink VRF, and battle in a 3-round arena system with stakes.

**All code is on-chain. No off-chain components.**

---

## Project Structure

```
src/
├── GwentCardToken.sol      # ERC1155 token + game currency + WETH
├── GwentSystem.sol         # Pack opening with Chainlink VRF
├── CardRegistryPure.sol    # 144 cards database (pure library)
├── CardGameLogic.sol       # Game scoring (EMPTY - to be built)
├── GwentArena.sol          # Battle arena with commit-reveal
└── GwentCard_test_code.sol

interfaces/
└── IGwentCardToken.sol    # Interface for GwentCardToken

test/
└── VRFTest_Local.t.sol   # VRF testing

script/
└── Deploy.s.sol           # Deployment script

docs/
└── GAME_DESIGN.md        # This file
```

---

## Contract 1: GwentCardToken.sol

### Purpose
ERC1155 token that handles:
- Game currency (ID 0)
- NFT cards (IDs 1-144)

### Token IDs
| ID | Type |
|----|------|
| 0 | Game Currency |
| 1-144 | Cards |

### Key Variables
```solidity
uint256 public constant GAME_CURRENCY_ID = 0;
uint256 public constant CARD_ID_START = 1;
uint256 public tokenPrice = 5e15; // 0.000005 WETH per token
IERC20 public wethToken;
address public treasuryWallet;
```

### Roles
- `MINTER_ROLE`: Can mint cards and currency
- `BURNER_ROLE`: Can burn currency (for pack purchases)
- `DEFAULT_ADMIN_ROLE`: Owner

### Key Functions
| Function | Description | Access |
|----------|-------------|--------|
| `buyTokens(tokenAmount, maxWethToPay)` | Buy tokens with WETH | Anyone |
| `mint(to, cardId, amount)` | Mint cards | MINTER_ROLE |
| `mintGameCurrency(to, amount)` | Mint currency | MINTER_ROLE |
| `burnGameCurrency(from, amount)` | Burn currency | BURNER_ROLE |
| `airdropCurrency(recipients[], amount)` | Batch airdrop (max 50) | ADMIN |
| `airdropCurrencySingle(recipient, amount)` | Single airdrop | ADMIN |
| `setWethToken(address)` | Set WETH token | ADMIN |
| `setTokenPrice(uint256)` | Set token price | ADMIN |
| `setTreasuryWallet(address)` | Set treasury | ADMIN |

### Pricing
- Token: 0.000005 WETH (~1 WETH = $2000)
- Pack: 100 tokens = 0.0005 WETH ≈ $1

---

## Contract 2: GwentSystem.sol

### Purpose
Handles pack opening using Chainlink VRF for random card generation.

### Constructor Parameters
```solidity
constructor(
    uint256 subscriptionId,    // Chainlink VRF subscription
    bytes32 gasLane,           // VRF key hash
    uint32 callbackGasLimit,   // VRF callback gas limit
    address vrfCoordinatorV2,  // VRF coordinator address
    address cardTokenAddress   // GwentCardToken address
)
```

### Pack Types
| Function | Cards in Pack |
|----------|---------------|
| `openNorthenRealmsPack()` | 6 cards |
| `openScoialTaelPack()` | 5 cards |
| `openNilfgaardPack()` | 3 cards |
| `openMonstersPack()` | 5 cards |
| `openSkelligePack()` | 4 cards |

### Rarity Distribution
- Common: 50%
- Uncommon: 30%
- Rare: 15%
- Rare+: 4%
- Hero: 1%

### Flow
1. User calls `openXXXPack()`
2. 100 tokens burned via `burnGameCurrency()`
3. Chainlink VRF requested for random cards
4. Random words fulfilled → cards stored
5. User calls `claimRolls(requestId)` → cards minted to wallet

### Key Storage
```solidity
mapping(uint256 => address) private s_requestOwner;    // requestId → user
mapping(uint256 => uint256[]) private s_packCards;     // requestId → cards[]
mapping(uint256 => PackType) private s_packTypes;     // requestId → pack type
```

---

## Contract 3: CardRegistryPure.sol

### Purpose
Pure library containing card database. No storage, just getter functions.

### Card Count: 144 cards

| Faction | Cards | IDs |
|---------|-------|-----|
| Northern Realms | 25 | 1-25 |
| Scoia'tael | 23 | 26-48 |
| Nilfgaard | 29 | 49-77 |
| Monsters | 35 | 78-112 |
| Skellige | 23 | 113-135 |
| Special/Weather | 9 | 136-144 |

### Card Structure
```solidity
struct Card {
    uint8 power;
    uint8 berserker_power;
    Ability ability;
    Ability special_ability;
    UnitType unitType;
    Faction faction;
}
```

### Enums
```solidity
enum Ability {
    None, Berserker, Transform_After_Death, Commander_horn, Decoy,
    Hero, Medic, Morale_Boost, Mardroeme, Muster, Summon,
    Spy, Tight_Bond, Scorch, weather_sets_close_1, weather_clears,
    weather_sets_range_1, weather_reduces_close_range_1, weather_sets_sieg_1
}

enum UnitType {
    Close_Combat, Ranged, Siege, Agile, Weather, Special
}

enum Faction {
    Northern, Nilfgaard, Monster, Scoiatael, Skellige, Neutral
}
```

### Key Functions
- `getCard(id)` → returns Card struct
- `getMusterGroup(id)` → returns muster group ID

---

## Contract 4: CardGameLogic.sol

### Status: EMPTY

This is a placeholder. Current scoring just counts cards:
```solidity
function _calculateScore(uint256[] memory cards) internal pure returns (uint256) {
    return cards.length; // Just counts cards!
}
```

**Needs to be implemented:**
- Power calculation from CardRegistryPure
- Ability processing (Tight_Bond, Muster, Commander_horn, etc.)
- Weather effects
- Spy, Medic, Decoy mechanics

---

## Contract 5: GwentArena.sol

### Purpose
Battle arena with commit-reveal system for hidden plays.

### Enums
```solidity
enum Faction {
    Northern, Nilfgaard, Monster, Scoiatael, Skellige
}

enum Phase {
    WaitingForCommit,
    WaitingForReveal,
    WaitingForResolution,
    Completed
}

enum MatchResult {
    Pending, Player1Wins, Player2Wins, Draw,
    Player1Timeout, Player2Timeout, BothTimeout
}
```

### Structs

#### ArenaEntry
```solidity
struct ArenaEntry {
    address player;
    Faction faction;
    uint256[] cardIds;     // Public deck card IDs
    uint256[] cardAmounts; // Public deck card quantities
    uint256 stakeAmount;   // Immutable standard entryFee
    uint256 enterTime;
    uint256 waitReward;
    bool isMatched;
    uint256[] matchIds;    // Match history
}
```

#### Match
```solidity
struct Match {
    address player1;
    address player2;
    Faction faction1;
    Faction faction2;
    // (Deck Arrays are abstracted out as Storage Pointers via ArenaEntry)
    // Commit phase - hidden hashes
    bytes32 player1R1Hash;
    bytes32 player1R2Hash;
    bytes32 player1R3Hash;
    bytes32 player2R1Hash;
    bytes32 player2R2Hash;
    bytes32 player2R3Hash;
    // Reveal phase - actual cards (ERC1155 style ID+Amount pairs)
    uint256[] player1R1Ids;
    uint256[] player1R1Amounts;
    uint256[] player1R2Ids;
    uint256[] player1R2Amounts;
    uint256[] player1R3Ids;
    uint256[] player1R3Amounts;
    uint256[] player2R1Ids;
    uint256[] player2R1Amounts;
    uint256[] player2R2Ids;
    uint256[] player2R2Amounts;
    uint256[] player2R3Ids;
    uint256[] player2R3Amounts;
    uint256 stakeAmount;
    uint256 poolAmount;
    Phase phase;
    uint256 commitDeadline;
    uint256 revealDeadline;
    MatchResult result;
}
```

### Key Variables
```solidity
uint256 public entryFee = 50 ether;
uint256 public waitRewardPerBlock = 0.001 ether;
uint256 public commitTimeout = 3 days;
uint256 public revealTimeout = 1 days;
uint256 public callerRewardPercent = 1;
uint256 public constant MIN_DECK_SIZE = 22;
uint256 public constant MAX_DECK_SIZE = 30;
uint256 public constant MIN_ROUND_CARDS = 5;
uint256 public houseFeePercent = 2; // Mutable percentage per match pool
uint256 public waitingHead;      // Pointer to next unmatched player
uint256 public resolutionHead;   // Pointer to next unresolved match
```

### Queue Optimization (O(1) Pointers)
To ensure the contract remains gas-efficient as player count scales, the `waitingQueue` and `resolutionQueue` use **Head Pointers**. 
- `checkUpkeep` always starts scanning from the `Head` instead of index 0.
- `performUpkeep` increments the `Head` after processing.
- This prevents "Iterating over growing arrays" and keeps the system's gas costs constant.

### Arena Flow

#### Phase 1: Entry & Keepers Matchmaking
1. User calls `enterArena(faction, cardIds[], cardAmounts[])`. No stakeAmount dictation.
2. Contract validates Faction cards using `CardRegistryPure.sol`.
3. Contract transfers cards to itself and burns `entryFee` game currency.
4. Player added to a **global unified** `waitingQueue` (Any faction can battle any faction).
5. **Chainlink Automation Keepers** run `checkUpkeep` continuously. If two unmatched players are detected, Chainlink calls `performUpkeep`.
6. Match instantiated natively with zero gas fees charged to Player 2.

#### Phase 2: Commit (3 days)
1. Both players call `commitPlays(matchId, r1Hash, r2Hash, r3Hash)`
2. Hash = keccak256(roundCards + salt) - hidden
3. If both commit early → moves to Reveal immediately
4. After 3 days → anyone can call `timeoutCommit()`

#### Phase 3: Reveal (1 day)
1. Both players call `revealPlays(matchId, r1Ids, r1Amounts, r2Ids, r2Amounts, r3Ids, r3Amounts, salt)`
2. Contract verifies: `keccak256(ids + amounts + salt) == committed hash`
3. If both reveal → Match enters **Phase 4: WaitingForResolution**
4. After 1 day → anyone can call `timeoutReveal()`

#### Phase 4: Match Resolution (Automated)
1. After both players reveal their cards, the match phase becomes `WaitingForResolution`.
2. Chainlink Automation detects the state change and calls `performUpkeep`.
3. `_resolveMatch` executes. It verifies `revealedCounts[id] <= originalAmounts[index]` for each player, sums the `amounts` for scores, and checks for `< 5 cards` in R1/R2.
4. **Slashing**: If a player cheats, score=0. If both cheat, the pool is awarded to the system owner.
5. This ensures players never manually pay gas for the high-computational costs of game logic scoring.

### Owner Functions
| Function | Description |
|----------|-------------|
| `setEntryFee(uint256)` | Fixed system-wide cost to enter arena |
| `setHouseFeePercent(uint256)` | % burned/removed from prize pool per match |
| `setWaitRewardPerBlock(uint256)` | Per-block waiting reward |
| `setCommitTimeout(uint256)` | Commit phase duration |
| `setRevealTimeout(uint256)` | Reveal phase duration |
| `setCallerRewardPercent(uint256)` | Reward % for timeout caller |

### User & System Functions
| Function | Description |
|----------|-------------|
| `enterArena(faction, cardIds[], cardAmounts[])` | Enter arena (no stake param) |
| `checkUpkeep(bytes)` | Chainlink: check global queue for opponents OR resolutions |
| `performUpkeep(bytes)` | Chainlink: execute match creation or resolution |
| `commitPlays(matchId, r1Hash, r2Hash, r3Hash)` | Submit hidden plays (hashed ID+Amount arrays) |
| `revealPlays(...)` | Reveal actual plays (ID+Amount parallel arrays) |
| `cancelEntry()` | Cancel if not matched (get cards + stake back) |
| `claimRewards(matchId)` | Claim winnings (auto-resets queue state) |
| `claimCards(matchId)` | Get back staked cards (auto-resets queue state) |
| `timeoutCommit(matchId)` | Trigger if commit deadline passed |
| `timeoutReveal(matchId)` | Trigger if reveal deadline passed |
| `getWaitingPlayers()` | View all waiting players |
| `getMatchInfo(matchId)` | View match details |
| `getPlayerEntry(player)` | View player entry (includes latestMatchId history) |

### Timeout Handling
- Anyone can call timeout functions after deadline
- Caller gets reward (1% of pool default)
- If player doesn't commit/reveal → they lose
- If both don't commit/reveal → both lose, stakes refunded

### Waiting Rewards
- Formula: `blocks × perBlock`
- Compensates first player while waiting for Chainlink to group.
- Stops when matched or cancelled

---

## How Contracts Connect

```
User Flow:

1. Buy tokens
   GwentCardToken.buyTokens()
   → Pays WETH, receives game currency

2. Open packs
   GwentSystem.openXXXPack()
   → Burns 100 tokens
   → Chainlink VRF generates random cards
   → claimRolls() → cards minted to wallet

3. Enter arena
   GwentArena.enterArena()
   → Transfers cards to arena contract
   → Burns entry fee tokens
   → Chainlink Automation detects 2 queue members and generates Match!

4. Battle
   commitPlays() → revealPlays() → WaitingForResolution → _resolveMatch() (Automated)

5. Win
   claimRewards() → receives tokens
   claimCards() → receives cards back
```

### Role Requirements
```
GwentSystem needs: GwentCardToken.BURNER_ROLE
GwentArena needs: GwentCardToken.BURNER_ROLE
```

---

## Deployment Checklist

1. Deploy GwentCardToken
2. Deploy WETH (or use existing)
3. GwentCardToken.setWethToken(WETH_ADDRESS)
4. Deploy GwentSystem (with VRF config)
5. GwentCardToken.grantBurnerRole(GwentSystem_ADDRESS)
6. Deploy GwentArena
7. GwentCardToken.grantBurnerRole(GwentArena_ADDRESS)
8. Optional: Airdrop initial tokens

---

## Gas Considerations

- **Storage reads**: ~100-2100 gas (cheap)
- **Storage writes**: ~20,000 gas (expensive)
- **On Polygon**: Very cheap (~$0.001 per tx)
- Ownership verification at entry: ~30 balanceOf calls = ~3,000 gas

---

## Next Steps

1. **CardGameLogic.sol** - Implement actual scoring with abilities
2. **Frontend** - UI for all flows
3. **Testing** - Unit and integration tests

---

*Last Updated: March 2026*
*This is a fully on-chain project with no off-chain components*
