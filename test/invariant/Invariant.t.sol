// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {GwentArenaHandler} from "./Handler.t.sol";
import {GwentArena} from "../../src/GwentArena.sol";
import {GwentCardToken} from "../../src/GwentCardToken.sol";
import {Faction, Phase, MatchResult, MatchInfo} from "../../src/GwentTypes.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {
    ERC1967Proxy
} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "../../script/Helperconfig.s.sol";

contract GwentArenaInvariant is Test {
    GwentArena public arena;
    GwentCardToken public token;
    GwentArenaHandler public handler;

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.startPrank(config.account);
        token = new GwentCardToken();

        GwentArena arenaImpl = new GwentArena();

        // 4. Deploy GwentArena Proxy + Initialize
        bytes memory arenaInitData = abi.encodeWithSelector(
            GwentArena.initialize.selector,
            config.account,
            address(token)
        );
        ERC1967Proxy arenaProxy = new ERC1967Proxy(
            address(arenaImpl),
            arenaInitData
        );

        arena = GwentArena(address(arenaProxy));

        token.grantMinterRole(address(arena));
        token.grantBurnerRole(address(arena));
        token.grantMinterRole(address(this)); // Admin
        token.grantLockerRole(address(arena));

        handler = new GwentArenaHandler(arena, token);
        vm.stopPrank();

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = GwentArenaHandler.enterArena.selector;
        selectors[1] = GwentArenaHandler.performAutomation.selector;
        selectors[2] = GwentArenaHandler.commitAndReveal.selector;
        selectors[3] = GwentArenaHandler.claimRewards.selector;

        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );

        targetContract(address(handler));
    }

    /**
     * @notice Invariant 2: Match Phase Consistency
     * Resolution phase implies both players revealed.
     */
    function invariant_matchPhaseIntegrity() public view {
        uint256 count = arena.matchCount();
        for (uint i = 0; i < count; i++) {
            MatchInfo memory info = arena.getMatchInfo(i);
            if (info.phase == Phase.WaitingForResolution) {
                assertTrue(
                    info.revealed1 && info.revealed2,
                    "Resolution started without dual reveal"
                );
            }
        }
    }

    /**
     * @notice Invariant 3: Hero Sovereignty (Mathematical Purity)
     * Hero power (Slot 0) must NEVER be modified by calculateFinalPower.
     */
    function invariant_HeroSovereignty() public view {
        (
            uint256 p,
            uint256 r,
            uint256 m,
            uint256 mard,
            uint256 h,
            uint256 t
        ) = handler.getLastCombatInputs();

        // Skip if handler hasn't run combat math yet
        if (p == 0) return;

        uint256 result = arena.calculateFinalPower_External(
            p,
            r,
            m,
            mard,
            h,
            t
        );

        // Bits 0-63 (Hero Slot) must remain identical to input
        assertEq(
            result & 0xFFFFFFFFFFFFFFFF,
            p & 0xFFFFFFFFFFFFFFFF,
            "Hero power leaked or modified!"
        );
    }

    /**
     * @notice Invariant 4: Bit Slot Isolation
     * Ensure row scoring doesn't leak into adjacent bits or overflow uint64.
     */
    function invariant_BitSlotIsolation() public view {
        (
            uint256 p,
            uint256 r,
            uint256 m,
            uint256 mard,
            uint256 h,
            uint256 t
        ) = handler.getLastCombatInputs();
        if (p == 0) return;

        uint256 result = arena.calculateFinalPower_External(
            p,
            r,
            m,
            mard,
            h,
            t
        );

        for (uint i = 1; i <= 3; i++) {
            uint256 rowScore = (result >> (i * 64)) & 0xFFFFFFFFFFFFFFFF;
            // High scores (e.g. 10 units at 100 power) are expected,
            // but bit leakage would shift the whole word or touch Slot 0.
            assertTrue(
                rowScore < 0xFFFFFFFFFFFFFFFF,
                "Row power overflowed bit-slot!"
            );
        }
    }

    /**
     * @notice Invariant 5: Transformation Resilience
     * Provenance: Modified Design.
     * Bear status (transPower) must be preserved in final math regardless of other row modifiers.
     */
    function invariant_TransformationResilience() public view {
        (
            uint256 p,
            uint256 r,
            uint256 m,
            uint256 mard,
            uint256 h,
            uint256 t
        ) = handler.getLastCombatInputs();
        if (p == 0) return;

        uint256 result = arena.calculateFinalPower_External(
            p,
            r,
            m,
            mard,
            h,
            t
        );

        for (uint i = 1; i <= 3; i++) {
            uint256 shift = i * 64;
            uint256 mardRow = (mard >> shift) & 0xFFFFFFFF;
            uint256 extra = (t >> shift) & 0xFFFFFFFF;
            uint256 rowScore = (result >> shift) & 0xFFFFFFFF;

            if (mardRow > 0 && extra > 0) {
                // If Mardroeme is active, the transformation bonus MUST be present in the final score.
                assertTrue(
                    rowScore >= extra,
                    "Transformation bonus was lost in combat math!"
                );
            }
        }
    }
}
