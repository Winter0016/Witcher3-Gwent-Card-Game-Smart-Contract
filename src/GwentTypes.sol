// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum Phase {
    WaitingForCommit,
    WaitingForReveal,
    WaitingForResolution,
    Completed
}

enum MatchResult {
    Pending,
    Player1Wins,
    Player2Wins,
    Draw,
    Both_Cheated,
    Player1Timeout,
    Player2Timeout,
    BothTimeout
}

enum Ability {
    None,
    Berserker,
    Commander_horn,
    Decoy,
    Hero,
    Medic,
    Morale_Boost,
    Mardroeme,
    Muster,
    Summon,
    Spy,
    Tight_Bond,
    Scorch,
    weather_sets_close_1,
    weather_clears,
    weather_sets_range_1,
    weather_reduces_close_range_1,
    weather_sets_sieg_1
}

enum UnitType {
    Close_Combat,
    Ranged,
    Siege,
    Agile,
    Weather,
    Special
}

enum Faction {
    Northern,
    Nilfgaard,
    Monster,
    Scoiatael,
    Skellige,
    Neutral
}

struct Match {
    // --- Slot 1: Packed Address + Bools ---
    address player1;
    // --- Slot 2: Packed Address + Bools ---
    address player2;
    bool revealed1;
    bool revealed2;
    // --- Slot 3: Packed Metadata (256 bits total) ---
    Phase phase; // 8 bits
    MatchResult result; // 8 bits
    uint64 commitDeadline; // 64 bits
    uint64 revealDeadline; // 64 bits
    uint112 poolAmount; // 112 bits (Safe for most prize pools)
    // --- Slots 4-5: Combined Hashes (32 bytes each) ---
    bytes32 player1CombinedHash;
    bytes32 player2CombinedHash;
    // --- Packed Round Data (Saves ~250k Gas) ---
    uint256[] player1PackedRounds;
    uint256[] player2PackedRounds;
    uint256 roundLengths; // [uint8 p1r1, p1r2, p1r3, p2r1, p2r2, p2r3]
}

struct ArenaEntry {
    Faction faction;
    uint256 stakeAmount;
    uint64 enterBlock;
    uint32 queueIndex;
    bool isMatched;
    uint256 deckLength;
    uint256[3] packedDeck;
    uint256[] matchIds;
}

struct MatchInfo {
    address player1;
    address player2;
    uint256[] deck1Packed;
    uint256[] deck1Amounts;
    uint256[] deck2Packed;
    uint256[] deck2Amounts;
    Phase phase;
    uint256 commitDeadline;
    uint256 revealDeadline;
    MatchResult result;
    bool revealed1;
    bool revealed2;
    uint256 poolAmount;
}
