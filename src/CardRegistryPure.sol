// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CardRegistryPure {
    enum Ability {
        None,
        Berserker,
        Commander_horn,
        Decoy,
        Hero,
        Medic,
        Morale_Boost,
        Mardroeme,
        Muster,
        Summon,
        Spy,
        Tight_Bond,
        Scorch,
        weather_sets_close_1,
        weather_clears,
        weather_sets_range_1,
        weather_reduces_close_range_1,
        weather_sets_sieg_1
    }

    enum UnitType {
        Close_Combat,
        Ranged,
        Siege,
        Agile,
        Weather,
        Special
    }

    enum Faction {
        Northern,
        Nilfgaard,
        Monster,
        Scoiatael,
        Skellige,
        Neutral
    }

    struct Card {
        uint8 power;
        uint8 berserker_power;
        Ability ability;
        UnitType unitType;
        Faction faction;
    }

    /**
     * @notice Returns card properties based on its unique ID.
     * Card ranges by faction:
     * - Northern Realms: 1 - 25
     * - Scoia'tael: 26 - 48
     * - Nilfgaard: 49 - 77
     * - Monster: 78 - 112
     * - Skellige: 113 - 135
     * - Neutral (Special/Weather): 136 - 144
     */
    function getCard(uint16 id) public pure returns (Card memory) {
        if (id < 73) {
            if (id < 37) {
                if (id < 19) {
                    if (id < 10) {
                        if (id < 5) {
                            if (id == 1) return Card(1, 0, Ability.Morale_Boost, UnitType.Siege, Faction.Northern);
                            if (id == 2) return Card(1, 0, Ability.Tight_Bond, UnitType.Close_Combat, Faction.Northern);
                            if (id == 3) return Card(1, 0, Ability.None, UnitType.Close_Combat, Faction.Northern);
                            if (id == 4) return Card(1, 0, Ability.Spy, UnitType.Siege, Faction.Northern);
                        } else {
                            if (id == 5) return Card(2, 0, Ability.None, UnitType.Close_Combat, Faction.Northern);
                            if (id == 6) return Card(4, 0, Ability.Tight_Bond, UnitType.Close_Combat, Faction.Northern);
                            if (id == 7) return Card(4, 0, Ability.None, UnitType.Ranged, Faction.Northern);
                            if (id == 8) return Card(4, 0, Ability.None, UnitType.Ranged, Faction.Northern);
                            if (id == 9) return Card(4, 0, Ability.Spy, UnitType.Close_Combat, Faction.Northern);
                        }
                    } else {
                        if (id < 15) {
                            if (id == 10) return Card(5, 0, Ability.Tight_Bond, UnitType.Ranged, Faction.Northern);
                            if (id == 11) return Card(5, 0, Ability.Medic, UnitType.Siege, Faction.Northern);
                            if (id == 12) return Card(5, 0, Ability.None, UnitType.Ranged, Faction.Northern);
                            if (id == 13) return Card(5, 0, Ability.Spy, UnitType.Close_Combat, Faction.Northern);
                            if (id == 14) return Card(5, 0, Ability.None, UnitType.Close_Combat, Faction.Northern);
                        } else {
                            if (id == 15) return Card(5, 0, Ability.None, UnitType.Ranged, Faction.Northern);
                            if (id == 16) return Card(5, 0, Ability.None, UnitType.Close_Combat, Faction.Northern);
                            if (id == 17) return Card(6, 0, Ability.None, UnitType.Siege, Faction.Northern);
                            if (id == 18) return Card(6, 0, Ability.None, UnitType.Ranged, Faction.Northern);
                        }
                    }
                } else {
                    if (id < 28) {
                        if (id < 24) {
                            if (id == 19) return Card(6, 0, Ability.None, UnitType.Siege, Faction.Northern);
                            if (id == 20) return Card(6, 0, Ability.None, UnitType.Siege, Faction.Northern);
                            if (id == 21) return Card(8, 0, Ability.Tight_Bond, UnitType.Siege, Faction.Northern);
                            if (id == 22) return Card(10, 0, Ability.Hero, UnitType.Close_Combat, Faction.Northern);
                            if (id == 23) return Card(10, 0, Ability.Hero, UnitType.Close_Combat, Faction.Northern);
                        } else {
                            if (id == 24) return Card(10, 0, Ability.Hero, UnitType.Ranged, Faction.Northern);
                            if (id == 25) return Card(10, 0, Ability.Hero, UnitType.Close_Combat, Faction.Northern);
                            if (id == 26) return Card(0, 0, Ability.Medic, UnitType.Ranged, Faction.Scoiatael);
                            if (id == 27) return Card(1, 0, Ability.None, UnitType.Ranged, Faction.Scoiatael);
                        }
                    } else {
                        if (id < 33) {
                            if (id == 28) return Card(2, 0, Ability.Muster, UnitType.Ranged, Faction.Scoiatael);
                            if (id == 29) return Card(2, 0, Ability.None, UnitType.Ranged, Faction.Scoiatael);
                            if (id == 30) return Card(3, 0, Ability.None, UnitType.Agile, Faction.Scoiatael);
                            if (id == 31) return Card(3, 0, Ability.Muster, UnitType.Close_Combat, Faction.Scoiatael);
                            if (id == 32) return Card(4, 0, Ability.None, UnitType.Ranged, Faction.Scoiatael);
                        } else {
                            if (id == 33) return Card(4, 0, Ability.None, UnitType.Ranged, Faction.Scoiatael);
                            if (id == 34) return Card(5, 0, Ability.Muster, UnitType.Close_Combat, Faction.Scoiatael);
                            if (id == 35) return Card(5, 0, Ability.None, UnitType.Close_Combat, Faction.Scoiatael);
                            if (id == 36) return Card(5, 0, Ability.None, UnitType.Agile, Faction.Scoiatael);
                        }
                    }
                }
            } else {
                if (id < 55) {
                    if (id < 46) {
                        if (id < 41) {
                            if (id == 37) return Card(6, 0, Ability.None, UnitType.Agile, Faction.Scoiatael);
                            if (id == 38) return Card(6, 0, Ability.None, UnitType.Close_Combat, Faction.Scoiatael);
                            if (id == 39) return Card(6, 0, Ability.None, UnitType.Agile, Faction.Scoiatael);
                            if (id == 40) return Card(6, 0, Ability.None, UnitType.Agile, Faction.Scoiatael);
                        } else {
                            if (id == 41) return Card(6, 0, Ability.None, UnitType.Ranged, Faction.Scoiatael);
                            if (id == 42) return Card(6, 0, Ability.None, UnitType.Agile, Faction.Scoiatael);
                            if (id == 43) return Card(8, 0, Ability.Scorch, UnitType.Siege, Faction.Scoiatael);
                            if (id == 44) return Card(10, 0, Ability.Hero, UnitType.Ranged, Faction.Scoiatael);
                            if (id == 45) return Card(10, 0, Ability.Hero, UnitType.Ranged, Faction.Scoiatael);
                        }
                    } else {
                        if (id < 51) {
                            if (id == 46) return Card(10, 0, Ability.Hero, UnitType.Close_Combat, Faction.Scoiatael);
                            if (id == 47) return Card(10, 0, Ability.Morale_Boost, UnitType.Ranged, Faction.Scoiatael);
                            if (id == 48) return Card(10, 0, Ability.Hero, UnitType.Ranged, Faction.Scoiatael);
                            if (id == 49) return Card(0, 0, Ability.Medic, UnitType.Siege, Faction.Nilfgaard);
                            if (id == 50) return Card(1, 0, Ability.Medic, UnitType.Ranged, Faction.Nilfgaard);
                        } else {
                            if (id == 51) return Card(2, 0, Ability.None, UnitType.Ranged, Faction.Nilfgaard);
                            if (id == 52) return Card(2, 0, Ability.Tight_Bond, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 53) return Card(2, 0, Ability.None, UnitType.Ranged, Faction.Nilfgaard);
                            if (id == 54) return Card(2, 0, Ability.None, UnitType.Close_Combat, Faction.Nilfgaard);
                        }
                    }
                } else {
                    if (id < 64) {
                        if (id < 60) {
                            if (id == 55) return Card(3, 0, Ability.Tight_Bond, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 56) return Card(3, 0, Ability.None, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 57) return Card(3, 0, Ability.None, UnitType.Ranged, Faction.Nilfgaard);
                            if (id == 58) return Card(3, 0, Ability.None, UnitType.Siege, Faction.Nilfgaard);
                            if (id == 59) return Card(4, 0, Ability.None, UnitType.Ranged, Faction.Nilfgaard);
                        } else {
                            if (id == 60) return Card(4, 0, Ability.None, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 61) return Card(4, 0, Ability.None, UnitType.Ranged, Faction.Nilfgaard);
                            if (id == 62) return Card(4, 0, Ability.Spy, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 63) return Card(5, 0, Ability.None, UnitType.Ranged, Faction.Nilfgaard);
                        }
                    } else {
                        if (id < 69) {
                            if (id == 64) return Card(5, 0, Ability.Tight_Bond, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 65) return Card(5, 0, Ability.None, UnitType.Siege, Faction.Nilfgaard);
                            if (id == 66) return Card(6, 0, Ability.None, UnitType.Ranged, Faction.Nilfgaard);
                            if (id == 67) return Card(6, 0, Ability.None, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 68) return Card(6, 0, Ability.None, UnitType.Ranged, Faction.Nilfgaard);
                        } else {
                            if (id == 69) return Card(6, 0, Ability.None, UnitType.Siege, Faction.Nilfgaard);
                            if (id == 70) return Card(7, 0, Ability.Spy, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 71) return Card(9, 0, Ability.Spy, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 72) return Card(10, 0, Ability.None, UnitType.Ranged, Faction.Nilfgaard);
                        }
                    }
                }
            }
        } else {
            if (id < 109) {
                if (id < 91) {
                    if (id < 82) {
                        if (id < 78) {
                            if (id == 73) return Card(10, 0, Ability.None, UnitType.Siege, Faction.Nilfgaard);
                            if (id == 74) return Card(10, 0, Ability.Hero, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 75) return Card(10, 0, Ability.Hero, UnitType.Close_Combat, Faction.Nilfgaard);
                            if (id == 76) return Card(10, 0, Ability.Hero, UnitType.Siege, Faction.Nilfgaard);
                            if (id == 77) return Card(10, 0, Ability.Hero, UnitType.Ranged, Faction.Nilfgaard);
                        } else {
                            if (id == 78) return Card(1, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                            if (id == 79) return Card(2, 0, Ability.None, UnitType.Agile, Faction.Monster);
                            if (id == 80) return Card(2, 0, Ability.None, UnitType.Ranged, Faction.Monster);
                            if (id == 81) return Card(2, 0, Ability.None, UnitType.Ranged, Faction.Monster);
                        }
                    } else {
                        if (id < 87) {
                            if (id == 82) return Card(2, 0, Ability.None, UnitType.Close_Combat, Faction.Monster);
                            if (id == 83) return Card(2, 0, Ability.None, UnitType.Ranged, Faction.Monster);
                            if (id == 84) return Card(2, 0, Ability.None, UnitType.Agile, Faction.Monster);
                            if (id == 85) return Card(2, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                            if (id == 86) return Card(2, 0, Ability.None, UnitType.Ranged, Faction.Monster);
                        } else {
                            if (id == 87) return Card(4, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                            if (id == 88) return Card(4, 0, Ability.None, UnitType.Close_Combat, Faction.Monster);
                            if (id == 89) return Card(4, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                            if (id == 90) return Card(4, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                        }
                    }
                } else {
                    if (id < 100) {
                        if (id < 96) {
                            if (id == 91) return Card(4, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                            if (id == 92) return Card(4, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                            if (id == 93) return Card(5, 0, Ability.None, UnitType.Close_Combat, Faction.Monster);
                            if (id == 94) return Card(5, 0, Ability.None, UnitType.Close_Combat, Faction.Monster);
                            if (id == 95) return Card(5, 0, Ability.None, UnitType.Ranged, Faction.Monster);
                        } else {
                            if (id == 96) return Card(5, 0, Ability.None, UnitType.Close_Combat, Faction.Monster);
                            if (id == 97) return Card(5, 0, Ability.None, UnitType.Siege, Faction.Monster);
                            if (id == 98) return Card(5, 0, Ability.None, UnitType.Close_Combat, Faction.Monster);
                            if (id == 99) return Card(5, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                        }
                    } else {
                        if (id < 105) {
                            if (id == 100) return Card(5, 0, Ability.None, UnitType.Close_Combat, Faction.Monster);
                            if (id == 101) return Card(6, 0, Ability.Muster, UnitType.Siege, Faction.Monster);
                            if (id == 102) return Card(6, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                            if (id == 103) return Card(6, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                            if (id == 104) return Card(6, 0, Ability.Muster, UnitType.Close_Combat, Faction.Monster);
                        } else {
                            if (id == 105) return Card(6, 0, Ability.None, UnitType.Siege, Faction.Monster);
                            if (id == 106) return Card(6, 0, Ability.None, UnitType.Close_Combat, Faction.Monster);
                            if (id == 107) return Card(6, 0, Ability.None, UnitType.Siege, Faction.Monster);
                            if (id == 108) return Card(7, 0, Ability.Scorch, UnitType.Ranged, Faction.Monster);
                        }
                    }
                }
            } else {
                if (id < 127) {
                    if (id < 118) {
                        if (id < 114) {
                            if (id == 109) return Card(8, 0, Ability.Hero, UnitType.Agile, Faction.Monster);
                            if (id == 110) return Card(10, 0, Ability.Hero, UnitType.Close_Combat, Faction.Monster);
                            if (id == 111) return Card(10, 0, Ability.Hero, UnitType.Close_Combat, Faction.Monster);
                            if (id == 112) return Card(10, 0, Ability.Hero, UnitType.Ranged, Faction.Monster);
                            if (id == 113) return Card(0, 11, Ability.Berserker, UnitType.Close_Combat, Faction.Skellige);
                        } else {
                            if (id == 114) return Card(2, 0, Ability.Medic, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 115) return Card(2, 0, Ability.Commander_horn, UnitType.Siege, Faction.Skellige);
                            if (id == 116) return Card(2, 8, Ability.Berserker, UnitType.Ranged, Faction.Skellige);
                            if (id == 117) return Card(4, 14, Ability.Berserker, UnitType.Close_Combat, Faction.Skellige);
                        }
                    } else {
                        if (id < 123) {
                            if (id == 118) return Card(4, 0, Ability.Tight_Bond, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 119) return Card(4, 0, Ability.None, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 120) return Card(4, 0, Ability.None, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 121) return Card(4, 0, Ability.None, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 122) return Card(4, 0, Ability.None, UnitType.Siege, Faction.Skellige);
                        } else {
                            if (id == 123) return Card(4, 0, Ability.Muster, UnitType.Ranged, Faction.Skellige);
                            if (id == 124) return Card(4, 0, Ability.None, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 125) return Card(4, 0, Ability.None, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 126) return Card(6, 0, Ability.None, UnitType.Close_Combat, Faction.Skellige);
                        }
                    }
                } else {
                    if (id < 136) {
                        if (id < 132) {
                            if (id == 127) return Card(6, 0, Ability.None, UnitType.Ranged, Faction.Skellige);
                            if (id == 128) return Card(6, 0, Ability.Scorch, UnitType.Ranged, Faction.Skellige);
                            if (id == 129) return Card(6, 0, Ability.Tight_Bond, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 130) return Card(6, 0, Ability.None, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 131) return Card(6, 0, Ability.Tight_Bond, UnitType.Siege, Faction.Skellige);
                        } else {
                            if (id == 132) return Card(8, 0, Ability.Hero, UnitType.Ranged, Faction.Skellige);
                            if (id == 133) return Card(10, 0, Ability.Hero, UnitType.Close_Combat, Faction.Skellige);
                            if (id == 134) return Card(10, 0, Ability.Hero, UnitType.Ranged, Faction.Skellige);
                            if (id == 135) return Card(12, 0, Ability.Morale_Boost, UnitType.Agile, Faction.Skellige);
                        }
                    } else {
                        if (id < 141) {
                            if (id == 136) return Card(0, 0, Ability.Mardroeme, UnitType.Special, Faction.Neutral);
                            if (id == 137) return Card(0, 0, Ability.Commander_horn, UnitType.Special, Faction.Neutral);
                            if (id == 138) return Card(0, 0, Ability.Decoy, UnitType.Special, Faction.Neutral);
                            if (id == 139) return Card(0, 0, Ability.Scorch, UnitType.Special, Faction.Neutral);
                            if (id == 140) return Card(0, 0, Ability.weather_sets_close_1, UnitType.Weather, Faction.Neutral);
                        } else {
                            if (id == 141) return Card(0, 0, Ability.weather_clears, UnitType.Weather, Faction.Neutral);
                            if (id == 142) return Card(0, 0, Ability.weather_sets_range_1, UnitType.Weather, Faction.Neutral);
                            if (id == 143) return Card(0, 0, Ability.weather_sets_sieg_1, UnitType.Weather, Faction.Neutral);
                            if (id == 144) return Card(0, 0, Ability.weather_reduces_close_range_1, UnitType.Weather, Faction.Neutral);
                        }
                    }
                }
            }
        }
        revert("Invalid card id");
    }

    function getMusterMembersByID(uint16 id) external pure returns (uint256 packed) {
        if (id < 89) {
            if (id == 78) return (1 | (78 << 8));
            if (id == 85) return (1 | (85 << 8));
            if (id == 87) return (2 | (87 << 8) | (101 << 24));
            if (id == 28) return (1 | (28 << 8));
            if (id == 31) return (1 | (31 << 8));
            if (id == 34) return (1 | (34 << 8));
        } else {
            if (id == 101) return (2 | (87 << 8) | (101 << 24));
            if (id >= 102 && id <= 104) return (3 | (102 << 8) | (103 << 24) | (104 << 40));
            if (id == 89 || id == 90 || id == 91 || id == 92 || id == 99) {
                return (5 | (89 << 8) | (90 << 24) | (91 << 40) | (92 << 56) | (99 << 72));
            }
            if (id == 123) return (1 | (123 << 8));
            if (id == 133) return (1 | (118 << 8));
        }
    }

    function isDeckValidForFaction(Faction faction, uint256[] calldata cardIds, uint256[] calldata cardAmounts) public pure returns (bool) {
        uint256 length = cardIds.length;
        uint256 specialCount = 0;
        for (uint256 i = 0; i < length; ) {
            uint16 id = uint16(cardIds[i]);
            Card memory card = getCard(id);
            if (card.faction != faction && card.faction != Faction.Neutral) return false;
            if (id >= 136 && id <= 144) specialCount += cardAmounts[i];
            unchecked { ++i; }
        }
        return specialCount <= 3;
    }

    function isNeutralCard(uint16 id) public pure returns (bool) {
        return (id >= 136 && id <= 144);
    }
}
