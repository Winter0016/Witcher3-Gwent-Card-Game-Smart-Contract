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
- **Spy**: Contributes its power to the **opponent's** board score for that row. *On-play effect: Player chooses 2 additional cards from the leftover deck (`availability` array) to add to the current round.*
- **Berserker**: If a `Mardroeme` card is present in the same row, this card transforms and uses its `berserker_power` instead of its base power.
- **Mardroeme**: Triggers the `Berserker` transformation for units in its row.
- **Scorch**: Disables a specific selection of unit abilities for the entire round for **both** players. The specific ability is chosen by the player who plays the Scorch card (Encoded in Bits 32+).
- **Decoy**: A **counter-scorch** card. If a unit's ability is disabled by Scorch, having a Decoy in the player's round "unlocks" those abilities for them.

### Weather Effects
- **weather_sets_close_1** (Biting Frost): All non-hero `Close_Combat` units have their power set to 1.
- **weather_sets_range_1** (Impenetrable Fog): All non-hero `Ranged` units have their power set to 1.
- **weather_sets_sieg_1** (Torrential Rain): All non-hero `Siege` units have their power set to 1.
- **weather_reduces_close_range_1** (Skellige Storm): All non-hero `Close_Combat` AND `Ranged` units have their power set to 1.
- **weather_clears**: Removes all active weather effects.

### Triggered/Play-time Effects
- **Medic**: Only playable in Round 2 and Round 3. Allows player to replay a non-hero unit from the **Graveyard** (cards played in previous rounds).
- **Muster**: Instantly plays all cards with the same group name from the `availability` array (remaining deck).
- **Summon**: Calls specific cards from the `availability` array to the board.
- **Transform_After_Death**: Triggers a replacement card or effect when the unit is removed.

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

### Encoding Specification (16-Bit Slots)
To make bit-packing human-readable and scalable, we use 16-bit offsets:
- **Bits 0-15 (Shift 0)**: Card ID (1-144).
- **Bits 16-31 (Shift 16)**: Target Row (0=Close, 1=Ranged, 2=Siege).
- **Bits 32-47 (Shift 32)**: Scorch Ability Selection (0-7).
- **Bits 48-63 (Shift 48)**: Spy Card 1 ID (from deck).
- **Bits 64-79 (Shift 64)**: Spy Card 2 ID (from deck).
- **Bits 80-95 (Shift 80)**: Card Amount.

### Scorch Ability Selection (Bits 32-47)
When **Scorch (ID 139)** is played, bits 32-47 encode the ability to disable:
- `0`: Berserker
- `1`: Transform_After_Death
- ... (and so on)

### Usage Examples
- **Mardroeme (ID 136)** on **Ranged (Row 1)**: `136 + (1 << 8) = 136 + 256 = 392`.
- **Commander's Horn (ID 137)** on **Siege (Row 2)**: `137 + (2 << 8) = 137 + 512 = 649`.
- **Hero Unit (ID 1)**: Row is ignored/fixed, so `1` is still `1`.

### Data Unpacking Logic
```solidity
uint256 packed = packedArray[i];
uint16 cardId = uint16(packed & 0xFFFF);
uint8 targetRow = uint8((packed >> 16) & 0x03);
uint8 scorchSelection = uint8((packed >> 32) & 0xFF);
/* 
        Berserker,
        Transform_After_Death,
        Medic,
        Morale_Boost,
        Muster,
        Summon,
        Spy,
        Tight_Bond,

*/
uint16 spy1 = uint16((packed >> 48) & 0xFFFF);
uint16 spy2 = uint16((packed >> 64) & 0xFFFF);
uint16 amount = uint16((packed >> 80) & 0xFFFF);
```

### Validation & Safety (Cheating Prevention)
To prevent players from "forcing" a unit into an illegal row (e.g., putting a Close Combat unit on the Siege row), the `CardGameLogic` library applies these strict rules:

1.  **Fixed-Row Units**: If a card's `UnitType` is `Close_Combat`, `Ranged`, or `Siege`, the encoded bits are **completely ignored**. The unit is always placed in its native row.
2.  **Flexible Cards**: The encoded row is **only** respected for:
    - **Special Cards** (ID 136-137: Mardroeme and Commander's Horn).
    - **Agile Units** (Any unit with `UnitType.Agile`).
3.  **Invalid Row Handling**: If a flexible card encodes a row index `> 2` (e.g., value 3), it will default to the **Close Combat** row to prevent logic errors.

### Validation & Safety (Cheating Prevention)
During the `GwentArena._verifyDeckIntegrity` phase, the packing is stripped to verify ownership:
```solidity
uint256 cleanId = packed & 0xFFFF;
require(availability[cleanId] >= amount, "Cheater");
```

This keeps the system 100% secure without adding extra loops or expensive `if` checks.
