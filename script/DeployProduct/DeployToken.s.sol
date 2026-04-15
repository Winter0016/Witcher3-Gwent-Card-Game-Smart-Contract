// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentCardToken} from "../../src/GwentCardToken.sol";
import {HelperConfig} from "../Helperconfig.s.sol";

contract DeployToken is Script {
    function run() external returns (GwentCardToken) {
        vm.startBroadcast();
        GwentCardToken token = new GwentCardToken();
        vm.stopBroadcast();

        return (token);
    }
}
