# 📦 Gwent System: Card Generation & VRF Manual

The `GwentSystem.sol` contract is the backbone of the protocol's economy. it handles the fair generation of cards using **Chainlink VRF V2.5** and provides the primary interface for card inspection.

---

## 🎁 Pack Mechanics

There are five Faction Packs available in the system. Opening a pack initiates a request for provably fair randomness.

### **The Starter Pack (New Players)**
The protocol rewards new players with their first taste of Gwent.
*   **Benefit**: The first pack any player opens is **FREE**.
*   **Content**: A fixed 4-card starter set to get you into the Arena immediately.

### **Faction Packs (Standard)**
*   **Price**: 100 Gwent Tokens per pack.
*   **Factions**: Northern Realms, Scoia'tael, Nilfgaard, Monsters, and Skellige.
*   **Bulk Opening**: Players can specify the `amount` of packs to open in a single blockchain request.

> [!NOTE]
> **Permanent Liquidity**: Unlike unit cards, **Game Currency (ID 0)** is never locked by the Arena. You can always transfer currency to other players or open new packs, even while your units are locked in an active match.

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
