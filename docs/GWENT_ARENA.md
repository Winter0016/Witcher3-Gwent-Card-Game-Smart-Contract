# 🏟️ Gwent Arena: Technical & Operational Manual

This document provides a comprehensive guide to the `GwentArena.sol` contract, detailing user operations, matchmaking mechanics, and governance controls.

---

## 🏛️ Overview
`GwentArena.sol` is the central hub for the decentralized Gwent ecosystem. It manages the matchmaking queue, handles the secure Commit-Reveal match cycle, and facilitates the distribution of prize pools and waiting rewards.

---

## ⚔️ Player Operations

These functions are the core interactive elements for players in the Arena.

### `enterArena`
*   **Purpose**: Joins the waiting queue for a match.
*   **Patience Reward**: While you wait in the queue, you accumulate a "Passive Income" (default 0.001 Gwent per block). **Crucial Rule**: This reward is only added to your balance **once a match is successfully found**.
*   **Requirements**: Must stake the current `entryFee`. The provided deck must be valid and owned by the player.
*   **Effect**: Locks the player's **cards (units)** to prevent mid-match trading, but **Game Currency (ID 0) remains fully liquid** and transferrable.

### `commitPlays` & `revealPlays`
*   **Purpose**: Reveal your plaintext cards and salt to settle the score.
*   **Verification**: The system verifies this against your hidden pledge.

### `getActiveMatches`
*   **Purpose**: Get a list of all currently ongoing battles (excluding completed matches).
*   **Strategy**: This allows you to browse the Arena and see who is currently in combat.
*   **Parameters**: Uses `offset` and `limit` for paginated results (e.g., browse match by match).

### `getMatchInfo`
*   **Purpose**: Get the full technical state of a match.
*   **Critical Feature**: This allows you to **scout your opponent's deck** once a match is created, letting you plan your counters before you commit your plays.
*   **Deadlines**: Matches have strict timers (default 3 days to commit, 1 day to reveal). Missing these results in an automatic forfeit.

### `claimPendingBalance`
*   **Purpose**: Withdraws your accumulated winnings and rewards from the protocol.
*   **Context**: Winnings are moved to a `pendingRewards` mapping after a match is resolved to prevent gas-heavy auto-transfers. Players can claim their full balance at any time.

### `cancelEntry`
*   **Purpose**: Exit the queue before a match is found.
*   **Effect**: Unlocks your cards and returns your `entryFee` stake.
*   **The Penalty**: If you cancel your entry, any "Passive Income" you accumulated while waiting is **forfeited**. Only matched players receive the wait reward.

---

## 🏛️ Governance & Admin Controls

The arena is governed by two specialized roles: **Admin** (Governance DAO) and **Owner** (Treasury Guardian).

### **Level 1: Admin Controls (DEFAULT_ADMIN_ROLE)**
These settings manage the day-to-day economy of the Arena:
*   `setEntryFee`: Adjusts the cost of entering a match.
*   `setWaitRewardPerBlock`: Controls the "Patience Reward" given to players waiting in the queue.
*   `setCommitTimeout` & `setRevealTimeout`: Adjusts the match timers to speed up or slow down gameplay.
*   `setCallerRewardPercent`: Sets the reward (default 1%) given to community members who help resolve timed-out matches.

### **Level 2: Owner Controls (OWNER_ROLE)**
These settings manage the protocol's fundamental safety and revenue:
*   `setHouseFeePercent`: Adjusts the small cut (default 2%) the protocol takes from prize pools.
*   `setTreasury`: Defines where the protocol fees are sent.
*   `claimFees`: Withdraws the accumulated protocol revenue to the treasury address.

---

## 🛠️ Internal Mechanics

### **O(1) Head-Pointer Queue**
To ensure the protocol can support thousands of players without high gas costs, the Arena uses a "Head-Pointer" system. Chainlink Automation starts scanning for matches from the `waitingHead` and moves forward, meaning we never iterate over old or empty queue slots.

### **Automated Resolution**
The `checkUpkeep` and `performUpkeep` functions allow the protocol to operate autonomously.
1.  **Matchmaking**: Automatically pairs the first two valid players in the queue.
2.  **Resolution**: Automatically triggers the scoring engine as soon as the last player reveals their cards.

### **Timeout Resolvers**
If a player goes "AFK" (Away from Keyboard) during a match:
*   `timeoutCommit`: Can be called by anyone after the deadline to award the win to the player who did their part.
*   `timeoutReveal`: Awards the win to the player who revealed their cards if the opponent failed to do so.

---

## 📜 Technical Specs
*   **Proxy Pattern**: UUPS (Universal Upgradeable Proxy Standard).
*   **Inheritance**: Uses `AccessControl` for roles, `ReentrancyGuard` for safety, and `ERC1155Holder` to manage card locks.
*   **Storage Safety**: Includes a `uint256[50] __gap` to ensure future upgrades never corrupt existing data.
