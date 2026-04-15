// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {WETH} from "../../src/WETH.sol";
import {HelperConfig} from "../Helperconfig.s.sol";

contract DeployWeth is Script {
    function run() external returns (WETH) {
        vm.startBroadcast();
        WETH weth = new WETH();
        vm.stopBroadcast();

        return (weth);
    }
}
