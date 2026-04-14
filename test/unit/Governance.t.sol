// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GwentGovernor} from "../../src/GwentGovernor.sol";
import {GwentTimeLock} from "../../src/GwentTimeLock.sol";
import {GwentCardToken} from "../../src/GwentCardToken.sol";
import {GwentArena} from "../../src/GwentArena.sol";
import {GwentSystem} from "../../src/GwentSystem.sol";
import {DeployGwent} from "../../script/Deploy.s.sol";
import {DeployDAO} from "../../script/DeployDAO.s.sol";
import {HelperConfig} from "../../script/Helperconfig.s.sol";

contract GovernanceTest is Test {
    GwentGovernor public governor;
    GwentTimeLock public timelock;
    GwentCardToken public token;
    GwentArena public arena;
    GwentSystem public gwentSystem;
    HelperConfig public helperConfig;

    address public voter = makeAddr("voter");
    uint256 public constant INITIAL_VOTER_BALANCE = 1000 ether;

    function setUp() public {
        // 1. Deploy Core Game
        DeployGwent deployer = new DeployGwent();
        (token, arena, gwentSystem, helperConfig) = deployer.run();

        // 2. Deploy DAO and Transfer Roles
        DeployDAO daoDeployer = new DeployDAO();
        (governor, timelock) = daoDeployer.run(
            address(token),
            address(arena),
            address(gwentSystem)
        );

        // 3. Setup Voter
        vm.startBroadcast(helperConfig.getConfig().account);
        token.airdropCurrencySingle(voter, INITIAL_VOTER_BALANCE);
        vm.stopBroadcast();
    }

    function testCantUpdateFeeWithoutDAO() public {
        vm.expectRevert();
        vm.prank(voter);
        arena.setEntryFee(100 ether);
    }

    function testDAOCanUpdateFee() public {
        uint256 newFee = 75 ether;
        string memory description = "Proposal #1: Change entry fee to 75 Gold";
        bytes memory encodedCall = abi.encodeWithSelector(
            arena.setEntryFee.selector,
            newFee
        );

        address[] memory targets = new address[](1);
        targets[0] = address(arena);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = encodedCall;

        // 1. Proposer delegates to self to activate voting power
        vm.prank(voter);
        token.delegate(voter);

        // Move forward 1 block so the voting power is "past votes"
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        // 2. Propose
        vm.prank(voter);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        console.log("Proposal State:", uint256(governor.state(proposalId))); // Pending

        // 3. Wait for voting delay (1 day)
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        console.log(
            "Proposal State after delay:",
            uint256(governor.state(proposalId))
        ); // Active

        // 4. Vote
        vm.prank(voter);
        governor.castVoteWithReason(
            proposalId,
            1,
            "Because we need lower fees!"
        ); // 1 = For

        // 5. Wait for voting period (1 week)
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        console.log(
            "Proposal State after voting:",
            uint256(governor.state(proposalId))
        ); // Succeeded

        // 6. Queue to Timelock
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        // 7. Wait for Timelock delay (1 day)
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        vm.roll(block.number + timelock.getMinDelay() + 1);

        // 8. Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        // 9. Verify the fee was updated!
        assertEq(arena.entryFee(), newFee);
    }

    function testGuardianCanVetoMaliciousProposal() public {
        // 1. Setup a proposal
        uint256 entryFee = 1000 ether; // Maliciously high fee
        address[] memory targetsArr = new address[](1);
        targetsArr[0] = address(arena);
        uint256[] memory valuesArr = new uint256[](1);
        valuesArr[0] = 0;
        bytes[] memory calldatasArr = new bytes[](1);
        calldatasArr[0] = abi.encodeWithSelector(
            GwentArena.setEntryFee.selector,
            entryFee
        );
        string memory description = "Attack: Set fee to 1000 Gold";

        vm.prank(voter);
        token.delegate(voter);
        vm.roll(block.number + 1);

        vm.prank(voter);
        uint256 proposalId = governor.propose(
            targetsArr,
            valuesArr,
            calldatasArr,
            description
        );

        // 2. Pass the vote
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(voter);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        // 3. Queue the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targetsArr, valuesArr, calldatasArr, descriptionHash);

        // 4. Guardian Veto!
        // We granted GUARDIAN_ROLE to config.account (address(this) in tests setup)
        // Actually, helperConfig account is usually address(0x1804...)
        // But in setup we used config.account.
        // Let's get it from helperConfig.
        address guardian = helperConfig.getConfig().account;

        vm.prank(guardian);
        governor.castVeto(targetsArr, valuesArr, calldatasArr, descriptionHash);

        // 5. Verify state is Canceled
        assertEq(uint256(governor.state(proposalId)), 2); // 2 = Canceled
    }

    function testSupermajorityVetoRequiresTwoOfThree() public {
        // 1. Setup 3 guardians total
        address guardian2 = makeAddr("guardian2");
        address guardian3 = makeAddr("guardian3");
        bytes32 guardianRole = governor.GUARDIAN_ROLE();

        vm.startPrank(helperConfig.getConfig().account);
        governor.grantRole(guardianRole, guardian2);
        governor.grantRole(guardianRole, guardian3);
        vm.stopPrank();

        // 2. Propose something
        string memory description = "Proposal Supermajority: Logic Update";
        address[] memory targetsArr = new address[](1);
        targetsArr[0] = address(arena);
        uint256[] memory valuesArr = new uint256[](1);
        valuesArr[0] = 0;
        bytes[] memory calldatasArr = new bytes[](1);
        calldatasArr[0] = abi.encodeWithSelector(
            GwentArena.setEntryFee.selector,
            1 ether
        );

        vm.prank(voter);
        token.delegate(voter);
        vm.roll(block.number + 1);

        vm.prank(voter);
        uint256 proposalId = governor.propose(
            targetsArr,
            valuesArr,
            calldatasArr,
            description
        );

        // 3. Move to Queue state
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(voter);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targetsArr, valuesArr, calldatasArr, descriptionHash);

        // 4. Guardian 1 Vetoes (1/3 = 33.3%) -> Should stay Queued
        vm.prank(helperConfig.getConfig().account);
        governor.castVeto(targetsArr, valuesArr, calldatasArr, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), 5); // 5 = Queued

        // 5. Guardian 2 Vetoes (2/3 = 66.6%) -> Should trigger Cancel
        // Math: (2 * 100) >= (3 * 66) is (200 >= 198) which is TRUE
        vm.prank(guardian2);
        governor.castVeto(targetsArr, valuesArr, calldatasArr, descriptionHash);

        // 6. Verify state is Canceled
        assertEq(uint256(governor.state(proposalId)), 2); // 2 = Canceled
    }
}
