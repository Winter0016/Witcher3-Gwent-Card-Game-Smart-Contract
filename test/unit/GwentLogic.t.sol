// SPDX-License-Identifer: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GwentArena} from "../../src/GwentArena.sol";
import {GwentCardToken} from "../../src/GwentCardToken.sol";
import {GwentSystem} from "../../src/GwentSystem.sol";
import {DeployGwent} from "../../script/Deploy.s.sol";
import {LinkToken} from "../mocks/LinkToken.sol";
import {
    VRFCoordinatorV2_5Mock
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig} from "../../script/Helperconfig.s.sol";
import {CodeConstants} from "../../script/Helperconfig.s.sol";
import {
    Phase,
    MatchResult,
    Faction,
    Match,
    MatchInfo
} from "../../src/GwentTypes.sol";
import {
    ERC1155Holder
} from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {CardGameLogic} from "../../src/CardGameLogic.sol";

contract GwentLogicTest is Test, CodeConstants, ERC1155Holder {
    event MatchResolved(
        uint256 indexed matchId,
        MatchResult result,
        address winner,
        uint256 p1TotalScore,
        uint256 p2TotalScore,
        uint256[3] p1RoundScores,
        uint256[3] p2RoundScores
    );

    GwentArena public gwentArena;
    GwentCardToken public gwentCardToken;
    GwentSystem public gwentSystem;
    LinkToken public linkToken;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 automationUpdateInterval;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;

    uint256 public constant LINK_BALANCE = 500 ether;
    uint256 public constant USER_BALANCE = 1000 ether;

    address player1 = makeAddr("player1");
    address player2 = makeAddr("player2");
    address player3 = makeAddr("player3");
    address player4 = makeAddr("player4");

    uint256[] public player1carddeck;
    uint256[] public player1carddeckamount;
    uint256[] public player2carddeck;
    uint256[] public player2carddeckamount;
    uint256[] public player3carddeck;
    uint256[] public player3carddeckamount;
    uint256[] public player4carddeck;
    uint256[] public player4carddeckamount;

    function setUp() public {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (block.chainid != 31337) {
            deal(config.link, config.account, 100 ether);
        }

        DeployGwent deployer = new DeployGwent();
        (gwentCardToken, gwentArena, gwentSystem, ) = deployer.run();

        vm.deal(player1, 1000 ether);

        address[] memory recipients = new address[](4);
        recipients[0] = player1;
        recipients[1] = player2;
        recipients[2] = player3;
        recipients[3] = player4;

        // --- Auth Ritual: Act as Admin ---
        vm.deal(config.account, 100 ether);
        vm.startPrank(config.account);

        gwentCardToken.airdropCurrency(recipients, USER_BALANCE);

        // --- Initialize Decks ---

        // Player 1: Northern Realms (IDs 1 - 25: 25 cards)
        player1carddeck = new uint256[](22);
        player1carddeckamount = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            // give player 22 cards total => 1 to 22
            player1carddeck[i] = 1 + (i % 25); // i % 25 means to cycle the entire northern realm range because nortern range is 1-25
            player1carddeckamount[i] = 1;
        }
        gwentCardToken.mintBatch(
            player1,
            player1carddeck,
            player1carddeckamount,
            ""
        );

        // Player 2: Scoia'tael (IDs 26 - 48: 23 cards)
        player2carddeck = new uint256[](22);
        player2carddeckamount = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            // give player 22 cards total => 26 to 47
            player2carddeck[i] = 26 + (i % 23);
            player2carddeckamount[i] = 1;
        }
        gwentCardToken.mintBatch(
            player2,
            player2carddeck,
            player2carddeckamount,
            ""
        );

        // Player 3: Monsters (IDs 78 - 112: 35 cards)
        player3carddeck = new uint256[](22);
        player3carddeckamount = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            // give player 22 cards total => 78 to 100
            player3carddeck[i] = 78 + (i % 35);

            if (player3carddeck[i] == 89) {
                player3carddeckamount[i] = 2;
            } else {
                player3carddeckamount[i] = 1;
            }
        }
        gwentCardToken.mintBatch(
            player3,
            player3carddeck,
            player3carddeckamount,
            ""
        );

        // Player 4: Skellige (IDs 113 - 135: 22 cards)
        player4carddeck = new uint256[](23);
        player4carddeckamount = new uint256[](23);
        for (uint256 i = 0; i < 23; i++) {
            player4carddeck[i] = 113 + i;
            player4carddeckamount[i] = 1;
        }
        gwentCardToken.mintBatch(
            player4,
            player4carddeck,
            player4carddeckamount,
            ""
        );

        vm.stopPrank();
    }

    modifier enterArenaPhase() {
        vm.startPrank(player1);
        uint256 gasstart1 = gasleft();
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(
            Faction.Northern,
            player1carddeck,
            player1carddeckamount
        );
        uint256 gasend1 = gasleft();
        console.log("Gas used for enterArena player1:", gasstart1 - gasend1);
        vm.stopPrank();

        vm.startPrank(player2);
        uint256 gasstart2 = gasleft();
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(
            Faction.Scoiatael,
            player2carddeck,
            player2carddeckamount
        );
        uint256 gasend2 = gasleft();
        console.log("Gas used for enterArena player2:", gasstart2 - gasend2);
        vm.stopPrank();

        // --- Trigger Matchmaking ---
        (bool upkeepNeeded, bytes memory performData) = gwentArena.checkUpkeep(
            ""
        );
        require(upkeepNeeded, "Matchmaking should be needed");
        gwentArena.performUpkeep(performData);
        _;
    }

    // AI WRITE TESTS
    function test_raw_power_no_ability_p1_wins() public enterArenaPhase {
        // Valid
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);
        uint256 salt = 12345;

        // Player 1 Hand (Northern): Unique IDs with Power 4-6, Ability.None
        uint256[] memory p1r1 = new uint256[](4);
        p1r1[0] = gwentArena.encodeCard(17, 1, 0, 0, 0, 0); // P6, Siege
        p1r1[1] = gwentArena.encodeCard(18, 1, 0, 0, 0, 0); // P6, Siege
        p1r1[2] = gwentArena.encodeCard(19, 1, 0, 0, 0, 0); // P6, Siege
        p1r1[3] = gwentArena.encodeCard(20, 1, 0, 0, 0, 0); // P6, Siege -> Total 24

        uint256[] memory p1r2 = new uint256[](3);
        p1r2[0] = gwentArena.encodeCard(12, 1, 0, 0, 0, 0); // P5, Ranged
        p1r2[1] = gwentArena.encodeCard(14, 1, 0, 0, 0, 0); // P5, Ranged
        p1r2[2] = gwentArena.encodeCard(15, 1, 0, 0, 0, 0); // P5, Ranged -> Total 15

        uint256[] memory p1r3 = new uint256[](3);
        p1r3[0] = gwentArena.encodeCard(16, 1, 0, 0, 0, 0); // P5, Ranged
        p1r3[1] = gwentArena.encodeCard(7, 1, 0, 0, 0, 0); // P4, Ranged
        p1r3[2] = gwentArena.encodeCard(8, 1, 0, 0, 0, 0); // P4, Ranged -> Total 13

        // Player 2 Hand (Scoia'tael): Unique IDs with Power 1-6, Ability.None
        uint256[] memory p2r1 = new uint256[](4);
        p2r1[0] = gwentArena.encodeCard(27, 1, 0, 0, 0, 0); // P1, Ranged
        p2r1[1] = gwentArena.encodeCard(29, 1, 0, 0, 0, 0); // P2, Ranged
        p2r1[2] = gwentArena.encodeCard(30, 1, 0, 0, 0, 0); // P3, Agile
        p2r1[3] = gwentArena.encodeCard(32, 1, 0, 0, 0, 0); // P4, Ranged -> Total 10

        uint256[] memory p2r2 = new uint256[](3);
        p2r2[0] = gwentArena.encodeCard(33, 1, 0, 0, 0, 0); // P4, Ranged
        p2r2[1] = gwentArena.encodeCard(35, 1, 0, 0, 0, 0); // P5, Agile
        p2r2[2] = gwentArena.encodeCard(36, 1, 0, 0, 0, 0); // P5, Agile -> Total 14

        uint256[] memory p2r3 = new uint256[](3);
        p2r3[0] = gwentArena.encodeCard(37, 1, 0, 0, 0, 0); // P6, Agile
        p2r3[1] = gwentArena.encodeCard(38, 1, 0, 0, 0, 0); // P6, Agile
        p2r3[2] = gwentArena.encodeCard(39, 1, 0, 0, 0, 0); // P6, Agile -> Total 18

        // --- Commit ---
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        vm.prank(player1);
        uint256 gasstart3 = gasleft();
        gwentArena.commitPlays(matchId, h);
        uint256 gasend3 = gasleft();
        console.log("Gas used for commitPlays player1:", gasstart3 - gasend3);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player2);
        uint256 gasstart4 = gasleft();
        gwentArena.commitPlays(matchId, ph);
        uint256 gasend4 = gasleft();
        console.log("Gas used for commitPlays player2:", gasstart4 - gasend4);

        // --- Reveal ---
        vm.prank(player1);
        uint256 gasstart5 = gasleft();
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        uint256 gasend5 = gasleft();
        console.log("Gas used for revealPlays player1:", gasstart5 - gasend5);
        vm.prank(player2);
        uint256 gasstart6 = gasleft();
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);
        uint256 gasend6 = gasleft();
        console.log("Gas used for revealPlays player2:", gasstart6 - gasend6);

        // --- Resolve ---
        uint256 gasstart7 = gasleft();
        (bool upkeepNeeded, bytes memory performData) = gwentArena.checkUpkeep(
            ""
        );
        require(upkeepNeeded, "Match resolution should be needed");
        gwentArena.performUpkeep(performData);
        uint256 gasend7 = gasleft();
        console.log("Gas used for resolve:", gasstart7 - gasend7);

        // --- Verify ---
        MatchInfo memory info = gwentArena.getMatchInfo(matchId);
        assertEq(
            uint8(info.result),
            uint8(MatchResult.Player1Wins),
            "Player 1 should win based on raw power"
        );
        vm.prank(player1);
        uint256 gasstart8 = gasleft();
        gwentArena.claimRewards(matchId);
        uint256 gasend8 = gasleft();
        console.log("Gas used for claimRewards player1:", gasstart8 - gasend8);
    }

    function test_tight_bondd_ability_p1_wins() public {
        // Valid
        uint256 salt = 12345;

        // 1. Give P1 2 more copies of ID 6 (P4, Tight Bond)
        uint256[] memory extraIds = new uint256[](1);
        extraIds[0] = 6;
        uint256[] memory extraAmounts = new uint256[](1);
        extraAmounts[0] = 2; // Already has 1 from setup, total is 3
        gwentCardToken.mintBatch(player1, extraIds, extraAmounts, "");

        // 2. Prepare P1 Deck (IDs 1-22, ID 6 has 3 copies) -> Total Cards: 24
        uint256[] memory p1Ids = new uint256[](22);
        uint256[] memory p1Amounts = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            p1Ids[i] = 1 + i;
            p1Amounts[i] = (p1Ids[i] == 6) ? 3 : 1;
        }

        // 3. Manual Entry
        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p1Ids, p1Amounts);
        vm.stopPrank();

        vm.startPrank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(
            Faction.Scoiatael,
            player2carddeck,
            player2carddeckamount
        );
        vm.stopPrank();

        // 4. Matchmaking
        (bool upkeepNeeded, bytes memory pData) = gwentArena.checkUpkeep("");
        require(upkeepNeeded, "Matchmaking needed");
        gwentArena.performUpkeep(pData);
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        // 5. Play Rounds: Total cards (sum of amounts) must be exactly 10
        // R1: ID 6 (P4, Bond) Amount 3 + ID 3 (P1) Amount 1 -> Total 4 cards (Power 36+1=37)
        uint256[] memory p1r1 = new uint256[](2);
        p1r1[0] = gwentArena.encodeCard(6, 3, 0, 0, 0, 0); // power:4, ability:Tight Bond (Amt 3)
        p1r1[1] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0); // power:1, ability:None (Amt 1)

        // R2: Total 3 cards
        uint256[] memory p1r2 = new uint256[](3);
        p1r2[0] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // power:2, ability:None
        p1r2[1] = gwentArena.encodeCard(7, 1, 0, 0, 0, 0); // power:4, ability:None
        p1r2[2] = gwentArena.encodeCard(8, 1, 0, 0, 0, 0); // power:4, ability:None

        // R3: Total 3 cards (Grand Total = 4 + 3 + 3 = 10)
        uint256[] memory p1r3 = new uint256[](3);
        p1r3[0] = gwentArena.encodeCard(12, 1, 0, 0, 0, 0); // power:5, ability:None
        p1r3[1] = gwentArena.encodeCard(14, 1, 0, 0, 0, 0); // power:5, ability:None
        p1r3[2] = gwentArena.encodeCard(15, 1, 0, 0, 0, 0); // power:5, ability:None

        // P2: Exactly 10 cards (all Amount 1)
        uint256[] memory p2r1 = new uint256[](5);
        p2r1[0] = gwentArena.encodeCard(37, 1, 0, 0, 0, 0); // P6, Agile
        p2r1[1] = gwentArena.encodeCard(38, 1, 0, 0, 0, 0); // P6, Agile
        p2r1[2] = gwentArena.encodeCard(39, 1, 0, 0, 0, 0); // P6, Agile
        p2r1[3] = gwentArena.encodeCard(40, 1, 0, 0, 0, 0); // P6, Agile
        p2r1[4] = gwentArena.encodeCard(41, 1, 0, 0, 0, 0); // P6, Ranged (Total 30)

        uint256[] memory p2r2 = new uint256[](5);
        p2r2[0] = gwentArena.encodeCard(27, 1, 0, 0, 0, 0); // P1, Ranged
        p2r2[1] = gwentArena.encodeCard(29, 1, 0, 0, 0, 0); // P2, Ranged
        p2r2[2] = gwentArena.encodeCard(30, 1, 0, 0, 0, 0); // P3, Agile
        p2r2[3] = gwentArena.encodeCard(32, 1, 0, 0, 0, 0); // P4, Ranged
        p2r2[4] = gwentArena.encodeCard(33, 1, 0, 0, 0, 0); // P4, Ranged (Total 14)

        uint256[] memory p2r3 = new uint256[](0);

        // --- Commit ---
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player2);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Resolve ---
        (upkeepNeeded, pData) = gwentArena.checkUpkeep("");
        require(upkeepNeeded, "Resolution needed");
        gwentArena.performUpkeep(pData);

        // --- Verify ---
        MatchInfo memory info = gwentArena.getMatchInfo(matchId);
        assertEq(
            uint8(info.result),
            uint8(MatchResult.Player1Wins),
            "P1 should win via Tight Bond (Power 36 vs 30)"
        );
    }

    function test_spy_ability_p1_wins() public enterArenaPhase {
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);
        uint256 salt = 54321;

        // Player 1 Hand (Northern): 10 cards total
        uint256[] memory p1r1 = new uint256[](3);

        // Explicitly pre-encode the drawn cards as per the new high-fidelity design
        uint256 c19 = gwentArena.encodeCard(19, 1, 0, 0, 0, 0); // P6 Siege
        uint256 c20 = gwentArena.encodeCard(20, 1, 0, 0, 0, 0); // P6 Siege

        // Pass these encoded cards into the Spy card.
        // With 64-bit slots, they will NOT be truncated, so unpack() will find amount=1 natively!
        p1r1[0] = gwentArena.encodeCard(9, 1, 0, 0, c19, c20);
        p1r1[1] = gwentArena.encodeCard(17, 1, 0, 0, 0, 0); // power:6, ability:None
        p1r1[2] = gwentArena.encodeCard(18, 1, 0, 0, 0, 0); // power:6, ability:None -> Power (6+6) + DRAWN(6+6) = 24

        uint256[] memory p1r2 = new uint256[](3);
        p1r2[0] = gwentArena.encodeCard(12, 1, 0, 0, 0, 0); // power:5, ability:None
        p1r2[1] = gwentArena.encodeCard(14, 1, 0, 0, 0, 0); // power:5, ability:None
        p1r2[2] = gwentArena.encodeCard(15, 1, 0, 0, 0, 0); // power:5, ability:None -> Power 15

        uint256[] memory p1r3 = new uint256[](4);
        p1r3[0] = gwentArena.encodeCard(1, 1, 0, 0, 0, 0); // power:1, ability:Morale
        p1r3[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // power:1, ability:Bond
        p1r3[2] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0); // power:1, ability:None
        p1r3[3] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // power:2, ability:None -> Power 5

        // Player 2 Hand (Scoia'tael): 10 cards total
        uint256[] memory p2r1 = new uint256[](2);
        p2r1[0] = gwentArena.encodeCard(37, 1, 0, 0, 0, 0); // P6, Agile
        p2r1[1] = gwentArena.encodeCard(38, 1, 0, 0, 0, 0); // P6, Agile -> Power 12 + Spy(4) = 16

        uint256[] memory p2r2 = new uint256[](4);
        p2r2[0] = gwentArena.encodeCard(27, 1, 0, 0, 0, 0); // P1, Ranged
        p2r2[1] = gwentArena.encodeCard(29, 1, 0, 0, 0, 0); // P2, Ranged
        p2r2[2] = gwentArena.encodeCard(30, 1, 0, 0, 0, 0); // P3, Agile
        p2r2[3] = gwentArena.encodeCard(32, 1, 0, 0, 0, 0); // P4, Ranged -> Power 10

        uint256[] memory p2r3 = new uint256[](4);
        p2r3[0] = gwentArena.encodeCard(33, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[1] = gwentArena.encodeCard(35, 1, 0, 0, 0, 0); // P5, Agile
        p2r3[2] = gwentArena.encodeCard(36, 1, 0, 0, 0, 0); // P5, Agile
        p2r3[3] = gwentArena.encodeCard(41, 1, 0, 0, 0, 0); // P6, Ranged -> Power 20

        // --- Commit ---
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player2);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Resolve ---
        (bool upkeepNeeded, bytes memory pData) = gwentArena.checkUpkeep("");
        require(upkeepNeeded, "Resolution needed");
        gwentArena.performUpkeep(pData);

        // --- Verify ---
        MatchInfo memory info = gwentArena.getMatchInfo(matchId);
        assertEq(
            uint8(info.result),
            uint8(MatchResult.Player1Wins),
            "P1 should win via Spy draw swing"
        );
    }

    function test_spy_draws_morale_boost() public enterArenaPhase {
        // valid
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);
        uint256 salt = 98765;

        // Player 1 Hand (Northern): 10 cards total
        uint256[] memory p1r1 = new uint256[](2);
        uint256 c1 = gwentArena.encodeCard(1, 1, 0, 0, 0, 0); // P1, Morale (Siege)
        uint256 c17 = gwentArena.encodeCard(17, 1, 0, 0, 0, 0); // P6, Siege
        p1r1[0] = gwentArena.encodeCard(9, 1, 0, 0, c1, c17); // P4, Spy (Close)
        p1r1[1] = gwentArena.encodeCard(19, 1, 0, 0, 0, 0); // P6, Siege

        uint256[] memory p1r2 = new uint256[](4);
        p1r2[0] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // P1, Bond (Close)
        p1r2[1] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0); // P1, None (Close)
        p1r2[2] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // P2, None (Close)
        p1r2[3] = gwentArena.encodeCard(7, 1, 0, 0, 0, 0); // P4, Ranged

        uint256[] memory p1r3 = new uint256[](4);
        p1r3[0] = gwentArena.encodeCard(8, 1, 0, 0, 0, 0); // P4, Ranged
        p1r3[1] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // P5, Bond (Ranged)
        p1r3[2] = gwentArena.encodeCard(11, 1, 0, 0, 0, 0); // P5, Medic (Siege)
        p1r3[3] = gwentArena.encodeCard(12, 1, 0, 0, 0, 0); // P5, Ranged -> Total P1: 2 + 4 + 4 = 10 ✅

        // Player 2 Hand (Scoia'tael): 10 cards total
        uint256[] memory p2r1 = new uint256[](1);
        p2r1[0] = gwentArena.encodeCard(37, 1, 0, 0, 0, 0); // P6, Agile + Spy(4) = 10

        uint256[] memory p2r2 = new uint256[](5);
        p2r2[0] = gwentArena.encodeCard(26, 1, 0, 0, 0, 0); // P0, Medic (Ranged)
        p2r2[1] = gwentArena.encodeCard(27, 1, 0, 0, 0, 0); // P1, Ranged
        p2r2[2] = gwentArena.encodeCard(28, 1, 0, 0, 0, 0); // P2, Muster (Ranged)
        p2r2[3] = gwentArena.encodeCard(29, 1, 0, 0, 0, 0); // P2, Ranged
        p2r2[4] = gwentArena.encodeCard(30, 1, 0, 0, 0, 0); // P3, Agile

        uint256[] memory p2r3 = new uint256[](4);
        p2r3[0] = gwentArena.encodeCard(31, 1, 0, 0, 0, 0); // P3, Muster (Ranged)
        p2r3[1] = gwentArena.encodeCard(32, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[2] = gwentArena.encodeCard(33, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[3] = gwentArena.encodeCard(35, 1, 0, 0, 0, 0); // P5, Agile -> Total P2: 1 + 5 + 4 = 10 ✅

        // --- Commit ---
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player2);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Resolve ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);

        // --- Verify ---
        // P1 Round 1 should be 15. P2 Round 1 should be 10.
    }

    function test_spy_draws_horn() public {
        //valid
        uint256 salt = 12345;

        // 1. Setup Deck with Horn and Siege
        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        for (uint256 i = 0; i < 22; i++) {
            p1Deck[i] = player1carddeck[i];
            p1Amount[i] = player1carddeckamount[i];
        }
        p1Deck[22] = 137; // Northern Ranged Horn
        p1Amount[22] = 3; // MAX 3 SPECIAL CARDS ALLOWED!

        // 2. Mint cards before entering Arena
        gwentCardToken.mint(player1, 137, 3);
        gwentCardToken.mint(player1, 17, 10); // Siege unit for drawing

        // 3. Enter Arena for both players
        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(
            Faction.Scoiatael,
            player2carddeck,
            player2carddeckamount
        );
        vm.stopPrank();

        // 4. Trigger Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        // Player 1 Hand (Northern): 10 cards total
        uint256[] memory p1r1 = new uint256[](2);

        // P32: Choice, P16: Row
        // ID 137 targeted at Row 1 (Ranged)
        uint256 cHorn = gwentArena.encodeCard(137, 1, 1, 0, 0, 0); // Horn Special (Ranged)
        uint256 c17 = gwentArena.encodeCard(17, 1, 2, 0, 0, 0); // P6, Siege

        p1r1[0] = gwentArena.encodeCard(9, 1, 0, 0, cHorn, c17); // P4, Spy (Close)
        p1r1[1] = gwentArena.encodeCard(18, 1, 1, 0, 0, 0); // P6, Ranged (Targeted)
        // Expected R1: Row 1 (6 * 2) + Row 2 (6) = 18

        uint256[] memory p1r2 = new uint256[](4);
        p1r2[0] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // P1, Bond (Close)
        p1r2[1] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0); // P1, None (Close)
        p1r2[2] = gwentArena.encodeCard(4, 1, 0, 0, 0, 0); // P1, Spy (Siege)
        p1r2[3] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // P2, None (Close)

        uint256[] memory p1r3 = new uint256[](4);
        p1r3[0] = gwentArena.encodeCard(21, 1, 0, 0, 0, 0); // P6, Bond (Siege)
        p1r3[1] = gwentArena.encodeCard(22, 1, 0, 0, 0, 0); // P10, Hero (Close)
        p1r3[2] = gwentArena.encodeCard(11, 1, 0, 0, 0, 0); // P5, Medic (Siege)
        p1r3[3] = gwentArena.encodeCard(12, 1, 0, 0, 0, 0); // P5, Ranged -> Total P1: 2 + 4 + 4 = 10 ✅

        // Player 2 Hand (Scoia'tael): 10 cards total
        uint256[] memory p2r1 = new uint256[](1);
        p2r1[0] = gwentArena.encodeCard(37, 1, 0, 0, 0, 0); // P6 + Spy(4) = 10

        uint256[] memory p2r2 = new uint256[](5);
        for (uint16 i = 0; i < 5; i++)
            p2r2[i] = gwentArena.encodeCard(uint16(26 + i), 1, 0, 0, 0, 0); // P0-P3, Ranged/Agile
        uint256[] memory p2r3 = new uint256[](4);
        for (uint16 i = 0; i < 4; i++)
            p2r3[i] = gwentArena.encodeCard(uint16(31 + i), 1, 0, 0, 0, 0); // P3-P5, Ranged/Agile

        // --- Commit ---
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player2);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Resolve ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }

    function test_spy_morale_horn() public {
        //valid
        uint256 salt = 12345;

        // 1. Setup Deck with Horn (137) and Siege units
        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        for (uint256 i = 0; i < 22; i++) {
            p1Deck[i] = player1carddeck[i];
            p1Amount[i] = player1carddeckamount[i];
        }
        p1Deck[22] = 137; // Horn
        p1Amount[22] = 3;

        // 2. Mint cards before entering Arena
        gwentCardToken.mint(player1, 137, 3); // Horn
        gwentCardToken.mint(player1, 1, 1); // Morale Siege
        gwentCardToken.mint(player1, 9, 1); // Spy Northern
        gwentCardToken.mint(player1, 17, 10);
        gwentCardToken.mint(player1, 19, 10);

        // Setup Player 2 Deck (Scoia'tael 26-48)
        uint256[] memory p2Deck = new uint256[](22);
        uint256[] memory p2Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player2carddeck[i];
            p2Amount[i] = player2carddeckamount[i];
        }

        // 3. Enter Arena
        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Scoiatael, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        // --- P1 Hand (10 Total Across Rounds) ---
        uint256[] memory p1r1 = new uint256[](3);
        uint256 cHorn = gwentArena.encodeCard(137, 1, 2, 0, 0, 0); // Horn Special (Siege)
        uint256 cMorale = gwentArena.encodeCard(1, 1, 2, 0, 0, 0); // P1, Morale (Siege)
        p1r1[0] = gwentArena.encodeCard(17, 1, 2, 0, 0, 0); // P6, Siege
        p1r1[1] = gwentArena.encodeCard(19, 1, 2, 0, 0, 0); // P6, Siege
        p1r1[2] = gwentArena.encodeCard(9, 1, 0, 0, cHorn, cMorale); // P4, Spy (Close) -> Draws Horn and Morale

        uint256[] memory p1r2 = new uint256[](4);
        p1r2[0] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // P1, Bond (Close)
        p1r2[1] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0); // P1, None (Close)
        p1r2[2] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // P2, None (Close)
        p1r2[3] = gwentArena.encodeCard(7, 1, 0, 0, 0, 0); // P4, Ranged

        uint256[] memory p1r3 = new uint256[](3);
        p1r3[0] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // P5, Bond (Ranged)
        p1r3[1] = gwentArena.encodeCard(11, 1, 0, 0, 0, 0); // P5, Medic (Siege)
        p1r3[2] = gwentArena.encodeCard(12, 1, 0, 0, 0, 0); // P5, Ranged -> Total 3 + 4 + 3 = 10 ✅

        // --- P2 Hand (10 Total Across Rounds) ---
        uint256[] memory p2r1 = new uint256[](1);
        p2r1[0] = gwentArena.encodeCard(37, 1, 0, 0, 0, 0); // P6, Agile

        uint256[] memory p2r2 = new uint256[](5);
        p2r2[0] = gwentArena.encodeCard(26, 1, 0, 0, 0, 0); // P0, Medic (Ranged)
        p2r2[1] = gwentArena.encodeCard(27, 1, 0, 0, 0, 0); // P1, Ranged
        p2r2[2] = gwentArena.encodeCard(28, 1, 0, 0, 0, 0); // P2, Muster (Ranged)
        p2r2[3] = gwentArena.encodeCard(29, 1, 0, 0, 0, 0); // P2, Ranged
        p2r2[4] = gwentArena.encodeCard(30, 1, 0, 0, 0, 0); // P3, Agile

        uint256[] memory p2r3 = new uint256[](4);
        p2r3[0] = gwentArena.encodeCard(31, 1, 0, 0, 0, 0); // P3, Muster (Ranged)
        p2r3[1] = gwentArena.encodeCard(32, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[2] = gwentArena.encodeCard(33, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[3] = gwentArena.encodeCard(34, 1, 0, 0, 0, 0); // P5, Muster (Ranged) -> Total 1 + 5 + 4 = 10 ✅

        // --- Commit ---
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player2);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Resolve ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }

    function test_muster_ability() public {
        //VALID
        uint256 salt = 12345;
        // 1. Setup Player 1 Deck (Northern 1-25)
        uint256[] memory p1Deck = new uint256[](22);
        uint256[] memory p1Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player1carddeck[i];
            p1Amount[i] = player1carddeckamount[i];
        }

        // 2. Setup Player 2 Deck (Scoia'tael 26-48)
        uint256[] memory p2Deck = new uint256[](22);
        uint256[] memory p2Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player2carddeck[i];
            p2Amount[i] = player2carddeckamount[i];
            // Ensure ID 28 has amount 3 for Muster test
            if (p2Deck[i] == 28) {
                p2Amount[i] = 3;
            }
        }

        // Mint the specific cards needed
        gwentCardToken.mint(player2, 28, 3);

        // 3. Enter Arena
        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Scoiatael, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        // --- P1 Hand (10 Total Across Rounds) ---
        uint256[] memory p1r1 = new uint256[](3);
        p1r1[0] = gwentArena.encodeCard(1, 1, 2, 0, 0, 0); // P1, Morale (Siege)
        p1r1[1] = gwentArena.encodeCard(17, 1, 2, 0, 0, 0); // P6, Siege
        p1r1[2] = gwentArena.encodeCard(19, 1, 2, 0, 0, 0); // P6, Siege

        uint256[] memory p1r2 = new uint256[](4);
        p1r2[0] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // P1, Bond (Close)
        p1r2[1] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0); // P1, None (Close)
        p1r2[2] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // P2, None (Close)
        p1r2[3] = gwentArena.encodeCard(7, 1, 0, 0, 0, 0); // P4, Ranged

        uint256[] memory p1r3 = new uint256[](3);
        p1r3[0] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // P5, Bond (Ranged)
        p1r3[1] = gwentArena.encodeCard(11, 1, 0, 0, 0, 0); // P5, Medic (Siege)
        p1r3[2] = gwentArena.encodeCard(12, 1, 0, 0, 0, 0); // P5, Ranged

        // --- P2 Hand (10 Total Across Rounds) ---
        uint256[] memory p2r1 = new uint256[](1);
        // Play 1x ID 28. Should muster the other 2.
        p2r1[0] = gwentArena.encodeCard(28, 1, 1, 0, 0, 0); // P2, Muster (Ranged)

        uint256[] memory p2r2 = new uint256[](5);
        p2r2[0] = gwentArena.encodeCard(26, 1, 0, 0, 0, 0); // P0, Medic (Ranged)
        p2r2[1] = gwentArena.encodeCard(27, 1, 0, 0, 0, 0); // P1, Ranged
        p2r2[2] = gwentArena.encodeCard(29, 1, 0, 0, 0, 0); // P2, Ranged
        p2r2[3] = gwentArena.encodeCard(30, 1, 0, 0, 0, 0); // P3, Agile
        p2r2[4] = gwentArena.encodeCard(31, 1, 0, 0, 0, 0); // P3, Muster (Ranged)

        uint256[] memory p2r3 = new uint256[](4);
        p2r3[0] = gwentArena.encodeCard(32, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[1] = gwentArena.encodeCard(33, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[2] = gwentArena.encodeCard(34, 1, 0, 0, 0, 0); // P5, Muster (Ranged)
        p2r3[3] = gwentArena.encodeCard(35, 1, 0, 0, 0, 0); // P5, Agile

        // --- Commit ---
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player2);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }
    function test_muster_ability_2() public {
        //VALID
        uint256 salt = 12345;
        // 1. Setup Player 1 Deck (Northern 1-25)
        uint256[] memory p1Deck = new uint256[](22);
        uint256[] memory p1Amount = new uint256[](22);
        // monster is 78-112
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player3carddeck[i];
            p1Amount[i] = player3carddeckamount[i];
        }

        // 2. Setup Player 2 Deck (Scoia'tael 26-48)
        uint256[] memory p2Deck = new uint256[](22);
        uint256[] memory p2Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player2carddeck[i];
            p2Amount[i] = player2carddeckamount[i];
            // Ensure ID 28 has amount 3 for Muster test
            if (p2Deck[i] == 28) {
                p2Amount[i] = 3;
            }
        }

        // Mint the specific cards needed
        gwentCardToken.mint(player2, 28, 3);

        // 3. Enter Arena
        vm.startPrank(player3);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Monster, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Scoiatael, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        // --- P1 Hand (10 Total Across Rounds) ---
        uint256[] memory p1r1 = new uint256[](1);
        p1r1[0] = gwentArena.encodeCard(89, 1, 0, 0, 0, 0); // P4, close combat muster, should summon the other related muster card with them in this round => power 21

        uint256[] memory p1r2 = new uint256[](1);
        p1r2[0] = gwentArena.encodeCard(89, 1, 0, 0, 0, 0); // P4, close combat,this couldnt call muster because we use all muster in round 1. => power 4 only

        uint256[] memory p1r3 = new uint256[](0);

        // --- P2 Hand (10 Total Across Rounds) ---
        uint256[] memory p2r1 = new uint256[](1);
        // Play 1x ID 28. Should muster the other 2.
        p2r1[0] = gwentArena.encodeCard(28, 1, 1, 0, 0, 0); // P2, Muster (Ranged)

        uint256[] memory p2r2 = new uint256[](5);
        p2r2[0] = gwentArena.encodeCard(26, 1, 0, 0, 0, 0); // P0, Medic (Ranged)
        p2r2[1] = gwentArena.encodeCard(27, 1, 0, 0, 0, 0); // P1, Ranged
        p2r2[2] = gwentArena.encodeCard(29, 1, 0, 0, 0, 0); // P2, Ranged
        p2r2[3] = gwentArena.encodeCard(30, 1, 0, 0, 0, 0); // P3, Agile
        p2r2[4] = gwentArena.encodeCard(31, 1, 0, 0, 0, 0); // P3, Muster (Ranged)

        uint256[] memory p2r3 = new uint256[](4);
        p2r3[0] = gwentArena.encodeCard(32, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[1] = gwentArena.encodeCard(33, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[2] = gwentArena.encodeCard(34, 1, 0, 0, 0, 0); // P5, Muster (Ranged)
        p2r3[3] = gwentArena.encodeCard(35, 1, 0, 0, 0, 0); // P5, Agile

        // --- Commit ---
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        vm.prank(player3);
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player2);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player3);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        uint256[3] memory p1Expected = [uint256(21), 4, 0];
        uint256[3] memory p2Expected = [uint256(6), 9, 18];
        vm.expectEmit(true, false, false, true);
        /* 
            checkTopic1 (True): Check the 1st indexed parameter (matchId).
            checkTopic2 (False/True): Check the 2nd indexed parameter. (Your event doesn't have one, so this is usually ignored).
            checkTopic3 (False/True): Check the 3rd indexed parameter. (You don't have one).
            checkData (True): Check ALL other parameters that are NOT indexed.
        */
        // 2. Emit the "Expected" event yourself
        emit MatchResolved(
            matchId,
            MatchResult.Player2Wins,
            player2,
            25,
            33,
            p1Expected, // [21, 4, 0]
            p2Expected
        );
        gwentArena.performUpkeep(pData);
    }
    function test_muster_ability_3_with_commander_horn() public {
        //VALID
        uint256 salt = 12345;
        // 1. Setup Player 1 Deck (Northern 1-25)
        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        // monster is 78-112
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player3carddeck[i];
            p1Amount[i] = player3carddeckamount[i];
            if (p1Deck[i] == 78) {
                p1Amount[i] = 3;
            }
        }
        p1Deck[22] = 137;
        p1Amount[22] = 1;

        gwentCardToken.mint(player3, 78, 2);
        gwentCardToken.mint(player3, 137, 1);
        // 2. Setup Player 2 Deck (Scoia'tael 26-48)
        uint256[] memory p2Deck = new uint256[](22);
        uint256[] memory p2Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player2carddeck[i];
            p2Amount[i] = player2carddeckamount[i];
            // Ensure ID 28 has amount 3 for Muster test
            if (p2Deck[i] == 28) {
                p2Amount[i] = 3;
            }
        }

        // Mint the specific cards needed
        gwentCardToken.mint(player2, 28, 3);

        // 3. Enter Arena
        vm.startPrank(player3);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Monster, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Scoiatael, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        // --- P1 Hand (10 Total Across Rounds) ---
        uint256[] memory p1r1 = new uint256[](2);
        p1r1[0] = gwentArena.encodeCard(89, 1, 0, 0, 0, 0); // P4, close combat muster, should summon the other related muster card with them in this round => power 21 ( 4 + 4 + 4 + 5)
        p1r1[1] = gwentArena.encodeCard(137, 1, 0, 0, 0, 0); // commander horn apply for close combat row => 21 * 2 = 42

        uint256[] memory p1r2 = new uint256[](2);
        p1r2[0] = gwentArena.encodeCard(89, 1, 0, 0, 0, 0); // P4, close combat,this couldnt call muster because we use all muster in round 1. => power 4 only
        p1r2[1] = gwentArena.encodeCard(78, 1, 0, 0, 0, 0); // p1, ranged muster ,summon the other related muster card with them in this round => 1 + 1 + 1 = 3

        // total : 4 + 3 = 7

        uint256[] memory p1r3 = new uint256[](0);

        // --- P2 Hand (10 Total Across Rounds) ---
        uint256[] memory p2r1 = new uint256[](1);
        // Play 1x ID 28. Should muster the other 2.
        p2r1[0] = gwentArena.encodeCard(28, 1, 1, 0, 0, 0); // P2, Muster (Ranged)

        uint256[] memory p2r2 = new uint256[](5);
        p2r2[0] = gwentArena.encodeCard(26, 1, 0, 0, 0, 0); // P0, Medic (Ranged)
        p2r2[1] = gwentArena.encodeCard(27, 1, 0, 0, 0, 0); // P1, Ranged
        p2r2[2] = gwentArena.encodeCard(29, 1, 0, 0, 0, 0); // P2, Ranged
        p2r2[3] = gwentArena.encodeCard(30, 1, 0, 0, 0, 0); // P3, Agile
        p2r2[4] = gwentArena.encodeCard(31, 1, 0, 0, 0, 0); // P3, Muster (Ranged)

        uint256[] memory p2r3 = new uint256[](4);
        p2r3[0] = gwentArena.encodeCard(32, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[1] = gwentArena.encodeCard(33, 1, 0, 0, 0, 0); // P4, Ranged
        p2r3[2] = gwentArena.encodeCard(34, 1, 0, 0, 0, 0); // P5, Muster (Ranged)
        p2r3[3] = gwentArena.encodeCard(35, 1, 0, 0, 0, 0); // P5, Agile

        // --- Commit ---
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        vm.prank(player3);
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player2);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player3);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        uint256[3] memory p1Expected = [uint256(42), 7, 0];
        uint256[3] memory p2Expected = [uint256(6), 9, 18];
        vm.expectEmit(true, false, false, true);
        emit MatchResolved(
            matchId,
            MatchResult.Player2Wins,
            player2,
            49,
            33,
            p1Expected, // [21, 4, 0]
            p2Expected
        );
        gwentArena.performUpkeep(pData);
    }

    function test_berserker_no_transformation() public {
        //valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](22);
        uint256[] memory p1Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](22);
        uint256[] memory p2Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }

        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](1);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // Berserker. Base 4. Close(0). 🐻

        uint256[] memory p1r2 = new uint256[](5);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close p4
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close p4
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close p4
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close p4
        p1r2[4] = gwentArena.encodeCard(122, 1, 2, 0, 0, 0); // Siege p4

        uint256[] memory p1r3 = new uint256[](4);
        p1r3[0] = gwentArena.encodeCard(123, 1, 1, 0, 0, 0); // Ranged(1)
        p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)
        p1r3[2] = gwentArena.encodeCard(125, 1, 0, 0, 0, 0); // Close(0)
        p1r3[3] = gwentArena.encodeCard(126, 1, 0, 0, 0, 0); // Close(0)

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 2, 0, 0, 0); // ID 1. Siege(2). ✅
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // Close(0)
        p2r1[2] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0); // Close(0)

        uint256[] memory p2r2 = new uint256[](4);
        p2r2[0] = gwentArena.encodeCard(4, 1, 2, 0, 0, 0); // ID 4. Siege(2). ✅
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // Close(0)
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Close(0)
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // Ranged(1). ✅

        uint256[] memory p2r3 = new uint256[](3);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // Ranged(1). ✅
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // Close(0)
        p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // Close(0)

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }
    function test_berserker_transformation() public {
        // Valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }
        p1Deck[22] = 136;
        p1Amount[22] = 1;

        gwentCardToken.mint(player4, 136, 1);

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](22);
        uint256[] memory p2Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }

        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](3);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // Berserker. Base 4. berserker 14 Close(0). 🐻

        p1r1[1] = gwentArena.encodeCard(136, 1, 0, 0, 0, 0); // mardrome target row close combat

        p1r1[2] = gwentArena.encodeCard(113, 1, 0, 0, 0, 0); // berserker . base 0 berserker 11

        uint256[] memory p1r2 = new uint256[](5);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close(0)
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close(0)
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close(0)
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close(0)
        p1r2[4] = gwentArena.encodeCard(122, 1, 0, 0, 0, 0); // Siege(2)

        uint256[] memory p1r3 = new uint256[](2);
        p1r3[0] = gwentArena.encodeCard(123, 1, 0, 0, 0, 0); // Ranged(1)
        p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 2, 0, 0, 0); // ID 1. Siege(2). ✅
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // Close(0)
        p2r1[2] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0); // Close(0)

        uint256[] memory p2r2 = new uint256[](4);
        p2r2[0] = gwentArena.encodeCard(4, 1, 2, 0, 0, 0); // ID 4. Siege(2). ✅
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // Close(0)
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Close(0)
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // Ranged(1). ✅

        uint256[] memory p2r3 = new uint256[](3);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // Ranged(1). ✅
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // Close(0)
        p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // Close(0)

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }
    function test_berserker_transformation_under_weather() public {
        // Valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }
        p1Deck[22] = 136;
        p1Amount[22] = 1;

        gwentCardToken.mint(player4, 136, 1);

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](23);
        uint256[] memory p2Amount = new uint256[](23);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }
        p2Deck[22] = 140;
        p2Amount[22] = 1;

        gwentCardToken.mint(player1, 140, 1);

        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](3);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // Berserker. Base 4. berserker 14 Close(0). 🐻

        p1r1[1] = gwentArena.encodeCard(136, 1, 0, 0, 0, 0); // mardrome target row close combat

        p1r1[2] = gwentArena.encodeCard(113, 1, 0, 0, 0, 0); // berserker . base 0 berserker 11

        uint256[] memory p1r2 = new uint256[](5);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close(0)
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close(0)
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close(0)
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close(0)
        p1r2[4] = gwentArena.encodeCard(122, 1, 0, 0, 0, 0); // Siege(2)

        uint256[] memory p1r3 = new uint256[](2);
        p1r3[0] = gwentArena.encodeCard(123, 1, 0, 0, 0, 0); // Ranged(1)
        p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 2, 0, 0, 0); // ID 1. Siege(2). ✅
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // Close(0)
        p2r1[2] = gwentArena.encodeCard(140, 1, 0, 0, 0, 0); // Close(0)

        uint256[] memory p2r2 = new uint256[](4);
        p2r2[0] = gwentArena.encodeCard(4, 1, 2, 0, 0, 0); // ID 4. Siege(2). ✅
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // Close(0)
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Close(0)
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // Ranged(1). ✅

        uint256[] memory p2r3 = new uint256[](3);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // Ranged(1). ✅
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // Close(0)
        p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // Close(0)

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        uint256[3] memory p1Expected = [uint256(23), 21, 12];
        vm.expectEmit(true, false, false, true);
        emit MatchResolved(
            matchId,
            MatchResult.Player1Wins,
            player4,
            56,
            21,
            p1Expected,
            [uint256(2), 10, 9]
        );
        gwentArena.performUpkeep(pData);
    }
    function test_berserker_transformation_under_weather_with_commander_horn()
        public
    {
        // Valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }
        p1Deck[22] = 137;
        p1Amount[22] = 1;

        gwentCardToken.mint(player4, 137, 1);

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](23);
        uint256[] memory p2Amount = new uint256[](23);

        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }
        p2Deck[22] = 140;
        p2Amount[22] = 1;

        gwentCardToken.mint(player1, 140, 1);

        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](4);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // closecombat Berserker. Base 4. berserker 14 Close(0). 🐻

        p1r1[1] = gwentArena.encodeCard(137, 1, 0, 0, 0, 0); // commander_horn target row 1

        p1r1[2] = gwentArena.encodeCard(113, 1, 0, 0, 0, 0); // closecombat berserker . base 0 berserker 11

        p1r1[3] = gwentArena.encodeCard(114, 0, 0, 0, 0, 0); // p2 mardroeme target close combat row

        // without weather: (14 + 11 + 2) * 2 = 54
        // with weather: (1 + (14-4) + 1 + 11 + 1) * 2 = 48

        uint256[] memory p1r2 = new uint256[](5);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close(0) p4
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close(0) p4
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close(0) p4
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close(0) p4
        p1r2[4] = gwentArena.encodeCard(122, 1, 0, 0, 0, 0); // Siege(2) p4

        // 4 * 5 + 1(spy) = 21

        uint256[] memory p1r3 = new uint256[](1);
        p1r3[0] = gwentArena.encodeCard(123, 1, 0, 0, 0, 0); // Ranged(1) p4 mardrome
        // p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)

        // 4 + 4(spy) = 8

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 2, 0, 0, 0); // Siege(2) p1
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // Close(0) p1
        p2r1[2] = gwentArena.encodeCard(140, 1, 0, 0, 0, 0); // close combat set 1

        // 1 + 1 = 2

        uint256[] memory p2r2 = new uint256[](4);
        p2r2[0] = gwentArena.encodeCard(4, 1, 2, 0, 0, 0); // Siege(2) p1 spy
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // Close(0) p2
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Close(0) p4 tight
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // Ranged(1). p4

        // 4 + 4 + 2 = 10

        uint256[] memory p2r3 = new uint256[](3);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // Ranged(1). p4
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // Close(0) p4 spy
        p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // Close(0) p5 tight

        // 4 + 5 = 9

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        uint256[3] memory p1Expected = [uint256(48), 21, 8];
        vm.expectEmit(true, false, false, true);
        emit MatchResolved(
            matchId,
            MatchResult.Player1Wins,
            player4,
            77,
            21,
            p1Expected,
            [uint256(2), 10, 9]
        );
        gwentArena.performUpkeep(pData);
    }
    function test_berserker_Invalid_transformation_2_mardrome() public {
        // Valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }
        p1Deck[22] = 136;
        p1Amount[22] = 1;

        gwentCardToken.mint(player4, 136, 2);

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](22);
        uint256[] memory p2Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }

        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](4);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // Berserker. Base 4. berserker 14 Close(0). 🐻

        p1r1[1] = gwentArena.encodeCard(136, 0, 0, 0, 0, 0); // mardrome target row close combat

        p1r1[2] = gwentArena.encodeCard(136, 1, 0, 0, 0, 0); // mardrome target row ranged

        p1r1[3] = gwentArena.encodeCard(116, 1, 0, 0, 0, 0); // Berserker. Base 2. berserker 8 ranged

        uint256[] memory p1r2 = new uint256[](4);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close(0)
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close(0)
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close(0)
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close(0)

        uint256[] memory p1r3 = new uint256[](2);
        p1r3[0] = gwentArena.encodeCard(123, 1, 1, 0, 0, 0); // Ranged(1)
        p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 2, 0, 0, 0); // P1, Morale (Siege)
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // P1, Bond (Close)
        p2r1[2] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0); // P1, None (Close)

        uint256[] memory p2r2 = new uint256[](4);
        p2r2[0] = gwentArena.encodeCard(4, 1, 0, 0, 0, 0); // P1, Spy (Siege)
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // P2, None (Close)
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // P4, Bond (Close)
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // P4, Ranged

        uint256[] memory p2r3 = new uint256[](3);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // P4, Ranged
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // P4, Spy (Close)
        p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // P5, Bond (Ranged)

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }
    function test_scorch_ability() public {
        // Valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }
        p1Deck[22] = 136; // Mardroeme Special
        p1Amount[22] = 1;

        gwentCardToken.mint(player4, 136, 1);

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](23);
        uint256[] memory p2Amount = new uint256[](23);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }

        p2Deck[22] = 139; // Scorch Special
        p2Amount[22] = 1;

        gwentCardToken.mint(player1, 139, 1);
        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](3);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // Berserker. Base 4. berserker 14 Close(0). 🐻

        p1r1[1] = gwentArena.encodeCard(136, 1, 0, 0, 0, 0); // mardrome target row close combat

        p1r1[2] = gwentArena.encodeCard(113, 1, 0, 4, 0, 0); // berserker . base 0 berserker 11

        uint256[] memory p1r2 = new uint256[](5);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close(0)
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close(0)
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close(0)
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close(0)
        p1r2[4] = gwentArena.encodeCard(122, 1, 0, 0, 0, 0); // Siege(2)

        uint256[] memory p1r3 = new uint256[](2);
        p1r3[0] = gwentArena.encodeCard(123, 1, 0, 0, 0, 0); // Ranged(1)
        p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 0, 0, 0, 0); // ID 1. Siege(2). ✅
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // Close(0)
        p2r1[2] = gwentArena.encodeCard(139, 1, 0, 0, 0, 0); // scorch disable berserker

        uint256[] memory p2r2 = new uint256[](4);
        p2r2[0] = gwentArena.encodeCard(4, 1, 0, 0, 0, 0); // ID 4. Siege(2). ✅
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // Close(0)
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Close(0)
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // Ranged(1). ✅

        uint256[] memory p2r3 = new uint256[](3);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // Ranged(1). ✅
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // Close(0)
        p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // Close(0)

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }
    function test_decoy_ability() public {
        // Valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }

        p1Deck[22] = 138;
        p1Amount[22] = 1;

        gwentCardToken.mint(player4, 138, 1);

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](23);
        uint256[] memory p2Amount = new uint256[](23);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }

        p2Deck[22] = 139;
        p2Amount[22] = 1;

        gwentCardToken.mint(player1, 139, 1);
        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](4);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // Berserker. Base 4. berserker 14 Close(0). 🐻

        p1r1[1] = gwentArena.encodeCard(114, 1, 0, 0, 0, 0); // mardrome target row close combat power 2

        p1r1[2] = gwentArena.encodeCard(113, 1, 0, 4, 0, 0); // berserker . base 0 berserker 11

        p1r1[3] = gwentArena.encodeCard(138, 1, 0, 0, 0, 0); // decoy protect berserker power

        uint256[] memory p1r2 = new uint256[](4);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close(0)
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close(0)
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close(0)
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close(0)

        uint256[] memory p1r3 = new uint256[](2);
        p1r3[0] = gwentArena.encodeCard(123, 1, 0, 0, 0, 0); // Ranged(1)
        p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 0, 0, 0, 0); // ID 1. Siege(2). ✅
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // Close(0)
        p2r1[2] = gwentArena.encodeCard(139, 1, 0, 0, 0, 0); // scorch disable berserker

        uint256[] memory p2r2 = new uint256[](4);
        p2r2[0] = gwentArena.encodeCard(4, 1, 0, 0, 0, 0); // ID 4. Siege(2). ✅
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // Close(0)
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Close(0)
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // Ranged(1). ✅

        uint256[] memory p2r3 = new uint256[](3);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // Ranged(1). ✅
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // Close(0)
        p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // Close(0)

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }
    function test_weather_and_agile_ability() public {
        // Valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](24);
        uint256[] memory p1Amount = new uint256[](24);
        for (uint16 i = 0; i < 23; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }

        p1Deck[23] = 138;
        p1Amount[23] = 1;

        gwentCardToken.mint(player4, 138, 1);

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](24);
        uint256[] memory p2Amount = new uint256[](24);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }

        p2Deck[22] = 139;
        p2Amount[22] = 1;

        p2Deck[23] = 140;
        p2Amount[23] = 1;

        gwentCardToken.mint(player1, 139, 1);
        gwentCardToken.mint(player1, 140, 1);
        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](4);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // Berserker. Base 4. berserker 14 Close(0). 🐻

        p1r1[1] = gwentArena.encodeCard(114, 1, 0, 0, 0, 0); // mardrome target row close combat power 2

        p1r1[2] = gwentArena.encodeCard(113, 1, 0, 4, 0, 0); // berserker . base 0 berserker 11

        p1r1[3] = gwentArena.encodeCard(138, 1, 0, 0, 0, 0); // decoy protect berserker power

        uint256[] memory p1r2 = new uint256[](5);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close p4
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close p4
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close p4
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close p4 => total : 16 + spy power1 = 17
        p1r2[4] = gwentArena.encodeCard(135, 1, 1, 0, 0, 0); // agile p12 morale_boost

        uint256[] memory p1r3 = new uint256[](1);
        p1r3[0] = gwentArena.encodeCard(123, 1, 0, 0, 0, 0); // Ranged(1)
        // p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 0, 0, 0, 0); // ID 1. Siege(2). ✅
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // Close(0)
        p2r1[2] = gwentArena.encodeCard(139, 1, 0, 0, 0, 0); // scorch disable berserker

        uint256[] memory p2r2 = new uint256[](5);
        p2r2[0] = gwentArena.encodeCard(4, 1, 0, 0, 0, 0); // ID 4. Siege(2). spy p1 ✅
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // Close(0) p2
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Close(0) p4
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // Ranged(1). p4
        p2r2[4] = gwentArena.encodeCard(140, 1, 0, 0, 0, 0); // weather set close combat to 1

        uint256[] memory p2r3 = new uint256[](2);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // Ranged(1).
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // Close(0)
        // p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // Close(0)

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }
    function test_two_weather_ability() public {
        // Valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](25);
        uint256[] memory p1Amount = new uint256[](25);
        for (uint16 i = 0; i < 23; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }

        p1Deck[23] = 138;
        p1Amount[23] = 1;

        p1Deck[24] = 142; // weather set ranged to 1;
        p1Amount[24] = 1;

        gwentCardToken.mint(player4, 138, 1);
        gwentCardToken.mint(player4, 142, 1);

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](24);
        uint256[] memory p2Amount = new uint256[](24);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }

        p2Deck[22] = 139;
        p2Amount[22] = 1;

        p2Deck[23] = 140; //weather set close combat to 1
        p2Amount[23] = 1;

        gwentCardToken.mint(player1, 139, 1);
        gwentCardToken.mint(player1, 140, 1);
        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](4);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // Berserker. Base 4. berserker 14 Close(0). 🐻

        p1r1[1] = gwentArena.encodeCard(114, 1, 0, 0, 0, 0); // mardrome target row close combat power 2

        p1r1[2] = gwentArena.encodeCard(113, 1, 0, 4, 0, 0); // berserker . base 0 berserker 11

        p1r1[3] = gwentArena.encodeCard(138, 1, 0, 0, 0, 0); // decoy protect berserker power

        uint256[] memory p1r2 = new uint256[](5);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close p4
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close p4
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close p4
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close p4 => total close combat : 16 + spy power1(siege) = 17
        p1r2[4] = gwentArena.encodeCard(142, 1, 1, 0, 0, 0); // weather set ranged to 1

        // weather set close combat to 1 : 1 + 1 + 1 + 1 + 1(spy) = 5

        uint256[] memory p1r3 = new uint256[](1);
        p1r3[0] = gwentArena.encodeCard(123, 1, 0, 0, 0, 0); // Ranged(1)
        // p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 0, 0, 0, 0); // ID 1. Siege(2). ✅
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // Close(0)
        p2r1[2] = gwentArena.encodeCard(139, 1, 0, 0, 0, 0); // scorch disable berserker

        uint256[] memory p2r2 = new uint256[](5);
        p2r2[0] = gwentArena.encodeCard(4, 1, 0, 0, 0, 0); // ID 4. Siege(2). spy p1 ✅
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // Close(0) p2
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Close(0) p4
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // Ranged(1). p4
        p2r2[4] = gwentArena.encodeCard(140, 1, 0, 0, 0, 0); // weather set close combat to 1

        // weather set close combat to 1: 1 + 1 = 2
        // weather set ranged to 1 : 1

        // total : 2 + 1 = 3

        uint256[] memory p2r3 = new uint256[](2);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // Ranged(1).
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // Close(0)
        // p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // Close(0)

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }
    function test_clearweather() public {
        // Valid
        uint256 salt = 12345;
        // 1. Setup Player 4 Deck (Skellige)
        uint256[] memory p1Deck = new uint256[](25);
        uint256[] memory p1Amount = new uint256[](25);
        for (uint16 i = 0; i < 23; i++) {
            p1Deck[i] = player4carddeck[i];
            p1Amount[i] = player4carddeckamount[i];
        }

        p1Deck[23] = 138;
        p1Amount[23] = 1;

        p1Deck[24] = 141; // clear weather
        p1Amount[24] = 1;

        gwentCardToken.mint(player4, 138, 1);
        gwentCardToken.mint(player4, 141, 1);

        // 2. Setup Player 1 Deck (Northern)
        uint256[] memory p2Deck = new uint256[](24);
        uint256[] memory p2Amount = new uint256[](24);
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player1carddeck[i];
            p2Amount[i] = player1carddeckamount[i];
        }

        p2Deck[22] = 139;
        p2Amount[22] = 1;

        p2Deck[23] = 140; //weather set close combat to 1
        p2Amount[23] = 1;

        gwentCardToken.mint(player1, 139, 1);
        gwentCardToken.mint(player1, 140, 1);
        // 3. Enter Arena
        vm.startPrank(player4);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Skellige, p1Deck, p1Amount);
        vm.stopPrank();

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p2Deck, p2Amount);
        vm.stopPrank();

        // 4. Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        uint256 matchId = gwentArena.getPlayerLatestMatchId(player4);

        // --- P4 Hand ---
        uint256[] memory p1r1 = new uint256[](4);
        p1r1[0] = gwentArena.encodeCard(117, 1, 0, 0, 0, 0); // Berserker. Base 4. berserker 14 Close(0). 🐻

        p1r1[1] = gwentArena.encodeCard(114, 1, 0, 0, 0, 0); // mardrome target row close combat power 2

        p1r1[2] = gwentArena.encodeCard(113, 1, 0, 4, 0, 0); // berserker . base 0 berserker 11

        p1r1[3] = gwentArena.encodeCard(138, 1, 0, 0, 0, 0); // decoy protect berserker power

        uint256[] memory p1r2 = new uint256[](5);
        p1r2[0] = gwentArena.encodeCard(118, 1, 0, 0, 0, 0); // Close p4
        p1r2[1] = gwentArena.encodeCard(119, 1, 0, 0, 0, 0); // Close p4
        p1r2[2] = gwentArena.encodeCard(120, 1, 0, 0, 0, 0); // Close p4
        p1r2[3] = gwentArena.encodeCard(121, 1, 0, 0, 0, 0); // Close p4 => total close combat : 16 + spy power1(siege) = 17
        p1r2[4] = gwentArena.encodeCard(141, 1, 1, 0, 0, 0); // clear weather

        uint256[] memory p1r3 = new uint256[](1);
        p1r3[0] = gwentArena.encodeCard(123, 1, 0, 0, 0, 0); // Ranged(1)
        // p1r3[1] = gwentArena.encodeCard(124, 1, 0, 0, 0, 0); // Close(0)

        // --- P1 Hand ---
        uint256[] memory p2r1 = new uint256[](3);
        p2r1[0] = gwentArena.encodeCard(1, 1, 0, 0, 0, 0); // ID 1. Siege(2). ✅
        p2r1[1] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0); // Close(0)
        p2r1[2] = gwentArena.encodeCard(139, 1, 0, 0, 0, 0); // scorch disable berserker

        uint256[] memory p2r2 = new uint256[](5);
        p2r2[0] = gwentArena.encodeCard(4, 1, 0, 0, 0, 0); // ID 4. Siege(2). spy p1 ✅
        p2r2[1] = gwentArena.encodeCard(5, 1, 0, 0, 0, 0); // Close(0) p2
        p2r2[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Close(0) p4
        p2r2[3] = gwentArena.encodeCard(7, 1, 1, 0, 0, 0); // Ranged(1). p4
        p2r2[4] = gwentArena.encodeCard(140, 1, 0, 0, 0, 0); // weather set close combat to 1

        uint256[] memory p2r3 = new uint256[](2);
        p2r3[0] = gwentArena.encodeCard(8, 1, 1, 0, 0, 0); // Ranged(1).
        p2r3[1] = gwentArena.encodeCard(9, 1, 0, 0, 0, 0); // Close(0)
        // p2r3[2] = gwentArena.encodeCard(10, 1, 0, 0, 0, 0); // Close(0)

        // --- Commit ---
        vm.prank(player4);
        bytes32 h = keccak256(abi.encode(p1r1, p1r2, p1r3, salt));
        gwentArena.commitPlays(matchId, h);

        bytes32 ph = keccak256(abi.encode(p2r1, p2r2, p2r3, salt));
        vm.prank(player1);
        gwentArena.commitPlays(matchId, ph);

        // --- Reveal ---
        vm.prank(player4);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player1);
        gwentArena.revealPlays(matchId, p2r1, p2r2, p2r3, salt);

        // --- Execute ---
        (, bytes memory pData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(pData);
    }

    function test_tight_bond_scaling() public {
        uint256 salt = 12345;
        // Northern Realms (IDs 1-25)
        uint256[] memory p1Deck = new uint256[](22);
        uint256[] memory p1Amount = new uint256[](22);
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player1carddeck[i];
            if (p1Deck[i] == 6) {
                p1Amount[i] = 6;
            } else {
                p1Amount[i] = player1carddeckamount[i];
            }
        }

        // Mint extra copies of ID 6 if needed (setUp mints 1)
        gwentCardToken.mint(player1, 6, 6);

        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p1Deck, p1Amount);
        vm.stopPrank();

        // Standard Nilfgaard deck for player 2
        vm.startPrank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(
            Faction.Scoiatael,
            player2carddeck,
            player2carddeckamount
        );
        vm.stopPrank();

        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        // --- P1 Hand ---
        uint256[] memory p1r1 = new uint256[](1);
        p1r1[0] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // 1 Blue Stripe -> 4 power

        uint256[] memory p1r2 = new uint256[](2);
        p1r2[0] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0);
        p1r2[1] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // 2 Blue Stripes -> 4 * 2^2 = 16 power

        uint256[] memory p1r3 = new uint256[](3);
        p1r3[0] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0);
        p1r3[1] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0);
        p1r3[2] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // 3 Blue Stripes -> 4 * 3^2 = 36 power

        // Empty player 2 hands
        uint256[] memory empty = new uint256[](0);

        vm.prank(player1);
        gwentArena.commitPlays(
            matchId,
            keccak256(abi.encode(p1r1, p1r2, p1r3, salt))
        );
        vm.prank(player2);
        gwentArena.commitPlays(
            matchId,
            keccak256(abi.encode(empty, empty, empty, salt))
        );

        vm.prank(player1);
        gwentArena.revealPlays(matchId, p1r1, p1r2, p1r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, empty, empty, empty, salt);

        (, bytes memory pData) = gwentArena.checkUpkeep("");

        uint256[3] memory p1Expected = [uint256(4), 16, 36];
        vm.expectEmit(true, false, false, true);
        emit MatchResolved(
            matchId,
            MatchResult.Player1Wins,
            player1,
            56,
            0,
            p1Expected,
            [uint256(0), 0, 0]
        );

        gwentArena.performUpkeep(pData);
    }

    function test_hero_invincibility() public {
        uint256 salt = 999;

        uint256[] memory p1Deck = new uint256[](23);
        uint256[] memory p1Amount = new uint256[](23);
        // P1: Hero (ID 22) + Unit (ID 6). Northern Realms.
        for (uint16 i = 0; i < 22; i++) {
            p1Deck[i] = player1carddeck[i];
            p1Amount[i] = player1carddeckamount[i];
        }
        p1Deck[22] = 137;
        p1Amount[22] = 1;
        gwentCardToken.mint(player1, 137, 1);
        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, p1Deck, p1Amount);
        vm.stopPrank();

        // P2: Neutral deck (IDs 26+). Scoiatael.

        uint256[] memory p2Deck = new uint256[](23);
        uint256[] memory p2Amount = new uint256[](23);
        // P1: Hero (ID 22) + Unit (ID 6). Northern Realms.
        for (uint16 i = 0; i < 22; i++) {
            p2Deck[i] = player2carddeck[i];
            p2Amount[i] = player2carddeckamount[i];
        }
        p2Deck[22] = 140;
        p2Amount[22] = 1;
        gwentCardToken.mint(player2, 140, 1);

        vm.startPrank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Scoiatael, p2Deck, p2Amount);
        vm.stopPrank();

        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        // --- P1 Plays ---
        uint256[] memory p1r1 = new uint256[](3);
        p1r1[0] = gwentArena.encodeCard(22, 1, 0, 0, 0, 0); // Hero (10)
        p1r1[1] = gwentArena.encodeCard(6, 1, 0, 0, 0, 0); // Unit (4)
        p1r1[2] = gwentArena.encodeCard(137, 1, 0, 0, 0, 0); // Horn (on Row 0)

        // --- P2 Plays ---
        uint256[] memory p2r1 = new uint256[](1);
        p2r1[0] = gwentArena.encodeCard(140, 1, 0, 0, 0, 0); // Frost

        uint256[] memory empty = new uint256[](0);

        vm.prank(player1);
        gwentArena.commitPlays(
            matchId,
            keccak256(abi.encode(p1r1, empty, empty, salt))
        );
        vm.prank(player2);
        gwentArena.commitPlays(
            matchId,
            keccak256(abi.encode(p2r1, empty, empty, salt))
        );

        vm.prank(player1);
        gwentArena.revealPlays(matchId, p1r1, empty, empty, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, p2r1, empty, empty, salt);

        // --- Verification ---
        // Expected State for P1 Row 0:
        // Hero ID 22 (10) + Unit ID 6 (4 -> 1 -> 2) = 12.
        (, bytes memory pData) = gwentArena.checkUpkeep("");

        vm.expectEmit(true, true, true, true);
        emit MatchResolved(
            matchId,
            MatchResult.Player1Wins,
            player1,
            12,
            0,
            [uint256(12), 0, 0],
            [uint256(0), 0, 0]
        );
        gwentArena.performUpkeep(pData);
    }
}
