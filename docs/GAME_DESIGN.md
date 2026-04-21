# 🎮 Gwent Arena: The Architecture of War (V1.5)

This document explores the technical core, specialized matchmaking, and decentralized economics that power the Gwent Arena. 

---

## 🏛️ The Protocol Engine

The Arena is built on **Arbitrum Sepolia** using a modular "Proxy-Logic" architecture. This allows the community to upgrade the game rules without ever migrating your cards or history.

### The Specialized Modules
*   **The Arena (`GwentArena.sol`)**: The heart of the matchmaking engine. It tracks every duel, monitors player stakes, and ensures prize pools reach the rightful winners.
*   **The Scoring Brain (`CardGameLogic.sol`)**: A specialized, gas-optimized library that calculates complex battle results across three rows in milliseconds.
*   **The Distribution System (`GwentSystem.sol`)**: Manages card pack generation and acts as the bridge to **Chainlink VRF** for provably fair rewards.
*   **The Treasury & Power (`GwentCardToken.sol`)**: Not just a currency, but the voice of the community. Every token held represents a vote in the protocol's future.

---

## ⚔️ The Matchmaking Experience

### High-Speed Pairing
We’ve engineered a **Head-Pointer Matchmaking** system to ensure your queue times are short and gas costs are zero.
*   **No Waiting in Line**: The engine uses a high-efficiency queue that finds your opponent instantly, regardless of how many thousands of players are currently in the Arena.
*   **Fair Play Focus**: Matches are faction-agnostic. Whether you field a Skellige deck or a Monster horde, you’ll find a balanced challenge.

### The Commit-Reveal Handshake
To ensure no player can "peek" at their opponent's strategy before playing, every match follows a secure 4-step cycle:
1.  **The Secret Pledge (Commit)**: You submit a hidden hash of your chosen moves.
2.  **The Great Reveal**: Both players reveal their actual cards and "Salt" to verify their pledges.
3.  **The Scoring Duel**: The engine calculates the victor based on the **Story Order** of combat logic.
4.  **The Victory Claim**: Winners instantly receive their winnings from the match pool.

---

## 🏛️ Community Governance

The Gwent Protocol belongs to its players. Admin control has been fully migrated to the **Gwent DAO**.

*   **The Voice of the Player**: Any player with enough tokens can propose changes to game balance, fees, or even new card abilities.
*   **The Guardian Veto**: A 3-member Security Council acts as a safety net. If a proposal is malicious, a **Supermajority (2 of 3)** can veto it during the mandatory delay period, keeping the protocol safe for everyone.

---

## 💰 Economics & Fairness

### Protocol Health
*   **The Entry Fee**: Keeps the ecosystem vibrant. A small portion of tokens is burned on entry, making each token you own more valuable over time.
*   **The Fair House Cut**: A 2% fee is taken from prize pools to fund future tournaments and development.

### Tournament Integrity
*   **Anti-Cheat Slashes**: Players who try to stall or cheat by not revealing their cards are automatically penalized, with their stake awarded to their opponent.
*   **The Sentinel Bonus**: Any community member who helps resolve a timed-out match receives a 1% reward from the match pool for keeping the protocol moving.

---

## 🎲 The Randomness Guarantee

We use **Chainlink VRF V2.5** to ensure that every card pack you open is provably fair.
*   **No House Edge**: Not even the protocol developers can predict or influence which cards you’ll find in a pack.
*   **Provability**: You can verify the randomness of your specific pack opening directly on the blockchain.

---

*Verified on Arbitrum Sepolia - April 2026*
