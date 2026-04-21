# 🃏 Decentralized Gwent: The Witcher's Arena

[![Network: Arbitrum Sepolia](https://img.shields.io/badge/Network-Arbitrum_Sepolia-blue.svg)](https://sepolia.arbiscan.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**Forge your deck. Master the rows. Rule the Continent.**

Decentralized Gwent is a high-stakes, on-chain card strategy game where every move is secured by the blockchain and every drop of luck is provably fair. Merging high-fidelity strategy with decentralized trust, the protocol features a **UUPS-upgradeable** engine, **Chainlink VRF** randomness, and a robust **DAO-Guardian** security model.

### 🛡️ Play for More Than Just Victory
*   **The Patience Economy**: Earn passive rewards (Gwent Tokens) just for waiting in the matchmaking queue.
*   **Strategic Commitment**: Scout your opponent's entire deck before the battle begins, plan your counters, and "Seal" your 3-round strategy. The **Commit-Reveal** system ensures that no one can reactively change their moves once the duel starts.
*   **Autonomous Referee**: Powered by **Chainlink Automation**, matches are paired and resolved instantly without any manual intervention.
*   **True Ownership**: Every card is an NFT on Arbitrum Sepolia, owned and tradable by you.

> [!TIP]
> **🚀 Quick Start**
> 1.  **Fund your Journey**: Buy game tokens in Step 1 of the [Player Tutorial](./docs/TUTORIAL.md).
> 2.  **Pick your Faction**: Get your **First 4 Packs for FREE** via the [Gwent System](./docs/GWENT_SYSTEM.md).
> 3.  **Enter the Arena**: Join the queue and start earning while you wait for a challenger.

---

## 🚀 The Player's Journey (1-2-3 Guide)

You don't need to be a blockchain expert to rule the Arena. Here is how you get started:

### 1. **Get your Gold** 💰
Visit the `GwentCardToken` contract to swap ETH for Gwent Tokens. These tokens are your key to opening packs and entering tournaments.

### 2. **Build your Deck** 🎁
Choose your favorite Faction and click "Open". For your **very first opening only**, the system will **automatically multiply your request by 4** for free. 

> [!WARNING]
> **One-Shot Bonus**: You don't get 4 separate choices. The very first time you click "Open" for any faction, the system uses your one-time newbie bonus to give you 4 packs worth of cards from that specific faction. Choose wisely!

### 3. **Enter the Arena** ⚔️
Join the matchmaking queue in `GwentArena`. While you wait for an opponent, you **earn passive rewards** just for being patient. Once a match is found, our "Auto-Referee" handles the scoring so you can focus on strategy.


---

## 🏛️ Governance & Security Model

We utilize a hybrid governance model that balances community ownership with protocol safety.

- **Governance Token**: `GwentCardToken`
- **Voting Unit**: **Game Currency (ID 0)**.
- **Voting Power**: 1 Unit (ID 0) = 1 Vote.
*   **Powers**: Adjusting protocol fees, updating contract logic, and managing the treasury.

### **2. The Security Council (Guardian Veto)**
*   **Role**: Acts as a "Circuit Breaker" for malicious governance attacks.
*   **Veto Power**: During the Timelock delay, a **66% Supermajority (2 of 3)** members can veto and cancel a proposal. 

---

## 📍 Deployed Addresses (Arbitrum Sepolia)

| Component | Target Address |
| :--- | :--- |
| **GwentGovernor** | `0x763ec857c1444a8D371435ED513F9852B7607263` |
| **GwentTimeLock** | `0xB9f3989d8740Ae6055Fb0e7Aeb6A93f176ca0A47` |
| **GwentCardToken** | `0x804671566D9e584145c0340B72aF5F9904974A66` |
| **GwentArena (Proxy)** | `0x7B417Fa3cfCA13A3b8B83703B8ACB4be3997c6Bd` |
| **GwentSystem (Proxy)** | `0x49eE0547272E50Fec45e8C11E0148BF97c803f24` |
| **WETH** | `0x9D3A4728d5e3006784d7F2a82dE8440031A7F70D` |

---

## 🛠️ Developer & Power-User Tools

### Build & Test
```bash
# Optimized via IR for large contract support
forge build --via-ir

# Execute the comprehensive test suite
forge test
```

### Interactive Validation (CLI)
Query the protocol directly from your terminal using `cast`:

**1. Inspect a Card's Human-Readable Data:**
```bash
cast call $SYSTEM_PROXY "InspectCard(uint16)(uint8,uint8,string,string,string)" <CARD_ID>
```

**2. Check Governance Role Status:**
```bash
cast call $ARENA_PROXY "hasRole(bytes32,address)(bool)" 0x00...00 $TIMELOCK
```

---

## 🤖 The Invisible Referee (Chainlink Automation)

Matches in the Gwent Arena are entirely autonomous. We utilize **Chainlink Automation** to perform the heavy lifting of game management:

-   **Instant Matchmaking**: The moment two eligible players enter the queue, Automation triggers the match initialization.
-   **Self-Resolving Battles**: As soon as the final player reveals their cards, Automation triggers the scoring engine to calculate the winner and distribute the pool.
-   **Anti-Stall Protection**: If a player abandons a match, Automation allows "Sentinels" (the community) to trigger a timeout resolution, ensuring prizes are never stuck in limbo.

---

## 📜 Technical Highlights
*   **UUPS Proxy Pattern**: Future-proof logic upgrades with minimal gas overhead.
*   **Storage Gaps**: 50-slot `__gap` implementation ensures zero-collision upgrades to V2.
*   **Provable Fair**: Chainlink VRF V2.5 ensures pack generation is tamper-proof.
*   **Self-Resolving Matches**: Chainlink Automation handles real-time matchmaking and scoring settlement.
*   **Scalable Queue**: O(1) head-pointer matchmaking designed for thousands of active players.

---

## ⚖️ License
Licensed under **MIT**.
