// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CardRegistryPure} from "./CardRegistryPure.sol";
import {Match, Ability, UnitType, Faction} from "./GwentTypes.sol";

library CardGameLogic {
    struct CardData {
        uint16 id;
        CardRegistryPure.Card card;
        uint8 row;
        uint8 scorchChoice;
        uint256 spy1;
        uint256 spy2;
        uint16 amount;
    }

    struct RoundStats {
        uint256 power; // Packed 4 bytes
        uint256 rowcount; // Packed 4 bytes
        uint256 commanderHorn; // Packed 4 bytes
        uint256 moraleBoost; // Packed 4 bytes
        uint256 mardroeme; // Packed 4 bytes
        uint256 spyPower; // Packed 4 bytes
        uint256 spyCount; // Packed 4 bytes
        uint256 transPower; // Packed 4 bytes
        uint256 bondCounts; // Memory pointer to uint256[145]
    }

    struct NeutralEffects {
        Ability decoy;
        Ability scorch;
        uint256 horn;
        uint256 mardroeme;
        uint8 weather;
    }

    /// @notice Decodes the target row for a card, respecting Agile/Special flexibility.
    function getTargetRow(
        uint256 packedCard,
        CardRegistryPure.Card memory card
    ) public pure returns (uint8 rowIndex) {
        uint8 encodedRow = uint8((packedCard >> 16) & 0xFF);

        if (card.unitType == UnitType.Agile) {
            return (encodedRow == 1) ? 1 : 0;
        }

        if (card.unitType == UnitType.Special) {
            return encodedRow > 2 ? 0 : encodedRow;
        }

        if (card.unitType == UnitType.Close_Combat) return 0;
        if (card.unitType == UnitType.Ranged) return 1;
        if (card.unitType == UnitType.Siege) return 2;
        if (card.unitType == UnitType.Special) return encodedRow;

        return 0;
    }
    // function _ScorchAndDecoyChoice(
    //     uint8 _choice
    // ) internal pure returns (Ability choice) {
    //     if (_choice == 0) return Ability.Berserker;
    //     if (_choice == 1) return Ability.Commander_horn;
    //     if (_choice == 2) return Ability.Medic;
    //     if (_choice == 3) return Ability.Morale_Boost;
    //     if (_choice == 4) return Ability.Muster;
    //     if (_choice == 5) return Ability.Summon;
    //     if (_choice == 6) return Ability.Spy;
    //     if (_choice == 7) return Ability.Tight_Bond;
    //     return Ability.None;
    // }

    function _AbilityProcess(
        CardData memory data,
        Ability Decoy,
        Ability Scorch,
        uint256[] memory remaining,
        RoundStats memory stats
    ) internal pure {
        // --- Entrance Function ---
        // Delegates logic to specialized units to maintain 100% stack safety.
        _processCombatLogic(data, Decoy, Scorch, stats);
        _executeSpecialAbilities(data, Decoy, Scorch, remaining, stats);
    }

    /**
     * @notice Handles scoring, row-counts, and basic unit buffs.
     * Isolated into its own scope to manage stack depth.
     */
    function _processCombatLogic(
        CardData memory data,
        Ability Decoy,
        Ability Scorch,
        RoundStats memory stats
    ) internal pure {
        assembly {
            /**
             * RoundStats Memory Layout (32-byte slots):
             * ptr + 0   : power          (byte-packed: Hero=0, Row0=8, Row1=16, Row2=24)
             * ptr + 32  : rowcount       (byte-packed: Row0=8, Row1=16, Row2=24)
             * ptr + 64  : commanderHorn  (byte-packed: Row0=8, Row1=16, Row2=24)
             * ptr + 96  : moraleBoost    (byte-packed: Row0=8, Row1=16, Row2=24)
             * ptr + 128 : mardroeme      (byte-packed: Row0=8, Row1=16, Row2=24)
             * ptr + 160 : spyPower       (byte-packed: Row0=8, Row1=16, Row2=24)
             * ptr + 192 : spyCount       (byte-packed: Row0=8, Row1=16, Row2=24)
             * ptr + 224 : transPower     (byte-packed: Row0=8, Row1=16, Row2=24)
             */

            // --- 0. Direct Memory Fetching ---
            // Load variables into Yul stack only when needed to bypass Solidity stack limits.
            let id := and(mload(data), 0xFFFF)
            let cardPtr := mload(add(data, 32))
            let ability := mload(add(cardPtr, 64))
            let unitType := mload(add(cardPtr, 96))
            let p := mload(cardPtr)
            let amount := mload(add(data, 192))
            let shift := mul(64, add(mload(add(data, 64)), 1))
            let decoy := Decoy
            let scorch := Scorch
            function update_stat(ptr, off, val, s) {
                if gt(val, 0) {
                    mstore(
                        add(ptr, off),
                        add(mload(add(ptr, off)), shl(s, val))
                    )
                }
            }

            function update_count(ptr, val, s, ut) {
                if and(gt(val, 0), lt(ut, 4)) {
                    mstore(add(ptr, 32), add(mload(add(ptr, 32)), shl(s, val)))
                }
            }

            function update_limit(ptr, off, s) {
                let current := shr(s, mload(add(ptr, off)))
                if iszero(and(current, 0xFFFFFFFFFFFFFFFF)) {
                    mstore(add(ptr, off), add(mload(add(ptr, off)), shl(s, 1)))
                }
            }

            // --- 1. Scorch Condition Check ---
            if and(eq(ability, scorch), iszero(eq(ability, decoy))) {
                switch ability
                case 10 {
                    // Spy logic under Scorch
                    update_stat(stats, 160, mul(p, amount), shift)
                    update_stat(stats, 192, amount, shift)
                }
                default {
                    update_stat(stats, 0, mul(p, amount), shift)
                    update_count(stats, amount, shift, unitType)
                }
            }

            // --- 2. Main Scoring & Buff Logic ---
            if iszero(and(eq(ability, scorch), iszero(eq(ability, decoy)))) {
                switch ability
                case 1 {
                    // Berserker
                    update_stat(stats, 0, mul(p, amount), shift)
                    update_count(stats, amount, shift, unitType)
                    let bp := mload(add(cardPtr, 32))
                    update_stat(
                        stats,
                        224,
                        sub(mul(bp, amount), mul(p, amount)),
                        shift
                    )
                }
                case 2 {
                    // Horn
                    update_stat(stats, 0, mul(p, amount), shift)
                    update_count(stats, amount, shift, unitType)
                    update_limit(stats, 64, shift)
                }
                case 4 {
                    // Hero: contribute to neutral bit-slot (immune)
                    update_stat(stats, 0, mul(p, amount), 0)
                }
                case 6 {
                    // Morale Boost
                    update_stat(stats, 0, mul(p, amount), shift)
                    update_count(stats, amount, shift, unitType)
                    update_stat(stats, 96, amount, shift)
                }
                case 7 {
                    // Mardroeme
                    update_stat(stats, 0, mul(p, amount), shift)
                    update_count(stats, amount, shift, unitType)
                    update_limit(stats, 128, shift)
                }
                case 11 {
                    // --- Tight Bond (Marginal Gain Logic: 2n-1) ---
                    let idCountsPtr := mload(add(stats, 256))
                    let countPtr := add(add(idCountsPtr, 32), mul(id, 32))
                    let currentCount := mload(countPtr)

                    // Logic: Group Power = P * (NewCount^2).
                    // Marginal Gain = P * (NewCount^2 - CurrentCount^2) = P * (2*NewCount - amount) * amount
                    // For single card plays (amount=1), this is simply P * (2*NewCount - 1)
                    let newCount := add(currentCount, amount)
                    mstore(countPtr, newCount)

                    let multiplier := sub(mul(2, newCount), amount)
                    let p_gain := mul(p, mul(multiplier, amount))

                    update_stat(stats, 0, p_gain, shift)
                    update_count(stats, amount, shift, unitType)
                }
                case 5 {
                    // Medic
                    update_stat(stats, 0, mul(p, amount), shift)
                    update_count(stats, amount, shift, unitType)
                }
                case 10 {
                    // Spy
                    update_stat(stats, 160, mul(p, amount), shift)
                    update_stat(stats, 192, amount, shift)
                }
                case 8 {
                    // Muster handled in special abilities
                }
                default {
                    // Standard Unit
                    update_stat(stats, 0, mul(p, amount), shift)
                    update_count(stats, amount, shift, unitType)
                }
            }
        }
    }

    /**
     * @notice Handles complex recursion and Muster/Summon array searches.
     * Separated to ensure deep recursion doesn't hit stack limits.
     */
    function _executeSpecialAbilities(
        CardData memory data,
        Ability Decoy,
        Ability Scorch,
        uint256[] memory remaining,
        RoundStats memory stats
    ) internal pure {
        // --- 0. Silence Guard ---
        // If the card type is Scorched, its ability cannot trigger.
        if (data.card.ability == Scorch && Scorch != Ability.None) return;

        uint8 ability = uint8(data.card.ability);
        uint8 unitType = uint8(data.card.unitType);

        // --- 1. Muster (Ability 8) ---
        if (ability == 8) {
            uint256 packedM = CardRegistryPure.getMusterMembersByID(data.id);
            uint8 countM = uint8(packedM & 0xFF);
            uint256 totalPower = uint256(data.card.power) * data.amount;
            uint256 totalAmount = data.amount;

            for (uint8 j = 0; j < countM; j++) {
                uint16 mId = uint16((packedM >> (8 + j * 16)) & 0xFFFF);
                uint256 mAmount = remaining[mId];
                if (mAmount > 0) {
                    totalPower += mAmount * CardRegistryPure.getCard(mId).power;
                    totalAmount += mAmount;
                    remaining[mId] = 0;
                }
            }

            uint256 shift = 64 * (data.row + 1);
            assembly {
                function update_stat(ptr, off, val, s) {
                    if gt(val, 0) {
                        mstore(
                            add(ptr, off),
                            add(mload(add(ptr, off)), shl(s, val))
                        )
                    }
                }
                function update_count(ptr, val, s, ut) {
                    if and(gt(val, 0), lt(ut, 4)) {
                        mstore(
                            add(ptr, 32),
                            add(mload(add(ptr, 32)), shl(s, val))
                        )
                    }
                }

                update_stat(stats, 0, totalPower, shift)
                update_count(stats, totalAmount, shift, unitType)
            }
        }

        // --- 2. Spy or Medic Recursion ---
        if (data.spy1 > 0 && (data.spy1 & 0xFFFF) < 145) {
            CardData memory d1 = unpack(data.spy1);
            if (
                d1.card.ability != Ability.Spy &&
                d1.card.ability != Ability.Medic &&
                d1.id < 136 && // Unit only
                remaining[d1.id] > 0
            ) {
                remaining[d1.id] -= 1;
                _AbilityProcess(d1, Decoy, Scorch, remaining, stats);
            }
        }
        if (data.spy2 > 0 && (data.spy2 & 0xFFFF) < 145) {
            CardData memory d2 = unpack(data.spy2);
            if (
                d2.card.ability != Ability.Spy &&
                d2.card.ability != Ability.Medic &&
                d2.id < 136 && // Unit only
                remaining[d2.id] > 0
            ) {
                remaining[d2.id] -= 1;
                _AbilityProcess(d2, Decoy, Scorch, remaining, stats);
            }
        }
    }

    function unpack(uint256 packed) public pure returns (CardData memory data) {
        data.id = uint16(packed & 0xFFFF);
        data.card = CardRegistryPure.getCard(data.id);
        data.row = getTargetRow(packed, data.card);
        data.scorchChoice = uint8((packed >> 24) & 0xFF);
        data.amount = uint16((packed >> 32) & 0xFFFF) > 0
            ? uint16((packed >> 32) & 0xFFFF)
            : 1;
        data.spy1 = (packed >> 48) & 0xFFFF;
        data.spy2 = (packed >> 64) & 0xFFFF;
    }

    function _calculateRoundCard(
        uint256[] memory playerpacked,
        uint256[] memory remaining,
        Ability Decoy,
        Ability Scorch,
        uint256 commander_horn,
        uint256 mardroeme
    ) internal pure returns (RoundStats memory total) {
        total.commanderHorn = commander_horn;
        total.mardroeme = mardroeme;

        // Initialize bond counter array in memory (145 slots of 32 bytes)
        uint256[] memory idCounts = new uint256[](146);
        assembly {
            mstore(add(total, 256), idCounts)
        }

        for (uint256 i = 0; i < playerpacked.length; i++) {
            CardData memory data = unpack(playerpacked[i]);
            _AbilityProcess(data, Decoy, Scorch, remaining, total);
        }
    }

    function calculateFinalPower(
        uint256 pVal,
        uint256 rVal,
        uint256 mBoost,
        uint256 mardroeme,
        uint256 cHorn,
        uint256 tVal
    ) internal pure returns (uint256 result) {
        result = pVal;
        for (uint256 i = 1; i <= 3; i++) {
            uint256 shift = i * 64;

            uint256 p = (pVal >> shift) & 0xFFFFFFFF; // Mask to 32 bits to prevent high-bit leakage
            uint256 r = (rVal >> shift) & 0xFFFFFFFF;
            uint256 m = (mBoost >> shift) & 0xFFFFFFFF;
            uint256 h = (cHorn >> shift) & 0xFFFFFFFF;
            uint256 mard = (mardroeme >> shift) & 0xFFFFFFFF;
            uint256 extra = (tVal >> shift) & 0xFFFFFFFF; // Extract from dedicated slot

            uint256 total = p +
                (m > 0 && r > 0 ? m * (r - 1) : 0) +
                (mard > 0 ? extra : 0);
            if (h > 0) total *= 2;

            result =
                (result & ~(uint256(0xFFFFFFFFFFFFFFFF) << shift)) |
                (total << shift);
        }
    }
    function _RoundWinner(
        uint256[] memory p1Remaining,
        uint256[] memory p2Remaining,
        uint256[] memory player1Packed,
        uint256[] memory player2Packed,
        uint256 player1neutral,
        uint256 player2neutral
    ) internal pure returns (uint8, uint256, uint256) {
        CardData memory p1N = unpack(player1neutral);
        CardData memory p2N = unpack(player2neutral);

        Ability Decoy;
        Ability Scorch;
        uint8 weatherMask;

        // Process Player 1 and Player 2 Specials
        {
            NeutralEffects memory n1 = _processNeutral(
                p1N.id,
                p1N.scorchChoice,
                p1N.row
            );
            NeutralEffects memory n2 = _processNeutral(
                p2N.id,
                p2N.scorchChoice,
                p2N.row
            );

            Decoy = n1.decoy == Ability.None ? n2.decoy : n1.decoy;
            Scorch = n1.scorch == Ability.None ? n2.scorch : n1.scorch;

            if (n1.weather != 8 && n2.weather != 8) {
                // If NO Clear Weather (flag 8)
                weatherMask = n1.weather | n2.weather;
            }

            RoundStats memory p1S = _calculateRoundCard(
                player1Packed,
                p1Remaining,
                Decoy,
                Scorch,
                n1.horn,
                n1.mardroeme
            );
            RoundStats memory p2S = _calculateRoundCard(
                player2Packed,
                p2Remaining,
                Decoy,
                Scorch,
                n2.horn,
                n2.mardroeme
            );

            // Integrate Spies into opponent stats
            p1S.power += p2S.spyPower;
            p1S.rowcount += p2S.spyCount;
            p2S.power += p1S.spyPower;
            p2S.rowcount += p1S.spyCount;

            // Apply weather before multipliers!
            if ((weatherMask & 1) != 0) {
                p1S.power =
                    (p1S.power & ~(uint256(0xFFFFFFFFFFFFFFFF) << 64)) |
                    (p1S.rowcount & (uint256(0xFFFFFFFFFFFFFFFF) << 64));
                p2S.power =
                    (p2S.power & ~(uint256(0xFFFFFFFFFFFFFFFF) << 64)) |
                    (p2S.rowcount & (uint256(0xFFFFFFFFFFFFFFFF) << 64));
            }
            if ((weatherMask & 2) != 0) {
                p1S.power =
                    (p1S.power & ~(uint256(0xFFFFFFFFFFFFFFFF) << 128)) |
                    (p1S.rowcount & (uint256(0xFFFFFFFFFFFFFFFF) << 128));
                p2S.power =
                    (p2S.power & ~(uint256(0xFFFFFFFFFFFFFFFF) << 128)) |
                    (p2S.rowcount & (uint256(0xFFFFFFFFFFFFFFFF) << 128));
            }
            if ((weatherMask & 4) != 0) {
                p1S.power =
                    (p1S.power & ~(uint256(0xFFFFFFFFFFFFFFFF) << 192)) |
                    (p1S.rowcount & (uint256(0xFFFFFFFFFFFFFFFF) << 192));
                p2S.power =
                    (p2S.power & ~(uint256(0xFFFFFFFFFFFFFFFF) << 192)) |
                    (p2S.rowcount & (uint256(0xFFFFFFFFFFFFFFFF) << 192));
            }

            // Apply Spies to base powers
            p1S.power = calculateFinalPower(
                p1S.power,
                p1S.rowcount,
                p1S.moraleBoost,
                p1S.mardroeme,
                p1S.commanderHorn,
                p1S.transPower
            );
            p2S.power = calculateFinalPower(
                p2S.power,
                p2S.rowcount,
                p2S.moraleBoost,
                p2S.mardroeme,
                p2S.commanderHorn,
                p2S.transPower
            );

            // Sum and compare (using full 64-bit masks)
            uint256 p1Score = (p1S.power & 0xFFFFFFFFFFFFFFFF) +
                ((p1S.power >> 64) & 0xFFFFFFFFFFFFFFFF) +
                ((p1S.power >> 128) & 0xFFFFFFFFFFFFFFFF) +
                ((p1S.power >> 192) & 0xFFFFFFFFFFFFFFFF);

            uint256 p2Score = (p2S.power & 0xFFFFFFFFFFFFFFFF) +
                ((p2S.power >> 64) & 0xFFFFFFFFFFFFFFFF) +
                ((p2S.power >> 128) & 0xFFFFFFFFFFFFFFFF) +
                ((p2S.power >> 192) & 0xFFFFFFFFFFFFFFFF);

            if (p1Score > p2Score) return (1, p1Score, p2Score);
            if (p2Score > p1Score) return (2, p1Score, p2Score);
            return (3, p1Score, p2Score);
        }
    }

    function FindWinner(
        Match memory match_,
        uint256[] memory p1remaining,
        uint256[] memory p2remaining,
        uint256[6] memory neutrals,
        uint256[] memory p1r1,
        uint256[] memory p1r2,
        uint256[] memory p1r3,
        uint256[] memory p2r1,
        uint256[] memory p2r2,
        uint256[] memory p2r3
    )
        external
        pure
        returns (
            uint8 result,
            uint256 p1Total,
            uint256 p2Total,
            uint256[3] memory p1Rounds,
            uint256[3] memory p2Rounds
        )
    {
        uint8[3] memory results;
        uint256 p1S;
        uint256 p2S;
        uint8 rWinner;

        (rWinner, p1S, p2S) = _RoundWinner(
            p1remaining,
            p2remaining,
            p1r1,
            p2r1,
            neutrals[0],
            neutrals[1]
        );
        results[0] = rWinner;
        p1Rounds[0] = p1S;
        p2Rounds[0] = p2S;

        (rWinner, p1S, p2S) = _RoundWinner(
            p1remaining,
            p2remaining,
            p1r2,
            p2r2,
            neutrals[2],
            neutrals[3]
        );
        results[1] = rWinner;
        p1Rounds[1] = p1S;
        p2Rounds[1] = p2S;

        (rWinner, p1S, p2S) = _RoundWinner(
            p1remaining,
            p2remaining,
            p1r3,
            p2r3,
            neutrals[4],
            neutrals[5]
        );
        results[2] = rWinner;
        p1Rounds[2] = p1S;
        p2Rounds[2] = p2S;

        uint8 score1 = 0;
        uint8 score2 = 0;

        for (uint256 i = 0; i < 3; i++) {
            p1Total += p1Rounds[i];
            p2Total += p2Rounds[i];
            if (results[i] == 1) score1++;
            else if (results[i] == 2) score2++;
            else if (results[i] == 3) {
                score1++;
                score2++;
            }
        }

        if (score1 > score2)
            result = 1; // MatchResult.Player1Wins
        else if (score2 > score1)
            result = 2; // MatchResult.Player2Wins
        else result = 3; // MatchResult.Draw
    }
    // Placeholder simple scoring

    /**
     * @notice High-speed jump table for processing Special/Weather cards (IDs 136-144).
     */
    function _processNeutral(
        uint16 nid,
        uint8 choice,
        uint8 row
    ) internal pure returns (NeutralEffects memory effects) {
        Ability decoy;
        Ability scorch;
        uint256 horn;
        uint256 mardroeme;
        uint8 weather;

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
                    ability := 8
                } // Muster
                case 5 {
                    ability := 9
                } // Summon
                case 6 {
                    ability := 10
                } // Spy
                case 7 {
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
                    ability := 8
                }
                case 5 {
                    ability := 9
                }
                case 6 {
                    ability := 10
                }
                case 7 {
                    ability := 11
                }
                scorch := ability
            }
            case 137 {
                // Commander's Horn
                horn := shl(mul(64, add(row, 1)), 1)
            }
            case 136 {
                // Mardroeme
                mardroeme := shl(mul(64, add(row, 1)), 1)
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

        effects.decoy = decoy;
        effects.scorch = scorch;
        effects.horn = horn;
        effects.mardroeme = mardroeme;
        effects.weather = weather;
    }
}
