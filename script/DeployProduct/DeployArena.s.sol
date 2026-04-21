// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentArena} from "../../src/GwentArena.sol";
import {HelperConfig} from "../Helperconfig.s.sol";
import {
    ERC1967Proxy
} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployArena is Script {
    function run() external returns (GwentArena) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address token = 0x804671566D9e584145c0340B72aF5F9904974A66;
        vm.startBroadcast();
        GwentArena arenaImpl = new GwentArena();

        // 4. Deploy GwentArena Proxy + Initialize
        bytes memory arenaInitData = abi.encodeWithSelector(
            GwentArena.initialize.selector,
            config.account,
            token
        );
        ERC1967Proxy arenaProxy = new ERC1967Proxy(
            address(arenaImpl),
            arenaInitData
        );
        GwentArena arena = GwentArena(address(arenaProxy));
        vm.stopBroadcast();

        return (arena);
    }
}
