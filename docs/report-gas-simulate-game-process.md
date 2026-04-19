# 🎴 Gwent Arena: Gas Simulation Report
**Network**: Arbitrum Sepolia  
**Tester Address**: `0xd12898E34E6Fe299B833a87398597D21BF358014`

---

## 🎒 Phase 1: Onboarding & Card Acquisition
| Step | Action | Gas Used | Fee (ETH) | USD (est) |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Buy Token** (Native ETH swap) | 96,996 | 0.00000195 | $0.0068 |
| **2** | **Open Pack** (socialtale: 4 packs => 20 cards) | 151,237 | 0.00000302 | $0.0106 |
| **3** | **Claim Roll** (Claim 20 cards) | 327,638 | 0.00000656 | $0.0230 |
| **4** | **Open Pack** (scoialtale: 1 pack => 5 cards) | 184,329 | 0.00000368 | $0.0129 |
| **5** | **Claim Roll** (Claim 5 cards) | 99,733 | 0.00000199 | $0.0070 |

**Transaction Hashes (Phase 1):**
- Step 1: `0x06368f6223c16ef72893f84181bb6d21285618fb962c1fd2cb2651afca93a64e`
- Step 2: `0xb64f72701a548bd2f1c4a730ca5d1f61b95dceb2d7e6d4fd086d5c8bc15b8c30`
- Step 3: `0xcb0a2340acdde1ecfa5799f6e38ce331d6e31c1077528647f21712cb39b35b92`
- Step 4: `0x17e175889e74e934acd26b2d3923796be2c97aa1dc1a057a15457611a87c8ec2`
- Step 5: `0x286f0d6e61b0006044d2845a40728249aefd08819304bff2a3a3ac459ddee53e`

---

## ⚔️ Phase 2: Arena Entry & Matchmaking
| Step | Action | Gas Used | Fee (ETH) | USD (est) |
| :--- | :--- | :--- | :--- | :--- |
| **6** | **Player 1 Enter Arena** (24 cards) | 346,758 | 0.00000693 | $0.0243 |
| **7** | **Player 2 Enter Arena** (25 cards) | 325,889 | 0.00000651 | $0.0228 |
| **8** | **Automation: Matchmaking** | ~100k | 0.00000646 | $0.0226 |

**Transaction Hashes (Phase 2):**
- Step 6: `0x5df848a9bbc6adab0c81f1f583cba4e96f86424f9c727cfbb1bc33ca5ac15cec`
- Step 7: `0x101569ebfbab496e1a9fc90ecacbc51b1acbb0cc33dcec580e7286ed969357a7`
- Step 8: `0x81f5d21b9af05af4bb1c71292b1a4c0fe34ff2271253f734a3f59b36ddf93258`

---

## 🃏 Phase 3: Match Play (Commit & Reveal)
### Commit Moves
- **P1 (Northern Realms)**: `0x227de187b283355483f3fcd80cd8551d00d37931b6bdf60048934a81dd4ce6c5` (57,318 Gas)
- **P2 (Scoia'tael)**: `0xd8869208782d72c478c551765876163ce9e9e1f9a1465baa135ad47af9d0e2a6` (67,753 Gas)

### Reveal Moves
- **P1 Reveal**: `0x29ca7fdd3fa07cf52a42fdfb98d828873330d3fc8b5bdc82edca56c8ffb6e8c2` (184,386 Gas)
- **P2 Reveal**: `0xa12d257fb1f087892ab1c83498e4fbc747e2739c93ebf34f692eacd6b4e74dd2` (192,199 Gas)

---

## 🏁 Phase 4: Resolution & Rewards
### 🏆 Match #0 Scoreboard
| Player | Round 1 | Round 2 | Round 3 | **Total Score** | Result |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **P1 (Northern)** | 4 | 13 | 15 | **32** | ❌ Loss |
| **P2 (Scoia'tael)**| 10 | 15 | 19 | **44** | 🏆 **Winner** |

| Step | Action | Gas Used | Fee (ETH) | USD (est) |
| :--- | :--- | :--- | :--- | :--- |
| **13**| **Automation: Resolution** | 498,521 | 0.00001075 | $0.0376 |
| **14**| **P2 Claim Reward** | 85,451 | 0.00000170 | $0.0060 |

**Transaction Hashes (Phase 4):**
- Step 13: `0xa9c47ad4a83e8b1a1334bce000f86508e006e90bbe6eb4cfa78a834c5514d350`
- Step 14: `0x154a19bc849e35b2cc4a1c94eaf9db891ed9282fc99e05264c38a84e5433f2ba`

---

## 🏛️ ECONOMY & AUTOMATION SUMMARY (THE END)

### 1. Protocol Revenue
- **House Earned**: **2 Tokens** (Match #0 Fee)
- *Verification: `cast call $arena "pendingFees()(uint256)"`*

### 2. Chainlink Automation Footprint
| Upkeep Transaction | LINK Cost | USD Cost | gasUsed |
| :--- | :--- | :--- | :--- |
| Matchmaking (Step 8) | 0.01228 LINK | ~$0.18 USD | ~100,000 |
| Resolution (Step 13) | 0.01431 LINK | ~$0.21 USD | 498,521 |
| **TOTAL** | **0.02659 LINK** | **~$0.39 USD** | |

### 3. Chainlink Resolution Evidence
| Attribute | Value | Note |
| :--- | :--- | :--- |
| **Status** | ✅ **Success** | Match resolved successfully |
| **Computation (Logic)** | **498,521 Gas** | Exhaustive deck integrity check |
| **Network Overhead** | **106,139 Gas** | Automation node premium |

### 4. 💰 FINAL TALLY: Player 2 (Full Lifecycle)
| Category | ETH Cost (USD) | LINK Cost (USD) |
| :--- | :--- | :--- |
| **Prep (Packs & Cards)** | $0.05926 | $0.00000 |
| **Arena Entry** | $0.02281 | $0.00000 |
| **In-Game (Commit & Reveal)** | $0.01822 | $0.00000 |
| **Automated Logistics (Share)** | $0.03014 | $0.19739 |
| **Winnings Claim** | $0.00598 | $0.00000 |
| **GRAND TOTAL** | **$0.13641** | **$0.19739** |

> [!NOTE] 
> **Total Player Expense**: **~$0.334 USD**  
> **Total Player Earnings**: **98 Tokens** (Profit: +48 Tokens)
