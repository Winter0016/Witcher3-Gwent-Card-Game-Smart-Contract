// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentGovernor} from "../src/GwentGovernor.sol";
import {GwentTimeLock} from "../src/GwentTimeLock.sol";
import {GwentCardToken} from "../src/GwentCardToken.sol";
import {GwentArena} from "../src/GwentArena.sol";
import {GwentSystem} from "../src/GwentSystem.sol";
import {HelperConfig} from "./Helperconfig.s.sol";

contract DeployDAO is Script {
    uint256 public constant MIN_DELAY = 1 days; // 1 day delay in the timelock

    function run(
        address tokenProxy,
        address arenaProxy,
        address systemProxy
    ) external returns (GwentGovernor, GwentTimeLock) {
        HelperConfig helperConfig = new HelperConfig();
        address deployerAccount = helperConfig.getConfig().account;

        vm.startBroadcast(deployerAccount);

        // 1. Deploy Timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        GwentTimeLock timelock = new GwentTimeLock(
            MIN_DELAY,
            proposers,
            executors,
            deployerAccount
        );

        // 2. Deploy Governor
        GwentGovernor governor = new GwentGovernor(
            GwentCardToken(payable(tokenProxy)),
            timelock,
            deployerAccount
        );

        // 3. Setup Timelock Roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 cancellerRole = timelock.CANCELLER_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        // The Governor needs to be able to Propose and Cancel
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(cancellerRole, address(governor));

        // Anyone can execute once the delay is over
        timelock.grantRole(executorRole, address(0));

        // Revoke admin powers from the deployer (handing over to the Timelock itself)
        // timelock.revokeRole(adminRole, deployerAccount);

        // 4. Transfer Game Roles to Timelock
        GwentArena arena = GwentArena(arenaProxy);
        GwentSystem system = GwentSystem(systemProxy);
        GwentCardToken token = GwentCardToken(payable(tokenProxy));

        bytes32 upgraderRole = keccak256("UPGRADER_ROLE");
        bytes32 defaultAdminRole = 0x00;

        // Grant roles to Timelock
        arena.grantRole(upgraderRole, address(timelock));
        arena.grantRole(defaultAdminRole, address(timelock));

        system.grantRole(upgraderRole, address(timelock));
        system.grantRole(defaultAdminRole, address(timelock));

        token.grantRole(defaultAdminRole, address(timelock));

        // Optional: Renounce roles from deployer (uncomment for full decentralization)
        // arena.revokeRole(defaultAdminRole, deployerAccount);
        // system.revokeRole(defaultAdminRole, deployerAccount);
        // token.revokeRole(defaultAdminRole, deployerAccount);

        vm.stopBroadcast();

        return (governor, timelock);
    }
}
