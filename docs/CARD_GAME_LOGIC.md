# CardGameLogic Implementation Plan

This document outlines the architecture and logic for the `CardGameLogic.sol` library, which will handle the complex scoring rules for the Gwent Arena.

## 1. Overview
Gwent scoring is not a simple summation. It involves multiple layers of modifiers (Weather, Morale Boost, Tight Bond, etc.) applied in a specific order. The `CardGameLogic` library will provide a pure interface to calculate scores based on revealed cards and the current board state.

## 2. Core Data Structures

### Board State
To calculate the total score for a player in a round, we need to categorize cards into rows.

```solidity
struct RowState {
    uint256[] cardIds;
    uint256[] cardAmounts;
    bool hasCommanderHorn; // Is a Horn card present in this row?
}

struct PlayerBoard {
    RowState closeCombat;
    RowState ranged;
    RowState siege;
}

struct GlobalWeather {
    bool bitingFrost;  // Affects Close Combat
    bool impenetrableFog; // Affects Ranged
    bool torrentialRain; // Affects Siege
}
```

## 3. Scoring Logic Order of Operations

### Optimized Scoring Hierarchy (Row-Level)
To optimize for Gas and minimize unnecessary checks, we apply modifiers in this specific order:

1.  **Hero Check**: If `Ability == Hero`, return `basePower` immediately. Skip all other steps.
2.  **Weather Base**: If the row is weathered, the unit's `effectivePower` starts at **1**. Otherwise, it starts at `basePower`.
3.  **Tight Bond Phase**: If the unit has `Tight_Bond` and there are 2+ copies, `effectivePower = effectivePower * 2`.
4.  **Morale Phase**: Add +1 for every `Morale_Boost` card in the row (excluding the card itself if it has the ability).
5.  **Final Multiplier**: If the row has a `Commander's Horn` (via card or special placement), `totalRowScore += (effectivePower * 2)`.

## 4. Full Ability List & Descriptions

The following abilities are defined in `CardRegistryPure.Ability`. Descriptions reflect the specific rules for this smart contract implementation:

### Scoring Modifiers (Core Logic)
- **None**: Simple unit, no extra effects.
- **Hero**: Immune to everything. Power cannot be changed by Weather, Horns, Morale Boosts, or Scorch.
- **Tight_Bond**: If two or more cards with the **same ID** are in the same row, the **total strength** of those specific units is **doubled** (e.g., `(sum of base powers) * 2`). This multiplier is always exactly 2, regardless of whether there are 2, 3, or more cards.
- **Morale_Boost**: Adds **+1** power to **all** units in the row (excluding itself).
- **Commander_horn**: Doubles the total power of all non-hero units in its row. Only one Horn modifier is applied per row.
- **Spy**: Contributes its power to the **opponent's** board score for that row. *On-play effect: Player chooses 2 cards to draw from the deck.*
- **Berserker**: If a `Mardroeme` card is present in the same row, this card transforms and uses its `berserker_power` instead of its base power.
- **Mardroeme**: Triggers the `Berserker` transformation for units in its row.

### Weather Effects
- **weather_sets_close_1** (Biting Frost): All non-hero `Close_Combat` units have their power set to 1.
- **weather_sets_range_1** (Impenetrable Fog): All non-hero `Ranged` units have their power set to 1.
- **weather_sets_sieg_1** (Torrential Rain): All non-hero `Siege` units have their power set to 1.
- **weather_reduces_close_range_1** (Skellige Storm): All non-hero `Close_Combat` AND `Ranged` units have their power set to 1.
- **weather_clears**: Removes all active weather effects.

### Triggered/Play-time Effects
- **Decoy**: Acts as a **protector**. Any non-hero unit card placed **next** to a Decoy is protected from the Scorch ability.
- **Medic**: Only playable in Round 2 and Round 3. Allows player to replay a non-hero unit from the **Graveyard** (cards played in previous rounds).
- **Scorch**: 
  - **Global Battlefield** (Both players, all rows): Triggered by the **Scorch (Special Card, ID 139)** and **Clan Dimun Pirate (ID 128)**. Destroys the strongest non-hero unit(s) on the board if the opponent's total strength is 10 or more.
  - **Specific Row**: Triggered by other **Unit cards with Scorch** (like Schirrú ID 43 or Toad ID 108). These only affect the strongest non-hero unit(s) in the row they target (the row equivalent to where they are played).
  - *Note: Protected units (next to Decoy) or Heroes are always ignored by Scorch.*
- **Muster**: Instantly plays all cards with the same group name from deck or hand.
- **Summon**: Calls specific cards to the board (e.g., Cerys summoning Shield Maidens).
- **Transform_After_Death**: Triggers a replacement card or effect when the unit is removed from the board (e.g., Kambi/Hemdall).

## 5. Proposed Library Interface

```solidity
library CardGameLogic {
    function calculatePlayerScore(
        uint256[] memory myIds,
        uint256[] memory myAmounts,
        uint256[] memory opponentIds,
        uint256[] memory opponentAmounts,
        GlobalWeather memory globalWeather
    ) public pure returns (uint256 totalScore) {
        // 1. Categorize cards for Player's board:
        //    - Include 'my' cards that are NOT Spies.
        //    - Include 'opponent' cards that ARE Spies.
        // 2. Aggregate weather from 'my', 'opponent', and 'globalWeather'.
        // 3. Apply scoring rules to categorized rows.
    }
}
```

