# 🏛️ Protocol Governance & Security

The Decentralized Gwent Protocol is governed by its users. All parameters, logic upgrades, and treasury management are controlled by the Gwent DAO.

---

## 🗳️ The Voting Model

The protocol uses the **Governor + Timelock** architecture (OpenZeppelin standard) with specific parameters tuned for balanced growth:

| Parameter | Value | Description |
|---|---|---|
| **Voting Delay** | 7,200 blocks (~1 day) | Period between proposal and vote start. |
| **Voting Period** | 50,400 blocks (~7 days) | Time allowed for users to cast votes. |
| **Quorum** | 4% | Minimum % of Game Currency (ID 0) supply required to pass. |
| **Proposal Threshold** | 10 ether | Units of Game Currency (ID 0) required to submit a proposal. |
| **Timelock Delay** | 2 days | Minimum delay before execution (Veto Window). |

---

## 🛡️ The Security Council (Guardian Veto)

To protect the protocol from "Flash Loan Governance Attacks" or malicious proposals, a dedicated **Security Council** exists.

### The Mechanism
- **Role**: `GUARDIAN_ROLE`
- **The 66% Rule**: A proposal is successfully cancelled if **2 out of 3** (or 66%) of the active Guardians vote to veto.
- **Veto Window**: Guardians can only veto an active proposal or one that is sitting in the Timelock queue. Once the Timelock delay expires and a proposal is executed, it can no longer be vetoed.

### Goal of the Veto
The veto is a "Circuit Breaker." It is intended to be used only in emergencies where a proposal clearly threatens the integrity of the protocol.

---

## 🔧 Managing the Protocol

All administrative functions on the `Arena`, `System`, and `Token` contracts are restricted to the **Timelock Address**.

### Example Governance Actions
- **Upgrading Logic**: Replacing the `GwentArena` logic contract with a V2 via UUPS.
- **Adjusting Fees**: Updating the `houseFeePercent` in the Arena.
- **Airdrops/Treasury**: Minting tokens for community rewards or tournament prize pools.

---

## 🏁 How to Participate

1. **Self-Delegate**: Tokens do not grant voting power automatically. You must call `delegate(address(this))` on the `GwentCardToken` contract to register your **Game Currency (ID 0)** balance for voting.
2. **Propose**: Use the Governor's `propose()` function.
3. **Vote**: Use the `castVote()` or `castVoteWithReason()` functions during the 7-day voting window.

---

*Gwent Governance Specification - V1.1*
