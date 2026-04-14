// SPDX-License-Identifer: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GwentArena} from "../../src/GwentArena.sol";
import {GwentCardToken} from "../../src/GwentCardToken.sol";
import {GwentSystem} from "../../src/GwentSystem.sol";
import {LinkToken} from "../mocks/LinkToken.sol";
import {
    VRFCoordinatorV2_5Mock
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig} from "../../script/Helperconfig.s.sol";
import {CodeConstants} from "../../script/Helperconfig.s.sol";
import {DeployGwent} from "../../script/Deploy.s.sol";
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
contract GwentarenaTest is Test, CodeConstants, ERC1155Holder {
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
    function setUp() public {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (block.chainid != 31337) {
            deal(config.link, config.account, 100 ether);
        }

        DeployGwent deployer = new DeployGwent();
        (gwentCardToken, gwentArena, gwentSystem, ) = deployer.run();

        address[] memory recipients = new address[](3);
        recipients[0] = player1;
        recipients[1] = player2;
        recipients[2] = player3;

        vm.prank(config.account);
        gwentCardToken.airdropCurrency(recipients, USER_BALANCE);
    }

    function test_check_user_balance() public {
        vm.startPrank(player1);
        uint256 balance = gwentCardToken.balanceOf(player1, 0);
        assertEq(balance, USER_BALANCE);
        vm.stopPrank();
    }
    function test_open_pack() public {
        vm.startPrank(player1);
        uint256 gasStart1 = gasleft();
        uint256 requestId = gwentSystem.openNorthenRealmsPack(5);
        uint256 gasUsed1 = gasStart1 - gasleft();

        uint256 gasStart2 = gasleft();
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
            requestId,
            address(gwentSystem)
        );
        uint256 gasUsed2 = gasStart2 - gasleft();

        uint256 gasStart3 = gasleft();
        uint256[] memory cardIds = gwentSystem.claimRolls(requestId);
        uint256 gasUsed3 = gasStart3 - gasleft();

        console.log("Gas used - Request:", gasUsed1);
        console.log("Gas used - Callback:", gasUsed2);
        console.log("Gas used - Claim:", gasUsed3);
        console.log("Total Gas:", gasUsed1 + gasUsed2 + gasUsed3);

        vm.stopPrank();
        uint256 cardlength = cardIds.length;
        console.log("Player 1 Cards:", cardlength);
        assertEq(cardlength, 30);
    }

    modifier setUpPlayerDecks() {
        vm.startPrank(address(this));

        // --- Player 1: Northern Realms (IDs 1 - 25) ---
        uint256[] memory p1Ids = new uint256[](40);
        uint256[] memory p1Amounts = new uint256[](40);
        for (uint256 i = 0; i < 40; i++) {
            p1Ids[i] = 1 + (i % 25); // Cycles through IDs 1 to 25
            p1Amounts[i] = 1;
        }
        gwentCardToken.mintBatch(player1, p1Ids, p1Amounts, "");

        // --- Player 2: Scoia'tael (IDs 26 - 48) ---
        uint256[] memory p2Ids = new uint256[](40);
        uint256[] memory p2Amounts = new uint256[](40);
        for (uint256 i = 0; i < 40; i++) {
            p2Ids[i] = 26 + (i % 23); // Cycles through IDs 26 to 48
            p2Amounts[i] = 1;
        }
        gwentCardToken.mintBatch(player2, p2Ids, p2Amounts, "");

        // --- Player 3: Monsters (IDs 78 - 112) ---
        uint256[] memory p3Ids = new uint256[](40);
        uint256[] memory p3Amounts = new uint256[](40);
        for (uint256 i = 0; i < 40; i++) {
            p3Ids[i] = 78 + (i % 35); // Cycles through IDs 78 to 112
            p3Amounts[i] = 1;
        }
        gwentCardToken.mintBatch(player3, p3Ids, p3Amounts, "");

        vm.stopPrank();
        _;
    }
    function test_enter_arena() public setUpPlayerDecks {
        uint256[] memory cardidplayer1 = new uint256[](22);
        uint256[] memory cardidamountplayer1 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            cardidplayer1[i] = i + 1;
            cardidamountplayer1[i] = 1;
        }
        vm.startPrank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        // Capture gas before
        uint256 gasStart = gasleft();

        gwentArena.enterArena(
            Faction.Northern,
            cardidplayer1,
            cardidamountplayer1
        );
        // Calculate delta
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used for enterArena:", gasUsed);
        vm.stopPrank();
        uint256 useraBalance = gwentCardToken.balanceOf(player1, 0);
        console.log("User Balance:", useraBalance);
        assertEq(useraBalance, USER_BALANCE - 50 ether);
    }

    function test_matchmaking() public setUpPlayerDecks {
        // --- Player 1 enters ---
        uint256[] memory deck1 = new uint256[](22);
        uint256[] memory amounts1 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck1[i] = i + 1;
            amounts1[i] = 1;
        }
        vm.startPrank(player1);
        uint256 gasstart1 = gasleft();
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, deck1, amounts1);
        uint256 gasused1 = gasstart1 - gasleft();
        console.log("Gas used for enterArena player1:", gasused1);
        vm.stopPrank();

        // --- Player 2 enters ---
        uint256[] memory deck2 = new uint256[](22);
        uint256[] memory amounts2 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck2[i] = 26 + i;
            amounts2[i] = 1;
        }
        vm.startPrank(player2);
        uint256 gasstart2 = gasleft();
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Scoiatael, deck2, amounts2);
        uint256 gasused2 = gasstart2 - gasleft();
        console.log("Gas used for enterArena player2:", gasused2);
        vm.stopPrank();

        // --- Check Upkeep ---
        uint256 gasstart3 = gasleft();
        (bool upkeepNeeded, bytes memory performData) = gwentArena.checkUpkeep(
            ""
        );
        uint256 gasused3 = gasstart3 - gasleft();
        console.log("Gas used for checkUpkeep:", gasused3);
        assertTrue(upkeepNeeded, "Upkeep should be needed");

        // --- Perform Upkeep ---
        uint256 gasstart4 = gasleft();
        gwentArena.performUpkeep(performData);
        uint256 gasused4 = gasstart4 - gasleft();
        console.log("Gas used for performUpkeep:", gasused4);

        // --- Verify Match ---
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);
        MatchInfo memory matchInfo = gwentArena.getMatchInfo(matchId);

        assertEq(matchInfo.player1, player1, "Player 1 mismatch");
        assertEq(matchInfo.player2, player2, "Player 2 mismatch");

        // Verify players are matched
        (, , , bool isMatched1, ) = gwentArena.getPlayerEntry(player1);
        (, , , bool isMatched2, ) = gwentArena.getPlayerEntry(player2);
        assertTrue(isMatched1, "Player 1 should be matched");
        assertTrue(isMatched2, "Player 2 should be matched");
    }

    function _airdropFactionCards(
        address player,
        uint256 startId,
        uint256 endId,
        uint256 total
    ) internal {
        vm.startPrank(address(this));
        uint256 count = endId - startId + 1;
        uint256[] memory ids = new uint256[](total);
        uint256[] memory amounts = new uint256[](total);
        for (uint256 i = 0; i < total; i++) {
            ids[i] = startId + (i % count);
            amounts[i] = 1;
        }
        gwentCardToken.mintBatch(player, ids, amounts, "");
        vm.stopPrank();
    }

    function test_matchmaking_three_players() public setUpPlayerDecks {
        // Valid
        // --- Player 1 and 2 enter and match ---
        uint256[] memory deck1 = new uint256[](22);
        uint256[] memory amounts1 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck1[i] = i + 1;
            amounts1[i] = 1;
        }
        vm.prank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        vm.prank(player1);
        gwentArena.enterArena(Faction.Northern, deck1, amounts1);

        uint256[] memory deck2 = new uint256[](22);
        uint256[] memory amounts2 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck2[i] = 26 + i;
            amounts2[i] = 1;
        }
        vm.prank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        vm.prank(player2);
        gwentArena.enterArena(Faction.Scoiatael, deck2, amounts2);

        // Perform matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        // --- Player 3 enters ---
        uint256[] memory deck3 = new uint256[](22);
        uint256[] memory amounts3 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck3[i] = 78 + i;
            amounts3[i] = 1;
        }
        vm.prank(player3);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        vm.prank(player3);
        gwentArena.enterArena(Faction.Monster, deck3, amounts3);

        // --- Check Upkeep ---
        (bool upkeepNeeded, ) = gwentArena.checkUpkeep("");
        assertFalse(
            upkeepNeeded,
            "Upkeep should NOT be needed with only 1 player waiting"
        );

        // --- Verify Player 3 state ---
        (, , uint256 enterBlock, bool isMatched, ) = gwentArena.getPlayerEntry(
            player3
        );
        assertTrue(enterBlock > 0, "Player 3 should be in the arena");
        assertFalse(isMatched, "Player 3 should NOT be matched yet");
    }

    /// AI WRITE TEST

    function _getCombinedHash(
        uint256[] memory r1,
        uint256[] memory r2,
        uint256[] memory r3,
        uint256 salt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(r1, r2, r3, salt));
    }

    function test_reveal_plays_gas_benchmark() public setUpPlayerDecks {
        // 1. Initial Matchmaking
        test_matchmaking();
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);
        uint256 salt = 123456;

        // 2. Prepare 10-card hands
        uint256[] memory r1 = new uint256[](4);
        uint256[] memory r2 = new uint256[](3);
        uint256[] memory r3 = new uint256[](3);
        for (uint16 i = 0; i < 4; i++)
            r1[i] = gwentArena.encodeCard(uint16(i + 1), 1, 0, 0, 0, 0);
        for (uint16 i = 0; i < 3; i++)
            r2[i] = gwentArena.encodeCard(uint16(i + 5), 1, 0, 0, 0, 0);
        for (uint16 i = 0; i < 3; i++)
            r3[i] = gwentArena.encodeCard(uint16(i + 8), 1, 0, 0, 0, 0);

        bytes32 combinedHash = _getCombinedHash(r1, r2, r3, salt);

        // --- BENCHMARK: commitPlays ---
        vm.prank(player1);
        uint256 gasstart1 = gasleft();
        gwentArena.commitPlays(matchId, combinedHash);
        uint256 gasused1 = gasstart1 - gasleft();
        console.log("Gas used for commitPlays player1:", gasused1);

        vm.prank(player2);
        uint256 gasstart2 = gasleft();
        gwentArena.commitPlays(matchId, combinedHash);
        uint256 gasused2 = gasstart2 - gasleft();
        console.log("Gas used for commitPlays player2:", gasused2);

        // --- BENCHMARK: revealPlays ---
        vm.prank(player1);
        uint256 gasstart3 = gasleft();
        gwentArena.revealPlays(matchId, r1, r2, r3, salt);
        uint256 gasused3 = gasstart3 - gasleft();
        console.log("Gas used for revealPlays player1:", gasused3);

        vm.prank(player2);
        uint256 gasstart4 = gasleft();
        gwentArena.revealPlays(matchId, r1, r2, r3, salt);
        uint256 gasused4 = gasstart4 - gasleft();
        console.log("Gas used for revealPlays player2:", gasused4);

        // Verification
        MatchInfo memory info = gwentArena.getMatchInfo(matchId);
        assertTrue(info.revealed1, "P1 should be revealed");
        assertTrue(info.revealed2, "P2 should be revealed");
        assertEq(uint(info.phase), uint(Phase.WaitingForResolution));
    }

    function test_zero_hash_commit_reverts() public setUpPlayerDecks {
        // Valid
        test_matchmaking();
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        vm.startPrank(player1);
        vm.expectRevert("Invalid hash");
        gwentArena.commitPlays(matchId, bytes32(0));
        vm.stopPrank();
    }

    function test_double_commit_reverts() public setUpPlayerDecks {
        // Valid
        test_matchmaking();
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        uint256[] memory empty;
        bytes32 h = _getCombinedHash(empty, empty, empty, 123);

        vm.startPrank(player1);
        gwentArena.commitPlays(matchId, h);

        vm.expectRevert("Already committed");
        gwentArena.commitPlays(matchId, h);
        vm.stopPrank();
    }

    function test_invalid_reveal_salt_reverts() public setUpPlayerDecks {
        // Valid
        test_matchmaking();
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        uint256[] memory r1 = new uint256[](1);
        r1[0] = gwentArena.encodeCard(1, 1, 0, 0, 0, 0);
        uint256[] memory empty;

        uint256 correctSalt = 123;
        uint256 wrongSalt = 456;
        bytes32 h = _getCombinedHash(r1, empty, empty, correctSalt);

        // Player 1 commits
        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);

        // Player 2 commits (to move to reveal phase)
        vm.prank(player2);
        gwentArena.commitPlays(matchId, h);

        // Try to reveal with WRONG salt
        vm.startPrank(player1);
        vm.expectRevert("Hash mismatch");
        gwentArena.revealPlays(matchId, r1, empty, empty, wrongSalt);
        vm.stopPrank();
    }

    function test_reveal_after_deadline_reverts() public setUpPlayerDecks {
        //valid
        test_matchmaking();
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        uint256[] memory empty;
        bytes32 h = _getCombinedHash(empty, empty, empty, 123);

        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);
        vm.prank(player2);
        gwentArena.commitPlays(matchId, h);

        // Wait for deadline
        MatchInfo memory info = gwentArena.getMatchInfo(matchId);
        vm.warp(info.revealDeadline + 1 days);

        vm.startPrank(player1);
        vm.expectRevert("Reveal timeout passed");
        gwentArena.revealPlays(matchId, empty, empty, empty, 123);
        vm.stopPrank();
    }

    function test_frontrun_cancel() public setUpPlayerDecks {
        // Valid
        // --- Player 1 enters ---
        uint256[] memory deck1 = new uint256[](22);
        uint256[] memory amounts1 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck1[i] = i + 1;
            amounts1[i] = 1;
        }
        vm.prank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        vm.prank(player1);
        gwentArena.enterArena(Faction.Northern, deck1, amounts1);

        // --- Player 2 enters ---
        uint256[] memory deck2 = new uint256[](22);
        uint256[] memory amounts2 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck2[i] = 26 + i;
            amounts2[i] = 1;
        }
        vm.prank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        vm.prank(player2);
        gwentArena.enterArena(Faction.Scoiatael, deck2, amounts2);

        // --- Check Upkeep finds a match ---
        (bool upkeepNeeded, bytes memory performData) = gwentArena.checkUpkeep(
            ""
        );
        assertTrue(upkeepNeeded, "Upkeep should be needed");

        // --- Player 2 Front-runs with Cancel ---
        vm.prank(player2);
        gwentArena.cancelEntry();

        // --- Perform Upkeep (simulating automation) ---
        // It SHOULD NOT revert even though player2 is gone
        gwentArena.performUpkeep(performData);

        // Verify Player 1 is still in the queue (not matched)
        (, , , bool isMatched, ) = gwentArena.getPlayerEntry(player1);
        assertFalse(
            isMatched,
            "Player 1 should NOT be matched after P2 cancelled"
        );
    }

    function test_queue_holes_griefing() public setUpPlayerDecks {
        // Valid
        // --- Create many entries and then cancel some ---
        // This creates holes in the queue
        address[] memory pool = new address[](6);
        pool[0] = makeAddr("g1");
        pool[1] = makeAddr("g2");
        pool[2] = makeAddr("g3");
        pool[3] = makeAddr("g4");
        pool[4] = makeAddr("g5");
        pool[5] = makeAddr("g6");

        uint256[] memory deck = new uint256[](22);
        uint256[] memory amounts = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck[i] = i + 1;
            amounts[i] = 1;
        }

        gwentCardToken.airdropCurrency(pool, USER_BALANCE);

        for (uint i = 0; i < 6; i++) {
            _airdropFactionCards(pool[i], 1, 25, 40);
            vm.startPrank(pool[i]);
            gwentCardToken.setApprovalForAll(address(gwentArena), true);
            gwentArena.enterArena(Faction.Northern, deck, amounts);
            vm.stopPrank();
        }

        // Cancel every second player to create holes
        vm.prank(pool[1]);
        gwentArena.cancelEntry();
        vm.prank(pool[3]);
        gwentArena.cancelEntry();
        vm.prank(pool[5]);
        gwentArena.cancelEntry();

        // Check Upkeep should still find matches for P1-P3(cancelled)-P2? No.
        // Queue is [P0, 0, P2, 0, P4, 0]
        // checkUpkeep should match P0 and P2
        (bool upkeepNeeded, bytes memory performData) = gwentArena.checkUpkeep(
            ""
        );
        assertTrue(upkeepNeeded, "Should find P0 and P2");

        (uint8 upkeepType, address matchP1, address matchP2, , ) = abi.decode(
            performData,
            (uint8, address, address, uint256, uint256)
        );
        assertEq(matchP1, pool[0]);
        assertEq(matchP2, pool[2]);

        gwentArena.performUpkeep(performData);

        // Next Match: P4 and ? (None left)
        (bool nextUpkeep, ) = gwentArena.checkUpkeep("");
        assertFalse(nextUpkeep, "Only P4 left, no match possible");
    }

    /* 
    function test_massive_reveal_reverts() public setUpPlayerDecks {
        // This test requires the "Reveal too large" fix in GwentArena.sol
        test_matchmaking();
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        uint256[] memory massive = new uint256[](11); // Max is 10
        for (uint256 i = 0; i < 11; i++) {
            massive[i] = gwentArena.encodeCard(1, 1, 0, 0, 0, 0);
        }
        uint256[] memory empty;

        (bytes32 h1, bytes32 h2, bytes32 h3) = _getCommitHashes(massive, empty, empty, 123);

        vm.prank(player1);
        gwentArena.commitPlays(matchId, h1, h2, h3);
        vm.prank(player2);
        gwentArena.commitPlays(matchId, h1, h2, h3);

        vm.startPrank(player1);
        vm.expectRevert("Reveal too large");
        gwentArena.revealPlays(matchId, massive, empty, empty, 123);
        vm.stopPrank();
    }
    */

    function test_cheat_unowned_cards_slashing() public setUpPlayerDecks {
        // Valid
        test_matchmaking();
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        // Player 1 reveals card ID 50, but Northern Realms deck only should have 1-25
        uint256[] memory cheat = new uint256[](1);
        cheat[0] = gwentArena.encodeCard(50, 1, 0, 0, 0, 0);
        uint256[] memory empty;

        bytes32 h = _getCombinedHash(cheat, empty, empty, 123);

        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);

        // Player 2 commits valid
        uint256[] memory valid = new uint256[](1);
        valid[0] = gwentArena.encodeCard(26, 1, 0, 0, 0, 0);
        bytes32 v = _getCombinedHash(valid, empty, empty, 123);
        vm.prank(player2);
        gwentArena.commitPlays(matchId, v);

        // Both reveal
        vm.prank(player1);
        gwentArena.revealPlays(matchId, cheat, empty, empty, 123);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, valid, empty, empty, 123);

        // Resolution – Automaton finds P1 Cheated
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        // Verify Player 2 Wins by Slashing
        MatchInfo memory info = gwentArena.getMatchInfo(matchId);
        assertEq(
            uint(info.result),
            uint(MatchResult.Player2Wins),
            "P2 should win if P1 cheated"
        );
    }

    function test_wait_reward_overflow() public setUpPlayerDecks {
        // Valid
        // Player 1 enters
        uint256[] memory deck = new uint256[](22);
        uint256[] memory amounts = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck[i] = i + 1;
            amounts[i] = 1;
        }
        vm.prank(player1);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        vm.prank(player1);
        gwentArena.enterArena(Faction.Northern, deck, amounts);

        // Warp time by 1 Million blocks
        vm.roll(block.number + 1_000_000);

        // Player 2 enters to trigger matchmaking check (and reward calculation)
        uint256[] memory deck2 = new uint256[](22);
        uint256[] memory amounts2 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck2[i] = 26 + i;
            amounts2[i] = 1;
        }

        _airdropFactionCards(player2, 26, 48, 40);
        vm.startPrank(player2);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Scoiatael, deck2, amounts2);
        vm.stopPrank();

        // Check Upkeep and Perform Matchmaking
        (, bytes memory performData) = gwentArena.checkUpkeep("");

        uint256 balanceBefore = gwentCardToken.balanceOf(player1, 0);
        gwentArena.performUpkeep(performData);
        vm.prank(player1);
        gwentArena.claimPendingBalance();
        uint256 balanceAfter = gwentCardToken.balanceOf(player1, 0);

        // Verify P1 received reward for 1M blocks
        // waitRewardPerBlock = 0.001 ether
        // 1,000,000 * 0.001 = 1,000 ether
        assertEq(
            balanceAfter - balanceBefore,
            1000 ether,
            "Should receive 1000 ETH reward"
        );
    }

    function test_cheat_max_cards_slashing() public setUpPlayerDecks {
        // Valid
        test_matchmaking();
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player1);

        uint256[] memory r1 = new uint256[](4);
        uint256[] memory r2 = new uint256[](4);
        uint256[] memory r3 = new uint256[](3); // 4 + 4 + 3 = 11 cards (Cheating!)
        uint256 salt = 123;

        for (uint256 i = 0; i < 4; i++)
            r1[i] = gwentArena.encodeCard(1, 1, 0, 0, 0, 0);
        for (uint256 i = 0; i < 4; i++)
            r2[i] = gwentArena.encodeCard(2, 1, 0, 0, 0, 0);
        for (uint256 i = 0; i < 3; i++)
            r3[i] = gwentArena.encodeCard(3, 1, 0, 0, 0, 0);

        bytes32 h = _getCombinedHash(r1, r2, r3, salt);
        vm.prank(player1);
        gwentArena.commitPlays(matchId, h);

        // Player 2 commits valid 10 cards (Amount must be 1 to match enterArena deck)
        uint256[] memory v1 = new uint256[](5);
        uint256[] memory v2 = new uint256[](5);
        uint256[] memory v3;
        for (uint256 i = 0; i < 5; i++)
            v1[i] = gwentArena.encodeCard(uint16(26 + i), 1, 0, 0, 0, 0);
        for (uint256 i = 0; i < 5; i++)
            v2[i] = gwentArena.encodeCard(uint16(31 + i), 1, 0, 0, 0, 0);

        bytes32 vh = _getCombinedHash(v1, v2, v3, salt);
        vm.prank(player2);
        gwentArena.commitPlays(matchId, vh);

        // Both reveal
        vm.prank(player1);
        gwentArena.revealPlays(matchId, r1, r2, r3, salt);
        vm.prank(player2);
        gwentArena.revealPlays(matchId, v1, v2, v3, salt);

        // Resolution – Automaton finds P1 Cheated
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        // Verify Player 2 Wins by Slashing
        MatchInfo memory info = gwentArena.getMatchInfo(matchId);
        assertEq(
            uint(info.result),
            uint(MatchResult.Player2Wins),
            "P2 should win if P1 played 11 cards"
        );
    }

    function test_reproduction_deadlock() public setUpPlayerDecks {
        // 1. Honest Player enters
        test_matchmaking(); // P1 and P2 matched. Now match queue head is 2.

        // 2. Griefer enters
        MaliciousWaitGriefer griefer = new MaliciousWaitGriefer();
        uint256[] memory deck = new uint256[](22);
        uint256[] memory amounts = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck[i] = i + 1;
            amounts[i] = 1;
        }
        _airdropFactionCards(address(griefer), 1, 25, 40);
        address[] memory gPool = new address[](1);
        gPool[0] = address(griefer);
        gwentCardToken.airdropCurrency(gPool, 100 ether);

        vm.startPrank(address(griefer));
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Northern, deck, amounts);
        griefer.setGriefing(true); // Now turn on the evil!
        vm.stopPrank();

        // 3. Honest Player 3 enters
        uint256[] memory deck3 = new uint256[](22);
        uint256[] memory amounts3 = new uint256[](22);
        for (uint256 i = 0; i < 22; i++) {
            deck3[i] = 78 + i;
            amounts3[i] = 1;
        }

        _airdropFactionCards(player3, 78, 112, 40);
        vm.startPrank(player3);
        gwentCardToken.setApprovalForAll(address(gwentArena), true);
        gwentArena.enterArena(Faction.Monster, deck3, amounts3);
        vm.stopPrank();

        // 4. Wait for rewards
        vm.roll(block.number + 100);

        // 5. Automation tries to match (Griefer, P3)
        // Verified: THIS NO LONGER REVERTS!
        (, bytes memory performData) = gwentArena.checkUpkeep("");
        gwentArena.performUpkeep(performData);

        // 6. Verify Match was created despite the bad ghost
        uint256 matchId = gwentArena.getPlayerLatestMatchId(player3);
        MatchInfo memory info = gwentArena.getMatchInfo(matchId);
        assertEq(info.player1, address(griefer));
        assertEq(info.player2, player3);

        // 7. Verify rewards are pending (not minted)
        uint256 pendingP3 = gwentArena.pendingRewards(player3);
        assertTrue(pendingP3 > 0, "P3 should have pending wait rewards");
    }
}

contract MaliciousWaitGriefer is ERC1155Holder {
    bool public griefingEnabled;

    function setGriefing(bool _enabled) external {
        griefingEnabled = _enabled;
    }

    function onERC1155Received(
        address,
        address,
        uint256 id,
        uint256 value,
        bytes memory
    ) public override returns (bytes4) {
        if (griefingEnabled && id == 0 && value > 0) {
            revert("I am a bad ghost!");
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
