// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentGovernor} from "../../src/GwentGovernor.sol";
import {GwentTimeLock} from "../../src/GwentTimeLock.sol";
import {HelperConfig} from "../Helperconfig.s.sol";
import {GwentCardToken} from "../../src/GwentCardToken.sol";

contract DeployTimeLock is Script {
    uint256 public constant MIN_DELAY = 1 days; // 1 day delay in the timelock
    address public tokenProxy = 0x804671566D9e584145c0340B72aF5F9904974A66;

    function run() external returns (GwentTimeLock) {
        HelperConfig helperConfig = new HelperConfig();
        address deployerAccount = helperConfig.getConfig().account;

        vm.startBroadcast();
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        GwentTimeLock timelock = new GwentTimeLock(
            MIN_DELAY,
            proposers,
            executors,
            deployerAccount
        );
        vm.stopBroadcast();

        return (timelock);
    }
}
