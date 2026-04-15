//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {GwentArena} from "../../src/GwentArena.sol";
import {GwentSystem} from "../../src/GwentSystem.sol";
import {GwentCardToken} from "../../src/GwentCardToken.sol";
import {GwentGovernor} from "../../src/GwentGovernor.sol";
import {GwentTimeLock} from "../../src/GwentTimeLock.sol";

contract interaction is Script {
    GwentArena public arena;
    GwentSystem public system;
    GwentCardToken public token;
    GwentGovernor public governor;
    GwentTimeLock public timelock;

    function run() external {
        arena = GwentArena(0x7B417Fa3cfCA13A3b8B83703B8ACB4be3997c6Bd);
        system = GwentSystem(0x49eE0547272E50Fec45e8C11E0148BF97c803f24);
        token = GwentCardToken(
            payable(0x804671566D9e584145c0340B72aF5F9904974A66)
        );
        governor = GwentGovernor(
            payable(0x763ec857c1444a8D371435ED513F9852B7607263)
        );
        timelock = GwentTimeLock(
            payable(0xB9f3989d8740Ae6055Fb0e7Aeb6A93f176ca0A47)
        );

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 cancellerRole = timelock.CANCELLER_ROLE();
        bytes32 defaultAdminRole = 0x00;

        vm.startBroadcast();
        token.grantRole(token.MINTER_ROLE(), address(system));
        token.grantRole(token.BURNER_ROLE(), address(system));
        token.grantRole(token.MINTER_ROLE(), address(arena));
        token.grantRole(token.LOCKER_ROLE(), address(arena));
        token.grantRole(token.BURNER_ROLE(), address(arena));

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(cancellerRole, address(governor));

        // Anyone can execute once the delay is over
        timelock.grantRole(executorRole, address(0));

        //
        arena.grantRole(defaultAdminRole, address(timelock));

        system.grantRole(defaultAdminRole, address(timelock));

        token.grantRole(defaultAdminRole, address(timelock));

        vm.stopBroadcast();
    }
}
