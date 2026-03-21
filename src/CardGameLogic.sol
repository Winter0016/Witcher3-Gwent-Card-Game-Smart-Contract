// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CardRegistryPure} from "./CardRegistryPure.sol";
import {Match} from "./GwentTypes.sol";

library CardGameLogic {
    struct RowState {
        uint16[] ids;
        uint256[] amounts;
        bool hasSpecial;
        uint256 moraleCount;
    }

    struct GlobalWeather {
        bool bitingFrost;
        bool impenetrableFog;
        bool torrentialRain;
        bool skelligeStorm;
    }

    struct BoardState {
        RowState close;
        RowState ranged;
        RowState siege;
        bool isInvalid;
    }
    // enum ScorchAndDecoyChoice {
    //     Berserker,
    //     Transform_After_Death,
    //     Commander_horn,
    //     Medic,
    //     Morale_Boost,
    //     Mardroeme,
    //     Muster,
    //     Summon,
    //     Spy,
    //     Tight_Bond
    // }

    /// @notice Decodes the target row for a card, respecting Agile/Special flexibility.
    function getTargetRow(
        uint256 packedCard,
        CardRegistryPure.Card memory card
    ) public pure returns (uint8 rowIndex) {
        uint8 encodedRow = uint8((packedCard >> 16) & 0x03);

        if (card.unitType == CardRegistryPure.UnitType.Agile) {
            return (encodedRow == 1) ? 1 : 0;
        }

        if (card.unitType == CardRegistryPure.UnitType.Special) {
            return encodedRow > 2 ? 0 : encodedRow;
        }

        if (card.unitType == CardRegistryPure.UnitType.Close_Combat) return 0;
        if (card.unitType == CardRegistryPure.UnitType.Ranged) return 1;
        if (card.unitType == CardRegistryPure.UnitType.Siege) return 2;
        if (card.unitType == CardRegistryPure.UnitType.Special)
            return encodedRow;

        return 0;
    }
    function _ScorchAndDecoyChoice(
        uint8 _choice
    ) internal pure returns (CardRegistryPure.Ability choice) {
        if (_choice == 0) return CardRegistryPure.Ability.Berserker;
        if (_choice == 1) return CardRegistryPure.Ability.Commander_horn;
        if (_choice == 2) return CardRegistryPure.Ability.Medic;
        if (_choice == 3) return CardRegistryPure.Ability.Morale_Boost;
        if (_choice == 4) return CardRegistryPure.Ability.Mardroeme;
        if (_choice == 5) return CardRegistryPure.Ability.Muster;
        if (_choice == 6) return CardRegistryPure.Ability.Summon;
        if (_choice == 7) return CardRegistryPure.Ability.Spy;
        if (_choice == 8) return CardRegistryPure.Ability.Tight_Bond;
        return CardRegistryPure.Ability.None;
    }

    function _AbilityProcess(
        uint16 id,
        CardRegistryPure.Card memory card,
        uint16 amount,
        CardRegistryPure.Ability Decoy,
        CardRegistryPure.Ability Scorch,
        uint256[] memory remaining,
        uint256 spy1,
        uint256 spy2
    )
        internal
        pure
        returns (
            uint256 power_update,
            uint256 rowcount_update,
            uint256 commander_horn,
            uint256 morale_boost,
            uint256 mardroeme,
            uint256 spy,
            uint256[] memory remaining_update
        )
    {
        uint8 ability = uint8(card.ability);
        uint8 decoy = uint8(Decoy);
        uint8 scorch = uint8(Scorch);
        uint256 p = card.power;
        uint256 bp = card.berserker_power;

        uint256 packedM = 0;
        if (ability == 8 || ability == 9) {
            packedM = CardRegistryPure.getMusterMembersByID(id);
        }

        assembly {
            // Check Scorch Condition first
            if and(eq(ability, scorch), iszero(eq(ability, decoy))) {
                switch ability
                case 10 {
                    spy := amount
                }
                default {
                    power_update := mul(p, amount)
                    rowcount_update := amount
                }
            }
            if iszero(and(eq(ability, scorch), iszero(eq(ability, decoy)))) {
                switch ability
                case 1 {
                    // Berserker
                    power_update := mul(p, amount)
                    rowcount_update := amount
                    let extra := shl(24, sub(mul(bp, amount), mul(p, amount)))
                    power_update := add(power_update, extra)
                }
                case 2 {
                    commander_horn := 1
                }
                case 4 {
                    power_update := mul(p, amount)
                }
                case 6 {
                    power_update := mul(p, amount)
                    morale_boost := amount
                    rowcount_update := amount
                }
                case 7 {
                    power_update := mul(p, amount)
                    rowcount_update := amount
                    mardroeme := amount
                }
                case 10 {
                    spy := amount
                }
                case 11 {
                    power_update := mul(mul(amount, p), 2)
                    rowcount_update := amount
                }
                default {}
                if or(eq(ability, 8), eq(ability, 9)) {
                    let countM := and(packedM, 0xFF)
                    let final_amount := amount
                    let s_power := 0
                    for {
                        let j := 0
                    } lt(j, countM) {
                        j := add(j, 1)
                    } {
                        let mId := and(shr(add(8, mul(j, 16)), packedM), 0xFFFF)
                        let mPtr := add(remaining, add(32, mul(mId, 32)))
                        let mAmount := mload(mPtr)
                        if gt(mAmount, 0) {
                            final_amount := add(final_amount, mAmount)
                            mstore(mPtr, 0)
                            if eq(ability, 9) {
                                // Summon extra power
                                s_power := add(s_power, mul(mul(mAmount, p), 2))
                            }
                        }
                    }
                    if eq(ability, 8) {
                        // Muster final power
                        power_update := mul(final_amount, p)
                    }
                    if eq(ability, 9) {
                        // Summon power
                        power_update := add(mul(amount, p), s_power)
                    }
                    rowcount_update := final_amount
                }
            }
        }

        if (ability == 10 || ability == 5) {
            // Spy or Medic
            if (spy1 > 0) {
                (, CardRegistryPure.Card memory c, , , , , ) = unpack(spy1);
                power_update += c.power * amount;
                rowcount_update += amount;
                remaining[spy1] -= amount;
            }
            if (ability == 10 && spy2 > 0) {
                (, CardRegistryPure.Card memory c, , , , , ) = unpack(spy2);
                power_update += c.power * amount;
                rowcount_update += amount;
                remaining[spy2] -= amount;
            }
        }

        remaining_update = remaining;
    }

    function unpack(
        uint256 packed
    )
        public
        pure
        returns (
            uint16 id,
            CardRegistryPure.Card memory card,
            uint8 row,
            uint8 scorchChoice,
            uint256 spy1,
            uint256 spy2,
            uint16 amount
        )
    {
        id = uint16(packed & 0xFFFF);
        card = CardRegistryPure.getCard(id);
        row = getTargetRow(packed, card);
        scorchChoice = uint8((packed >> 32) & 0xFF);
        spy1 = uint256((packed >> 48) & 0xFFFF);
        spy2 = uint256((packed >> 64) & 0xFFFF);
        amount = uint16((packed >> 80) & 0xFFFF);
    }

    function _calculateRoundCard(
        uint256[] memory playerpacked,
        uint256[] memory remaining,
        CardRegistryPure.Ability Decoy,
        CardRegistryPure.Ability Scorch,
        uint256 commander_horn,
        uint256 mardroeme
    )
        internal
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256[] memory
        )
    {
        uint256 morale_boost = 0;
        uint256 rowcount = 0;
        uint256 power = 0;
        uint256 spy = 0;

        for (uint256 i = 0; i < playerpacked.length; i++) {
            (
                uint16 id,
                CardRegistryPure.Card memory card,
                uint8 row,
                uint8 scorchChoice,
                uint256 spy1,
                uint256 spy2,
                uint16 amount
            ) = unpack(playerpacked[i]);
            if (card.ability == CardRegistryPure.Ability.Hero) {
                power += card.power * amount;
            } else {
                (
                    uint256 power_update,
                    uint256 rowcount_update,
                    uint256 commander_horn_update,
                    uint256 morale_boost_update,
                    uint256 mardroeme_update,
                    uint256 spy_update,
                    uint256[] memory remaining_update
                ) = _AbilityProcess(
                        id,
                        card,
                        amount,
                        Decoy,
                        Scorch,
                        remaining,
                        spy1,
                        spy2
                    );
                power += power_update << (8 * (row + 1));
                rowcount += rowcount_update << (8 * (row + 1));
                if (commander_horn >> 8 == 0) {
                    commander_horn += commander_horn_update << (8 * (row + 1));
                }
                morale_boost += morale_boost_update << (8 * (row + 1));
                mardroeme += mardroeme_update << (8 * (row + 1));
                spy += spy_update << (8 * (row + 1));
                remaining = remaining_update;
            }
        }
        return (
            power,
            rowcount,
            commander_horn,
            morale_boost,
            mardroeme,
            spy,
            remaining
        );
    }

    function _RoundWinner(
        uint256[] memory p1Remaining,
        uint256[] memory p2Remaining,
        uint256[] memory player1Packed,
        uint256[] memory player2Packed,
        uint256 player1neutral,
        uint256 player2neutral
    ) internal pure returns (bool, uint256[] memory, uint256[] memory) {
        (
            uint16 p1Nid,
            CardRegistryPure.Card memory p1Ncard,
            uint8 p1Nrow,
            uint8 p1Nchoice,
            ,
            ,
            uint16 p1Namount
        ) = unpack(player1neutral);
        (
            uint16 p2Nid,
            CardRegistryPure.Card memory p2Ncard,
            uint8 p2Nrow,
            uint8 p2Nchoice,
            ,
            ,
            uint16 p2Namount
        ) = unpack(player2neutral);

        CardRegistryPure.Ability Decoy;
        CardRegistryPure.Ability Scorch;
        uint8 weatherMask;

        // Process Player 1 and Player 2 Specials
        {
            (
                CardRegistryPure.Ability d1,
                CardRegistryPure.Ability s1,
                uint256 h1,
                uint256 m1,
                uint8 w1
            ) = _processNeutral(p1Nid, p1Nchoice, p1Nrow);
            (
                CardRegistryPure.Ability d2,
                CardRegistryPure.Ability s2,
                uint256 h2,
                uint256 m2,
                uint8 w2
            ) = _processNeutral(p2Nid, p2Nchoice, p2Nrow);

            Decoy = d1 == CardRegistryPure.Ability.None ? d2 : d1;
            Scorch = s1 == CardRegistryPure.Ability.None ? s2 : s1;
            // commander_horn = h1 + h2;
            // mardroeme = m1 + m2;

            if (w1 != 8 && w2 != 8) {
                // If NO Clear Weather (flag 8)
                weatherMask = w1 | w2;
            }
            (
                uint256 p1Power,
                uint256 p1Rowcount,
                uint256 p1CommanderHorn,
                uint256 p1MoraleBoost,
                uint256 p1Mardroeme,
                uint256 p1Spy,
                uint256[] memory p1Remaining_update
            ) = _calculateRoundCard(
                    player1Packed,
                    p1Remaining,
                    Decoy,
                    Scorch,
                    h1,
                    m1
                );
            (
                uint256 p2Power,
                uint256 p2Rowcount,
                uint256 p2CommanderHorn,
                uint256 p2MoraleBoost,
                uint256 p2Mardroeme,
                uint256 p2Spy,
                uint256[] memory p2Remaining_update
            ) = _calculateRoundCard(
                    player2Packed,
                    p2Remaining,
                    Decoy,
                    Scorch,
                    h2,
                    m2
                );
            p1Power += p2Spy;
            p1Rowcount += p2Spy;
            p2Power += p1Spy;
            p2Rowcount += p1Spy;

            p1Power = calculateFinalPower(
                p1Power,
                p1Rowcount,
                p1MoraleBoost,
                p1Mardroeme,
                p1CommanderHorn
            );
            p2Power = calculateFinalPower(
                p2Power,
                p2Rowcount,
                p2MoraleBoost,
                p2Mardroeme,
                p2CommanderHorn
            );

            if ((weatherMask & 1) != 0) {
                p1Power =
                    (p1Power & ~(uint256(0xFF) << 8)) | // ~ means NOT => clear data , swap 1 to 0 and 0 to 0
                    (p1Rowcount & (uint256(0xFF) << 8));
                p2Power =
                    (p2Power & ~(uint256(0xFF) << 8)) |
                    (p2Rowcount & (uint256(0xFF) << 8));
            }
            if ((weatherMask & 2) != 0) {
                p1Power =
                    (p1Power & ~(uint256(0xFF) << 16)) |
                    (p1Rowcount & (uint256(0xFF) << 16));
                p2Power =
                    (p2Power & ~(uint256(0xFF) << 16)) |
                    (p2Rowcount & (uint256(0xFF) << 16));
            }
            if ((weatherMask & 4) != 0) {
                p1Power =
                    (p1Power & ~(uint256(0xFF) << 24)) |
                    (p1Rowcount & (uint256(0xFF) << 24));
                p2Power =
                    (p2Power & ~(uint256(0xFF) << 24)) |
                    (p2Rowcount & (uint256(0xFF) << 24));
            }
            return (p1Power > p2Power, p1Remaining_update, p2Remaining_update);
        }
    }

    function FindWinner(
        Match memory match_,
        uint256[] memory p1remaining,
        uint256[] memory p2remaining,
        uint256[6] memory neutrals
    ) external pure returns (uint8) {
        (
            bool player1win_round1,
            uint256[] memory p1remaining_round1,
            uint256[] memory p2remaining_round1
        ) = _RoundWinner(
                p1remaining,
                p2remaining,
                match_.player1R1Packed,
                match_.player2R1Packed,
                neutrals[0],
                neutrals[1]
            );

        (
            bool player1win_round2,
            uint256[] memory p1remaining_round2,
            uint256[] memory p2remaining_round2
        ) = _RoundWinner(
                p1remaining_round1,
                p2remaining_round1,
                match_.player1R2Packed,
                match_.player2R2Packed,
                neutrals[2],
                neutrals[3]
            );

        (bool player1win_round3, , ) = _RoundWinner(
            p1remaining_round2,
            p2remaining_round2,
            match_.player1R3Packed,
            match_.player2R3Packed,
            neutrals[4],
            neutrals[5]
        );
        uint8 winner = 3;
        if (player1win_round1) {
            winner += 1;
        }
        if (player1win_round2) {
            winner += 1;
        }
        if (player1win_round3) {
            winner += 1;
        }
        return winner;
    }
    // Placeholder simple scoring

    /**
     * @notice High-speed jump table for processing Special/Weather cards (IDs 136-144).
     */
    function _processNeutral(
        uint16 nid,
        uint8 choice,
        uint8 row
    )
        internal
        pure
        returns (
            CardRegistryPure.Ability decoy,
            CardRegistryPure.Ability scorch,
            uint256 horn,
            uint256 mardroeme,
            uint8 weather
        )
    {
        assembly {
            switch nid
            case 138 {
                // Decoy
                let ability := 0
                switch choice
                case 0 {
                    ability := 1
                } // Berserker
                case 1 {
                    ability := 2
                } // Commander_horn
                case 2 {
                    ability := 5
                } // Medic
                case 3 {
                    ability := 6
                } // Morale_Boost
                case 4 {
                    ability := 7
                } // Mardroeme
                case 5 {
                    ability := 8
                } // Muster
                case 6 {
                    ability := 9
                } // Summon
                case 7 {
                    ability := 10
                } // Spy
                case 8 {
                    ability := 11
                } // Tight_Bond
                decoy := ability
            }
            case 139 {
                // Scorch
                let ability := 0
                switch choice
                case 0 {
                    ability := 1
                }
                case 1 {
                    ability := 2
                }
                case 2 {
                    ability := 5
                }
                case 3 {
                    ability := 6
                }
                case 4 {
                    ability := 7
                }
                case 5 {
                    ability := 8
                }
                case 6 {
                    ability := 9
                }
                case 7 {
                    ability := 10
                }
                case 8 {
                    ability := 11
                }
                scorch := ability
            }
            case 137 {
                // Commander's Horn
                horn := shl(mul(8, add(row, 1)), 1)
            }
            case 136 {
                // Mardroeme
                mardroeme := shl(mul(8, add(row, 1)), 1)
            }
            case 140 {
                weather := 1
            } // Frost (Row 0)
            case 142 {
                weather := 2
            } // Fog (Row 1)
            case 143 {
                weather := 4
            } // Rain (Row 2)
            case 144 {
                weather := 6
            } // Storm (Row 1+2)
            case 141 {
                weather := 8
            } // Clear flag
        }
    }

    function calculateFinalPower(
        uint256 pVal,
        uint256 rVal,
        uint256 mBoost,
        uint256 mardroeme,
        uint256 cHorn
    ) internal pure returns (uint256 result) {
        result = pVal;
        for (uint256 i = 1; i <= 3; i++) {
            uint256 shift = i * 8;
            uint256 extraShift = shift + 24;

            uint256 p = (pVal >> shift) & 0xFF;
            uint256 r = (rVal >> shift) & 0xFF;
            uint256 m = (mBoost >> shift) & 0xFF;
            uint256 h = (cHorn >> shift) & 0xFF;
            uint256 mard = (mardroeme >> shift) & 0xFF;
            uint256 extra = (pVal >> extraShift) & 0xFF;

            uint256 total = p + (r - m) * m + (mard * extra);
            if (h > 0) total *= 2;
            if (total > 255) total = 255;

            result = (result & ~(uint256(0xFF) << shift)) | (total << shift);
        }
    }
}
