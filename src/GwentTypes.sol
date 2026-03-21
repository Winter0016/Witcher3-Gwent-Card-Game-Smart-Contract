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

enum Faction {
    Northern,
    Nilfgaard,
    Monster,
    Scoiatael,
    Skellige,
    Neutral
}

struct Match {
    address player1;
    address player2;
    Faction faction1;
    Faction faction2;
    bytes32 player1R1Hash;
    bytes32 player1R2Hash;
    bytes32 player1R3Hash;
    bytes32 player2R1Hash;
    bytes32 player2R2Hash;
    bytes32 player2R3Hash;
    uint256[] player1R1Packed;
    uint256[] player1R2Packed;
    uint256[] player1R3Packed;
    uint256[] player2R1Packed;
    uint256[] player2R2Packed;
    uint256[] player2R3Packed;
    uint256 stakeAmount;
    uint256 poolAmount;
    Phase phase;
    uint256 commitDeadline;
    uint256 revealDeadline;
    MatchResult result;
}

struct MatchInfo {
    address player1;
    address player2;
    uint256[] deck1Packed;
    uint256[] deck2Packed;
    uint256 stakeAmount;
    Phase phase;
    uint256 commitDeadline;
    uint256 revealDeadline;
    MatchResult result;
}