## 6. Integration with GwentArena.sol

The `GwentArena._resolveMatch` function will be updated to:
1.  Parse the revealed cards for both players.
2.  Call `CardGameLogic.calculatePlayerScore` for Player 1 (passing P2 cards as opponent).
3.  Call `CardGameLogic.calculatePlayerScore` for Player 2 (passing P1 cards as opponent).
4.  Compare total scores to determine the round winner.

## 7. Ability logic refinements
*   **Spy**: These cards land on the opponent's row and contribute to the opponent's score.
*   **Agile Units**: For on-chain resolution, agile units default to their primary row (Close_Combat for Scoiatael units) unless metadata is added later.
*   **Skellige Storm**: This weather card sets BOTH Ranged and Siege rows to 1 for all cards.

## 8. Implementation Strategy: Prioritized Two-Pass

To maximize Gas efficiency and follow the user's "Override First" requirement, we limit the process to **two loops** with a focus on early prioritization:

### Pass 1: Prioritized Sorting & Aggregation `O(N)`
We scan the input arrays (`ids`, `amounts`) to establish the "Environment" before processing individual units:
1.  **Priority: Overrides & Environment**:
    - If a **Weather (140-144)** or **Special Horn (137)** card is found, the row/global flags are set immediately.
    - This "Sets the stage" so that when units are processed later, we already know if their power will be overridden by weather.
2.  **Special Unit Handling**:
    - **Spies**: Identified and moved to the opponent's row state.
    - **Heroes**: Flagged as immune. During calculation, we can **skip all modifiers** for these cards.
3.  **Row Assignment**: Units are categorized into `Close`, `Ranged`, or `Siege`.

### Pass 2: Optimized Scoring Calculation `O(R)`
Using the environment established in Pass 1, we calculate row scores while skipping unnecessary logic:
1.  **Skip-If-Weathered**: For any non-hero unit, if the row's weather flag is `true`, we skip the base power check and start calculation from `1`.
2.  **Skip-If-Hero**: If a unit is a Hero, we skip Tight Bond, Morale, Horn, and Weather checks entirely, using only `basePower`.
3.  **Ability Summation**: Apply Tight Bond (2x for group), Morale (+1 per unit), and Horn (2x row) only where applicable.

This approach ensures "Priority" cards effectively override other logic, minimizing the number of `if` checks performed per unit.

## 9. Flexible Card Placement (Row Encoding)

Since `Commander's Horn`, `Mardroeme`, and `Agile` units can be placed in different rows, but the contract only receives `ids` and `amounts`, we use **Bit-Packing** to encode the user's row choice directly into the ID.

### Encoding Specification
The 256-bit `id` will be interpreted as follows:
- **Bits 0-7 (1-255)**: The actual Card ID (matches `CardRegistryPure`).
- **Bits 8-9 (Value 0-3)**: The Target Row Index.
  - `0`: Close Combat
  - `1`: Ranged
  - `2`: Siege
  - `3`: Global/Reserved

### Usage Examples
- **Mardroeme (ID 136)** on **Ranged (Row 1)**: `136 + (1 << 8) = 136 + 256 = 392`.
- **Commander's Horn (ID 137)** on **Siege (Row 2)**: `137 + (2 << 8) = 137 + 512 = 649`.
- **Hero Unit (ID 1)**: Row is ignored/fixed, so `1` is still `1`.

### Data Unpacking Logic
```solidity
uint16 revealedId = uint16(ids[i]);
uint16 cardId = revealedId & 0xFF;        // Gets ID (1-255)
uint16 targetRow = (revealedId >> 8) & 0x03; // Gets Row (0-2)
```

### Validation & Safety (Cheating Prevention)
To prevent players from "forcing" a unit into an illegal row (e.g., putting a Close Combat unit on the Siege row), the `CardGameLogic` library applies these strict rules:

1.  **Fixed-Row Units**: If a card's `UnitType` is `Close_Combat`, `Ranged`, or `Siege`, the encoded bits are **completely ignored**. The unit is always placed in its native row.
2.  **Flexible Cards**: The encoded row is **only** respected for:
    - **Special Cards** (ID 136-137: Mardroeme and Commander's Horn).
    - **Agile Units** (Any unit with `UnitType.Agile`).
3.  **Invalid Row Handling**: If a flexible card encodes a row index `> 2` (e.g., value 3), it will default to the **Close Combat** row to prevent logic errors.

### Updated Registry Verification (`_verifyDeckIntegrity`)
The `GwentArena.sol` check for card ownership will be updated to ignore the encoding bits during the "count" phase:
```solidity
uint256 cleanId = ids[i] & 0xFF; // Strip the row bits (keeping only ID 1-255)
require(revealedCounts[cleanId] <= ownedAmounts[cleanId], "Cheater");
```

This keeps the system 100% secure without adding extra loops or expensive `if` checks.
