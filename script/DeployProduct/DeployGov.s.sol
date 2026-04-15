// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentGovernor} from "../../src/GwentGovernor.sol";
import {GwentTimeLock} from "../../src/GwentTimeLock.sol";
import {HelperConfig} from "../Helperconfig.s.sol";
import {GwentCardToken} from "../../src/GwentCardToken.sol";

contract DeployGov is Script {
    uint256 public constant MIN_DELAY = 1 days; // 1 day delay in the timelock
    address public tokenProxy = 0x804671566D9e584145c0340B72aF5F9904974A66;
    GwentTimeLock public timelockContract =
        GwentTimeLock(payable(0xB9f3989d8740Ae6055Fb0e7Aeb6A93f176ca0A47));

    function run() external returns (GwentGovernor) {
        HelperConfig helperConfig = new HelperConfig();
        address deployerAccount = helperConfig.getConfig().account;

        vm.startBroadcast();
        // 2. Deploy Governor
        GwentGovernor governor = new GwentGovernor(
            GwentCardToken(payable(tokenProxy)),
            timelockContract,
            deployerAccount
        );
        vm.stopBroadcast();

        return (governor);
    }
}
