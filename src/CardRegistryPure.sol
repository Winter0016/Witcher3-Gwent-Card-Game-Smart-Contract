// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CardRegistryPure {
    enum Ability {
        None,
        Berserker,
        Transform_After_Death,
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
        Ability special_ability;
        UnitType unitType;
        Faction faction;
    }

    // =========================
    // CARD REGISTRY (PURE)
    // =========================
    function getCard(uint16 id) external pure returns (Card memory) {
        // 1. Split the deck in half immediately (Gas optimization trick)
        if (id <= 77) {
            // -------- NORTHERN REALMS (1 - 25) --------
            if (id <= 25) {
                if (id == 1)
                    return
                        Card(
                            1,
                            0,
                            Ability.Morale_Boost,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Northern
                        ); // Kaedweni Siege Expert
                if (id == 2)
                    return
                        Card(
                            1,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Poor Fucking Infantry
                if (id == 3)
                    return
                        Card(
                            1,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Redanian Foot Soldier
                if (id == 4)
                    return
                        Card(
                            1,
                            0,
                            Ability.Spy,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Northern
                        ); // Thaler

                // Power 2
                if (id == 5)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Yarpen Zigrin

                // Power 4
                if (id == 6)
                    return
                        Card(
                            4,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Blue Stripes Commando
                if (id == 7)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Northern
                        ); // Sabrina Glevissig
                if (id == 8)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Northern
                        ); // Sheldon Skaggs
                if (id == 9)
                    return
                        Card(
                            4,
                            0,
                            Ability.Spy,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Sigismund Dijkstra

                // Power 5
                if (id == 10)
                    return
                        Card(
                            5,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Northern
                        ); // Crinfrid Reavers Dragon Hunter
                if (id == 11)
                    return
                        Card(
                            5,
                            0,
                            Ability.Medic,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Northern
                        ); // Dun Banner Medic
                if (id == 12)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Northern
                        ); // Keira Metz
                if (id == 13)
                    return
                        Card(
                            5,
                            0,
                            Ability.Spy,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Prince Stennis
                if (id == 14)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Siegfried of Denesle
                if (id == 15)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Northern
                        ); // Síle de Tansarville
                if (id == 16)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Ves

                // Power 6
                if (id == 17)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Northern
                        ); // Ballista
                if (id == 18)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Northern
                        ); // Dethmold
                if (id == 19)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Northern
                        ); // Siege Tower
                if (id == 20)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Northern
                        ); // Trebuchet

                // Power 8
                if (id == 21)
                    return
                        Card(
                            8,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Northern
                        ); // Catapult

                // Power 10 (Heroes)
                if (id == 22)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Esterad Thyssen
                if (id == 23)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // John Natalis
                if (id == 24)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Northern
                        ); // Philippa Eilhart
                if (id == 25)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Northern
                        ); // Vernon Roche
            }

            // -------- SCOIA’TAEL (26 - 48) --------
            else if (id <= 48) {
                if (id == 26)
                    return
                        Card(
                            0,
                            0,
                            Ability.Medic,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Havekar Healer

                // Power 1
                if (id == 27)
                    return
                        Card(
                            1,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Riordain

                // Power 2
                if (id == 28)
                    return
                        Card(
                            2,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Elven Skirmisher
                if (id == 29)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Toruviel

                // Power 3
                if (id == 30)
                    return
                        Card(
                            3,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Agile,
                            Faction.Scoiatael
                        ); // Ciaran aep Easnillien
                if (id == 31)
                    return
                        Card(
                            3,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Scoiatael
                        ); // Dwarven Skirmisher

                // Power 4
                if (id == 32)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Dol Blathanna Archer
                if (id == 33)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Vrihedd Brigade Recruit

                // Power 5
                if (id == 34)
                    return
                        Card(
                            5,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Scoiatael
                        ); // Havekar Smuggler
                if (id == 35)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Scoiatael
                        ); // Mahakaman Defender
                if (id == 36)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Agile,
                            Faction.Scoiatael
                        ); // Vrihedd Brigade Veteran

                // Power 6
                if (id == 37)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Agile,
                            Faction.Scoiatael
                        ); // Barclay Els
                if (id == 38)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Scoiatael
                        ); // Dennis Cranmer
                if (id == 39)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Agile,
                            Faction.Scoiatael
                        ); // Dol Blathanna Scout
                if (id == 40)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Agile,
                            Faction.Scoiatael
                        ); // Filavandrel aen Fidhail
                if (id == 41)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Ida Emean aep Sivney
                if (id == 42)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Agile,
                            Faction.Scoiatael
                        ); // Yaevinn

                // Power 8
                if (id == 43)
                    return
                        Card(
                            8,
                            0,
                            Ability.Scorch,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Scoiatael
                        ); // Schirrú

                // Power 10
                if (id == 44)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Eithné
                if (id == 45)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Iorveth
                if (id == 46)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.Morale_Boost,
                            UnitType.Close_Combat,
                            Faction.Scoiatael
                        ); // Isengrim Faoiltiarna
                if (id == 47)
                    return
                        Card(
                            10,
                            0,
                            Ability.Morale_Boost,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Milva
                if (id == 48)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Scoiatael
                        ); // Saesenthessis
            }

            // -------- NILFGAARD (49 - 77) --------
            else {
                if (id == 49)
                    return
                        Card(
                            0,
                            0,
                            Ability.Medic,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Nilfgaard
                        ); // Siege Technician

                // Power 1
                if (id == 50)
                    return
                        Card(
                            1,
                            0,
                            Ability.Medic,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Etolian Auxiliary Archers

                // Power 2
                if (id == 51)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Albrich
                if (id == 52)
                    return
                        Card(
                            2,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Nausicaa Cavalry Rider
                if (id == 53)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Sweers
                if (id == 54)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Vreemde

                // Power 3
                if (id == 55)
                    return
                        Card(
                            3,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Impera Brigade Guard
                if (id == 56)
                    return
                        Card(
                            3,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Morteisen
                if (id == 57)
                    return
                        Card(
                            3,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Puttkammer
                if (id == 58)
                    return
                        Card(
                            3,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Nilfgaard
                        ); // Rotten Mangonel

                // Power 4
                if (id == 59)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Cynthia
                if (id == 60)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Rainfarn
                if (id == 61)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Vanhemar
                if (id == 62)
                    return
                        Card(
                            4,
                            0,
                            Ability.Spy,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Vattier de Rideaux

                // Power 5
                if (id == 63)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Renuald aep Matsen
                if (id == 64)
                    return
                        Card(
                            5,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Young Emissary
                if (id == 65)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Nilfgaard
                        ); // Zerrikanian Fire Scorpion

                // Power 6
                if (id == 66)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Assire var Anahid
                if (id == 67)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Cahir Mawr Dyffryn aep Ceallach
                if (id == 68)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Fringilla Vigo
                if (id == 69)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Nilfgaard
                        ); // Siege Engineer

                // Power 7
                if (id == 70)
                    return
                        Card(
                            7,
                            0,
                            Ability.Spy,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Shilard Fitz-Oesterlen

                // Power 9
                if (id == 71)
                    return
                        Card(
                            9,
                            0,
                            Ability.Spy,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Stefan Skellen

                // Power 10 (Non-Hero)
                if (id == 72)
                    return
                        Card(
                            10,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Black Infantry Archer
                if (id == 73)
                    return
                        Card(
                            10,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Nilfgaard
                        ); // Heavy Zerrikanian Fire Scorpion

                // Power 10 (Heroes)
                if (id == 74)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Letho of Gulet
                if (id == 75)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.Medic,
                            UnitType.Close_Combat,
                            Faction.Nilfgaard
                        ); // Menno Coehoorn
                if (id == 76)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Nilfgaard
                        ); // Morvran Voorhis
                if (id == 77)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Nilfgaard
                        ); // Tibor Eggebracht
            }
        } else {
            // -------- MONSTERS (78 - 112) --------
            if (id <= 112) {
                if (id == 78)
                    return
                        Card(
                            1,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Ghoul

                // Power 2
                if (id == 79)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Agile,
                            Faction.Monster
                        ); // Celaeno Harpy
                if (id == 80)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Monster
                        ); // Cockatrice
                if (id == 81)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Monster
                        ); // Endrega
                if (id == 82)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Foglet
                if (id == 83)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Monster
                        ); // Gargoyle
                if (id == 84)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Agile,
                            Faction.Monster
                        ); // Harpy
                if (id == 85)
                    return
                        Card(
                            2,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Nekker
                if (id == 86)
                    return
                        Card(
                            2,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Monster
                        ); // Wyvern

                // Power 4
                if (id == 87)
                    return
                        Card(
                            4,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Arachas
                if (id == 88)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Botchling
                if (id == 89)
                    return
                        Card(
                            4,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Vampire: Bruxa
                if (id == 90)
                    return
                        Card(
                            4,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Vampire: Ekimmara
                if (id == 91)
                    return
                        Card(
                            4,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Vampire: Fleder
                if (id == 92)
                    return
                        Card(
                            4,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Vampire: Garkain

                // Power 5
                if (id == 93)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Forktail
                if (id == 94)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Frightener
                if (id == 95)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Monster
                        ); // Grave Hag
                if (id == 96)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Griffin
                if (id == 97)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Monster
                        ); // Ice Giant
                if (id == 98)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Plague Maiden
                if (id == 99)
                    return
                        Card(
                            5,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Vampire: Katakan
                if (id == 100)
                    return
                        Card(
                            5,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Werewolf

                // Power 6
                if (id == 101)
                    return
                        Card(
                            6,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Monster
                        ); // Arachas Behemoth
                if (id == 102)
                    return
                        Card(
                            6,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Crone: Brewess
                if (id == 103)
                    return
                        Card(
                            6,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Crone: Weavess
                if (id == 104)
                    return
                        Card(
                            6,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Crone: Whispess
                if (id == 105)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Monster
                        ); // Earth Elemental
                if (id == 106)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Fiend
                if (id == 107)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Monster
                        ); // Fire Elemental

                // Power 7
                if (id == 108)
                    return
                        Card(
                            7,
                            0,
                            Ability.Scorch,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Monster
                        ); // Toad

                // Power 8
                if (id == 109)
                    return
                        Card(
                            8,
                            0,
                            Ability.Hero,
                            Ability.Morale_Boost,
                            UnitType.Agile,
                            Faction.Monster
                        ); // Kayran

                // Power 10 (Heroes)
                if (id == 110)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Draug
                if (id == 111)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Monster
                        ); // Imlerith
                if (id == 112)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Monster
                        ); // Leshen
            }

            // -------- SKELLIGE (113 - 135) --------
            else if (id <= 135) {
                if (id == 113)
                    return
                        Card(
                            0,
                            11, // transforms into Hemdall (11)
                            Ability.Transform_After_Death,
                            Ability.Hero,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Kambi

                // Power 2
                if (id == 114)
                    return
                        Card(
                            2,
                            0,
                            Ability.Medic,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Birna Bran

                if (id == 115)
                    return
                        Card(
                            2,
                            0,
                            Ability.Commander_horn,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Skellige
                        ); // Draig Bon-Dhu

                if (id == 116)
                    return
                        Card(
                            2,
                            8, // transforms into Young Vildkaarl (8)
                            Ability.Berserker,
                            Ability.Tight_Bond,
                            UnitType.Ranged,
                            Faction.Skellige
                        ); // Young Berserker

                // Power 4
                if (id == 117)
                    return
                        Card(
                            4,
                            14, // transforms into Vildkaarl (14)
                            Ability.Berserker,
                            Ability.Morale_Boost,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Berserker

                if (id == 118)
                    return
                        Card(
                            4,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Clan Drummond Shield Maiden

                if (id == 119)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Clan Heymaey Skald

                if (id == 120)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Clan Tordarroch Armorsmith

                if (id == 121)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Donar an Hindar

                if (id == 122)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Skellige
                        ); // Holger Blackhand

                if (id == 123)
                    return
                        Card(
                            4,
                            0,
                            Ability.Muster,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Skellige
                        ); // Light Longship

                if (id == 124)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Svanrige

                if (id == 125)
                    return
                        Card(
                            4,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Udalryk

                // Power 6
                if (id == 126)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Blueboy Lugos

                if (id == 127)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Skellige
                        ); // Clan Brokvar Archer

                if (id == 128)
                    return
                        Card(
                            6,
                            0,
                            Ability.Scorch,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Skellige
                        ); // Clan Dimun Pirate

                if (id == 129)
                    return
                        Card(
                            6,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Clan an Craite Warrior

                if (id == 130)
                    return
                        Card(
                            6,
                            0,
                            Ability.None,
                            Ability.None,
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Madman Lugos

                if (id == 131)
                    return
                        Card(
                            6,
                            0,
                            Ability.Tight_Bond,
                            Ability.None,
                            UnitType.Siege,
                            Faction.Skellige
                        ); // War Longship

                // Power 8
                if (id == 132)
                    return
                        Card(
                            8,
                            0,
                            Ability.Hero,
                            Ability.Mardroeme, // triggers berserker transforms
                            UnitType.Ranged,
                            Faction.Skellige
                        ); // Ermion

                // Power 10
                if (id == 133)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.Summon, // summon shield maidens
                            UnitType.Close_Combat,
                            Faction.Skellige
                        ); // Cerys

                if (id == 134)
                    return
                        Card(
                            10,
                            0,
                            Ability.Hero,
                            Ability.None,
                            UnitType.Ranged,
                            Faction.Skellige
                        ); // Hjalmar

                // Power 12
                if (id == 135)
                    return
                        Card(
                            12,
                            0,
                            Ability.Morale_Boost,
                            Ability.None,
                            UnitType.Agile,
                            Faction.Skellige
                        ); // Olaf
            }

            // -------- SPECIAL & WEATHER CARDS (136 - 144) --------
            else if (id <= 144) {
                if (id == 136)
                    return
                        Card(
                            0,
                            0,
                            Ability.Mardroeme,
                            Ability.None,
                            UnitType.Special,
                            Faction.Skellige
                        ); // Mardroeme

                // Commander's Horn - Doubles row power
                if (id == 137)
                    return
                        Card(
                            0,
                            0,
                            Ability.Commander_horn,
                            Ability.None,
                            UnitType.Special,
                            Faction.Neutral
                        ); // Commander's Horn

                // Decoy - Swap card from battlefield with hand
                if (id == 138)
                    return
                        Card(
                            0,
                            0,
                            Ability.Decoy,
                            Ability.None,
                            UnitType.Special,
                            Faction.Neutral
                        ); // Decoy

                // Scorch - Destroy highest power unit
                if (id == 139)
                    return
                        Card(
                            0,
                            0,
                            Ability.Scorch,
                            Ability.None,
                            UnitType.Special,
                            Faction.Neutral
                        ); // Scorch

                // -------- WEATHER CARDS --------

                // Biting Frost - Sets Close Combat to 1
                if (id == 140)
                    return
                        Card(
                            0,
                            0,
                            Ability.weather_sets_close_1,
                            Ability.None,
                            UnitType.Weather,
                            Faction.Neutral
                        ); // Biting Frost

                // Clear Weather - Removes all weather effects
                if (id == 141)
                    return
                        Card(
                            0,
                            0,
                            Ability.weather_clears,
                            Ability.None,
                            UnitType.Weather,
                            Faction.Neutral
                        ); // Clear Weather

                // Impenetrable Fog - Sets Ranged to 1
                if (id == 142)
                    return
                        Card(
                            0,
                            0,
                            Ability.weather_sets_range_1,
                            Ability.None,
                            UnitType.Weather,
                            Faction.Neutral
                        ); // Impenetrable Fog

                // Torrential Rain - Sets Siege to 1
                if (id == 143)
                    return
                        Card(
                            0,
                            0,
                            Ability.weather_sets_sieg_1,
                            Ability.None,
                            UnitType.Weather,
                            Faction.Neutral
                        ); // Torrential Rain

                // Skellige Storm - Sets Ranged AND Siege to 1
                if (id == 144)
                    return
                        Card(
                            0,
                            0,
                            Ability.weather_reduces_close_range_1,
                            Ability.None,
                            UnitType.Weather,
                            Faction.Skellige
                        ); // Skellige Storm
            }
        }

        // If the ID doesn't exist, it falls down here and reverts
        revert("Invalid card id");
    }
    // =========================
    // MUSTER GROUP (PURE)
    // =========================

    // =========================
    // DECK VALIDATION (PURE)
    // =========================
    function isDeckValidForFaction(
        Faction faction,
        uint256[] calldata cardIds
    ) external pure returns (bool) {
        uint16 minId;
        uint16 maxId;

        // 1. Set the strict faction boundaries
        if (faction == Faction.Northern) {
            minId = 1;
            maxId = 25;
        } else if (faction == Faction.Scoiatael) {
            minId = 26;
            maxId = 48;
        } else if (faction == Faction.Nilfgaard) {
            minId = 49;
            maxId = 77;
        } else if (faction == Faction.Monster) {
            minId = 78;
            maxId = 112;
        } else if (faction == Faction.Skellige) {
            minId = 113;
            maxId = 135;
        } else {
            return false; // Neutral is not a playable base faction
        }

        // 2. Loop through the deck
        uint256 length = cardIds.length;
        for (uint256 i = 0; i < length; ) {
            uint256 id = cardIds[i];

            // Valid if it's in the faction range OR if it's a Neutral/Special card (136-144)
            bool isFactionCard = (id >= minId && id <= maxId);
            bool isNeutralCard = (id >= 136 && id <= 144);

            if (!isFactionCard && !isNeutralCard) {
                return false; // Instantly fail if an intruder card is found
            }

            // Gas optimization for the loop counter
            unchecked {
                ++i;
            }
        }

        return true; // All cards passed the check
    }

    function getMusterGroup(uint16 id) external pure returns (uint8) {
        // ================= MONSTERS =================

        // Ghoul
        if (id == 78) return 1;

        // Nekker
        if (id == 85) return 2;

        // Arachas
        if (id == 87 || id == 101) return 3;

        // Crones
        if (id == 102 || id == 103 || id == 104) return 4;

        // Vampires
        if (
            id == 89 || // Bruxa
            id == 90 || // Ekimmara
            id == 91 || // Fleder
            id == 92 || // Garkain
            id == 99 // Katakan
        ) return 5;

        // ================= SCOIA’TAEL =================

        // Elven Skirmishers
        if (id == 28) return 6;

        // Dwarven Skirmishers
        if (id == 31) return 7;

        // Havekar Smugglers
        if (id == 34) return 8;

        // ================= SKELLIGE =================

        // Light Longships
        if (id == 123) return 9;

        // Shield Maidens (Cerys summon target)
        if (id == 118) return 10;

        return 0;
    }
}
