// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentArena} from "../../src/GwentArena.sol";

contract UpgradeArena is Script {
    function run() external {
        // Your current Arena Proxy address on Arbitrum Sepolia
        address proxyAddress = 0x7B417Fa3cfCA13A3b8B83703B8ACB4be3997c6Bd;

        vm.startBroadcast();
        
        // Deploy the new implementation (Version 2)
        GwentArena newImpl = new GwentArena();
        
        // Perform the upgrade
        GwentArena(proxyAddress).upgradeTo(address(newImpl));
        
        vm.stopBroadcast();
    }
}
