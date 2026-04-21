# 🤝 Autonomous Matchmaking & Fair Play

This document explains the technical implementation of the `GwentArena` matchmaking system, leveraging Chainlink Automation and Commit-Reveal security.

---

## ⚡ The Head Pointer System (O(1) Scalability)

Traditional "Matchmaking" often requires looping through an array of players, which becomes prohibitively expensive as the game grows. 

Gwent Arena solves this with a **Head Pointer** mechanism:
- **`waitingHead`**: A state variable that tracks the index of the oldest unmatched player.
- **Gas Efficiency**: Instead of scanning from index 0, the system only starts looking at `waitingHead`. 
- **Auto-Increment**: Once a match is made, `waitingHead` increments, ensuring the search space never balloons.

---

## ⛓️ Chainlink Automation (Keepers)

To ensure the game is autonomous and decentralized, Chainlink nodes act as the "Matchmakers."

### `checkUpkeep` (Off-Chain)
Chainlink nodes simulate this function every block:
1. It scans the queue starting from `waitingHead`.
2. It identifies if two players are eligible for a match.
3. It returns the match data if an opponent is found.

### `performUpkeep` (On-Chain)
If `checkUpkeep` returns true, the node executes this on-chain transaction:
1. It receives the player addresses from the node.
2. it calls `_createMatch()`, instantiating the game state.

---

## 🛡️ Anti-Cheating: Commit-Reveal

The protocol protects players from "Front-running" or "Look-ahead" attacks using a 2-step play submission.

| Phase | Duration | Action | Security |
|---|---|---|---|
| **Commit** | 3 Days | Users submit `keccak256(cards + salt)`. | The cards are hidden; no one can see what you played. |
| **Reveal** | 1 Day | Users submit plain cards + salt. | The contract verifies the hash. If changed, the player is slashed. |

---

## 🏆 Rewards & Slashing

- **Stake**: When entering, cards are locked in the Arena contract.
- **Victory**: Winners receive $GWENT tokens and can safely withdraw their cards.
- **Abandonment**: If a player refuses to reveal after a match, they are timed out. Their opponent is awarded the win, and the bad actor loses their stake.

---

*Matchmaking Specification - V1.2*
