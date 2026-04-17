# Gwent Protocol: The Player's Guide

Welcome to the Gwent Protocol. This guide explains how to play, how to win, and how the numbers on the board are calculated.

---

## 🏆 How to Win

The game is played in **3 Rounds**. To win the match, you must win more rounds than your opponent.

*   **Round Win**: Have a higher Total Score than your opponent at the end of the round.

*   **Draws**: If a round is tied, both players receive 1 point. If the 3-round total is tied (e.g., 1-1 and a draw), the prize pool is split **50/50**.

---

## ⚔️ Unit Abilities

Every unit card has a special trait. Units with certain abilities can even "bring friends" to the battlefield in a single move.

### **Standard**
Pure power with no special effects.

### **Hero**
**The Ultimate Card.** Immune to all effects (Weather, Scorch, Horns, etc.). Nothing can touch its power.

### **Tight Bond**
Power in numbers! If you have multiple cards with this ability in one row, their power grows exponentially (2 cards = x4 power, 3 cards = x9 power).

### **Morale Boost**
A leader on the field. Every **other** unit in the same row gets **+1 Power**. These bonuses **stack** if you have multiple Morale units!

### **Commander's Horn (Unit Version)**
**Row-Locked Boost**: Doubles (**x2**) the score of the specific row this unit is played in. Does not stack with other Horns in the same row.

### **Medic**
**Targeted Reinforcement**: Choose **one specific card** from your deck and play it onto the battlefield instantly.

### **Spy**
**Tactical Trade**: Played on the **opponent's** board (giving them points), but allows you to choose **two specific cards** from your deck to play instantly on your own board.

### **Muster**
**Army Call**: Play one copy, and every other related unit in its "Muster Group" joins the fight instantly from your deck.

### **Berserker**
**Dormant Power**: A unit that transforms into a high-powered card if a **Mardroeme** catalyst is present in its row.

### **Mardroeme (Unit Version)**
**Row-Locked Catalyst**: Instantly triggers the transformation of all **Berserkers** in the specific row this unit is played in.

---

## ✨ Special Cards (The Battle for Abilities)

Special cards control the baseline rules of the match. Unlike Units, these are **Flexible**—you choose exactly which row to target when you play them.

### **Commander's Horn (Special Card)**
**Choice Multiplier (ID 137)**: Choose **any** row to double its total power (x2). Does not stack with Unit Horns.

### **Mardroeme (Special Card)**
**Choice Catalyst (ID 136)**: Choose **any** row to trigger all Berserker transformations within it.

### **Scorch**
**The Silencer (ID 139)**: Targeted Disable. Choose an opponent's ability type (like Tight Bond) to nullify all its bonuses for the round. Scorched cards only contribute their base power.

### **Decoy**
**The Counter-Move (ID 138)**: Targeted Enable. Use this to protect or re-enable an ability that your opponent has Scorched.

---

## ☁️ Environment (Weather)

Weather cards set the baseline power of every non-Hero unit in a row to **1**.

*   **Biting Frost (ID 140)**: Freezes the **Melee** row.

*   **Impenetrable Fog (ID 142)**: Blinds the **Ranged** row.

*   **Torrential Rain (ID 143)**: Drowns the **Siege** row.

*   **Skellige Storm (ID 144)**: Sets both the **Ranged** and **Siege** rows to 1.

*   **Clear Weather (ID 141)**: Removes all active weather effects.

---

## 🏛️ The Anatomy of a Round (How your Score is Calculated)

Ever wonder how a few cards turn into a massive score? The game engine follows a strict "Story Order" to calculate every point fairly.

### **Step 1: Setting the Stage**
The Duel begins by looking at the Environment. The engine checks for active **Weather**, and identifies which abilities have been **Scorched** (silenced) or **Decoyed** (protected).

### **Step 2: The Call for Backup**
Next, the engine looks for your **Spies** and **Medics**. It instantly dives into your deck to find the specific reinforcements you chose and pulls them onto the board before the first point is even counted.

### **Step 3: Taking Positions**
Every unit is placed into its combat row (Melee, Ranged, or Siege). If you played a **Spy**, it is handed over to your opponent, giving them the card's power but giving you the reinforcement advantage.

### **Step 4: The Weather Impact ❄️**
Before any bonuses are applied, the **Weather** hits. In any row with a Storm, Fog, or Frost, every unit's power is reduced to **1**. 
*   **The Hero Exception**: Heroes are shielded and keep their full power regardless of the weather.

### **Step 5: Brotherhood & Leadership (The Boosts)**
Now the cards start to help each other! 
*   **Morale Boosts**: Leaders grant +1 Power to every friend in their row.
*   **Tight Bond**: Identical units link up, causing their power to explode exponentially (linking 3 units is much stronger than 3 separate ones).

### **Step 6: Unleashing the Beast**
If a **Mardroeme** catalyst is on the row, your **Berserker** units add their high transformation power to the total.

### **Step 7: The Final Charge (The Horn) 👑**
As the very last act of the round, the **Commander’s Horn** is sounded. If a Horn is present (either as a unit or a special card), the **ENTIRE** total of that row—including all the boosts and transformations—is **doubled (x2)**.

### **Step 8: The Final Tally**
The scores from all three rows and your Hero shields are added up. The player with the highest total is declared the winner of the round.

---

## ⚖️ Rules of Engagement (The Arena Law)

The Arena uses automated protocol checks to ensure total fairness. If you violate any of the following technical rules, the engine will instantly disqualify you and award the match victory to your opponent.

### **1. Special Card Limits**
There are two strict limits on Special Cards (Weather, Horns, Scorch, Decoy):
*   **Deck Limit**: Your total deck can only contain a maximum of **3 Special Cards**.
*   **Round Limit**: You can only play **ONE** Special Card per round. If you play two special cards in a single round, the protocol flags it as an illegal play and you lose the match.

### **2. The 10-Card "Energy" Cap**
The Gwent Arena limited resource model allows you to manually play a **total of 10 cards** across the complete 3-round match. 
*   **What Counts**: Every card you manually commit and reveal as part of your turn counts toward this limit.
*   **What DOES NOT Count**: Any "bonus" cards brought onto the board by abilities like **Muster**, **Medic**, or **Spy** are excluded. You can have 20+ units on the field, as long as you only spent 10 "Turns" to put them there.
*   *Note: Choose your manual deployments wisely—going over the 10-reveal limit means an instant loss.*

### **3. Card Verification & Ownership**
The blockchain verifies your deck at every step. You will be disqualified if:
*   You attempt to play a card ID that is not between **1 and 144**.
*   You attempt to play more copies of a card than you actually own or registered when you entered the Arena.
*   **Hash Mismatch**: If the cards you "Reveal" do not match the secure "Commit" hash you made at the start, it is considered a forfeit.

### **4. The Time-Lock Forfeit**
Matches are governed by a strict clock.
*   **Commit Deadline (3 Days)**: If you fail to commit your strategy, the match is cancelled or awarded to the active player.
*   **Reveal Deadline (1 Day)**: Once both players commit, you have 24 hours to reveal your cards. If you miss this window, the protocol awards the match win to your opponent.
