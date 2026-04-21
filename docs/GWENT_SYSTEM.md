# 📦 Gwent System: Card Generation & VRF Manual

The `GwentSystem.sol` contract is the backbone of the protocol's economy. it handles the fair generation of cards using **Chainlink VRF V2.5** and provides the primary interface for card inspection.

---

## 🎁 Pack Mechanics

There are five Faction Packs available in the system. Opening a pack initiates a request for provably fair randomness.

### **The Starter Boost (New Players)**
The protocol rewards new players by kickstarting their favorite faction immediately.
*   **The Bonus**: The first time any player opens a pack, it is **FREE**.
*   **The Multiplier**: The system automatically treats the first opening as a **4-Pack request** for that specific faction. 
*   **⚠️ One-Shot Bonus**: This is a single-transaction benefit. You do not get 4 separate choices; whatever faction you pick first is the one that gets the 4x boost. Once you open your first pack, the bonus is gone forever.

### **Faction Packs (Standard)**
*   **Price**: 100 Gwent Tokens per pack.
*   **Bulk Opening**: Specifying `amount` multiplies your requested packs.

| Faction | Cards per Pack | Starter Yield (4x) | Arena Ready? |
| :--- | :--- | :--- | :--- |
| **Northern Realms** | **6** | **24** | ✅ **YES** |
| **Scoia'tael** | 5 | 20 | ❌ No (Need 22) |
| **Monsters** | 5 | 20 | ❌ No (Need 22) |
| **Skellige** | 4 | 16 | ❌ No (Need 22) |
| **Nilfgaard** | 3 | 12 | ❌ No (Need 22) |

> [!IMPORTANT]
> **The Starter Trap**: If you pick any faction other than Northern Realms for your first free opening, you will not have enough cards to enter the Arena. You will need to buy additional Gwent Tokens to complete your deck.

---

## 🎲 The Card Generation Cycle

Because card rarity determines power, the protocol uses a decentralized 3-step cycle to ensure the house can never cheat.

### **1. The Request**
When you call an `open[Faction]Pack` function:
*   The contract burns the required tokens.
*   A `RandomWordsRequest` is sent to the Chainlink VRF Coordinator.
*   A `requestId` is returned to the player.

### **2. The Fulfillment**
Chainlink's decentralized oracles generate a cryptographic proof of randomness and deliver it to our `fulfillRandomWords` function.
*   **Packing**: The contract packs these random card IDs into storage slots to save gas.
*   **State**: The pack status moves from "Pending" to "Fullfilled."

### **3. The Claim**
The player calls `claimRolls(requestId)` to finalize their reward.
*   The contract unpacks the random results.
*   Cards are minted as ERC1155 NFTs directly to the player's wallet.
*   The system verifies that only the original requester can claim the cards.

---

## 💎 Card Rarity Logic

Every card generated follows a tiered probability model based on a 0-99 roll:

| Roll Range | Rarity | Probability |
| :--- | :--- | :--- |
| **0 - 49** | Common | 50% |
| **50 - 79** | Uncommon | 30% |
| **80 - 94** | Rare | 15% |
| **95 - 98** | Epic | 4% |
| **99** | **Legendary** | 1% |

---

## 🔍 Card Inspection API

The protocol provides a high-level helper function for UIs and CLI users to understand card data without needing to reference the Card Registry directly.

### `InspectCard(uint16 id)`
Returns human-readable strings for any card in the ecosystem:
*   **Power**: Base combat power.
*   **Berserker Power**: Transformation power (if applicable).
*   **Ability**: The name of the special trait (e.g., "Tight Bond").
*   **Unit Type**: Row placement (e.g., "Ranged").
*   **Faction**: The faction the card belongs to.

---

## 🏛️ Governance & Security

The system is protected by specialized administrative roles:

*   **UPGRADER_ROLE**: Authorized to set the VRF Coordinator address and upgrade the logic via UUPS.
*   **DEFAULT_ADMIN_ROLE**: Manages general protocol permissions.
*   **Storage Gap**: Includes a 50-slot `__gap` to ensure future V2 logic can add new pack types or rarity tiers safely.
