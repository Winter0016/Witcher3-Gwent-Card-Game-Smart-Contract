// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {GwentArena} from "../../src/GwentArena.sol";
import {GwentCardToken} from "../../src/GwentCardToken.sol";
import {
    Faction,
    Phase,
    Match,
    MatchInfo,
    ArenaEntry
} from "../../src/GwentTypes.sol";

contract GwentArenaHandler is Test {
    GwentArena public arena;
    GwentCardToken public token;

    address[] public actors;
    uint256 public constant MAX_ACTORS = 5;
    uint256 public constant GHOST_SALT = 888;

    constructor(GwentArena _arena, GwentCardToken _token) {
        arena = _arena;
        token = _token;
        for (uint16 i = 0; i < MAX_ACTORS; i++) {
            actors.push(makeAddr(string(abi.encodePacked("actor", i))));
        }
    }

    function enterArena(uint256 actorSeed, uint8 factionSeed) public {
        address actor = actors[actorSeed % actors.length];
        Faction faction = Faction(factionSeed % 5);

        vm.prank(token.treasuryWallet());
        token.airdropCurrencySingle(actor, 1000 ether);

        uint16 startId = 1;
        if (faction == Faction.Nilfgaard) startId = 49;
        else if (faction == Faction.Monster) startId = 78;
        else if (faction == Faction.Scoiatael) startId = 26;
        else if (faction == Faction.Skellige) startId = 113;

        uint256[] memory ids = new uint256[](26);
        uint256[] memory amounts = new uint256[](26);
        for (uint256 i = 0; i < 22; i++) {
            ids[i] = startId + i;
            amounts[i] = 1;
        }
        for (uint256 i = 0; i < 4; i++) {
            ids[22 + i] = 136 + i;
            amounts[22 + i] = 1;
        }

        vm.startPrank(token.treasuryWallet());
        token.mintBatch(actor, ids, amounts, "");
        vm.stopPrank();

        vm.startPrank(actor);
        token.setApprovalForAll(address(arena), true);
        try arena.enterArena(faction, ids, amounts) {} catch {}
        vm.stopPrank();
    }

    function performAutomation(uint256 warpBlocks) public {
        warpBlocks = bound(warpBlocks, 1, 100);
        vm.warp(block.timestamp + (warpBlocks * 12));
        vm.roll(block.number + warpBlocks);

        (bool upkeepNeeded, bytes memory performData) = arena.checkUpkeep("");
        if (upkeepNeeded) {
            arena.performUpkeep(performData);
        }
    }

    function commitAndReveal(
        uint256 actorSeed,
        uint256 cardSeed,
        uint256 rowSeed
    ) public {
        address actor = actors[actorSeed % actors.length];
        uint256 mId = arena.getPlayerLatestMatchId(actor);
        if (mId == 0 && arena.matchCount() == 0) return;

        MatchInfo memory info = arena.getMatchInfo(mId);
        if (info.phase == Phase.Completed) return;
        if (info.player1 != actor && info.player2 != actor) return;

        uint256[] memory deck = (info.player1 == actor)
            ? info.deck1Packed
            : info.deck2Packed;
        if (deck.length == 0) return;

        uint256[] memory r1 = new uint256[](1); // Simplified to 1 card per play for fuzzer stability
        uint256[] memory empty = new uint256[](0);

        uint256 cardId = deck[cardSeed % deck.length];
        uint8 targetRow = uint8(rowSeed % 3);

        r1[0] = arena.encodeCard(uint16(cardId), 1, targetRow, 0, 0, 0);

        if (info.phase == Phase.WaitingForCommit) {
            vm.startPrank(actor);
            bytes32 h = keccak256(abi.encode(r1, empty, empty, GHOST_SALT));
            try arena.commitPlays(mId, h) {} catch {}
            vm.stopPrank();
        } else if (info.phase == Phase.WaitingForReveal) {
            vm.startPrank(actor);
            try arena.revealPlays(mId, r1, empty, empty, GHOST_SALT) {} catch {}
            vm.stopPrank();
        }
    }

    function claimRewards(uint256 actorSeed) public {
        address actor = actors[actorSeed % actors.length];
        uint256 mId = arena.getPlayerLatestMatchId(actor);
        if (mId == 0 && arena.matchCount() == 0) return;

        MatchInfo memory info = arena.getMatchInfo(mId);
        if (info.phase == Phase.Completed) {
            vm.startPrank(actor);
            try arena.claimRewards(mId) {} catch {}
            vm.stopPrank();
        }
    }

    // Mathematical Invariant Helpers
    uint256 public lastP;
    uint256 public lastR;
    uint256 public lastM;
    uint256 public lastMard;
    uint256 public lastH;
    uint256 public lastT;

    function getLastCombatInputs()
        public
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        return (lastP, lastR, lastM, lastMard, lastH, lastT);
    }

    function generateCombatLogic(
        uint256 p,
        uint256 r,
        uint256 m,
        uint256 mard,
        uint256 h,
        uint256 t
    ) public {
        lastP = p;
        lastR = r;
        lastM = m;
        lastMard = mard;
        lastH = h;
        lastT = t;
    }
}
