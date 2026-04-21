// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentSystem} from "../../src/GwentSystem.sol";
import {HelperConfig} from "../Helperconfig.s.sol";
import {
    ERC1967Proxy
} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySystem is Script {
    function run() external returns (GwentSystem) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address token = 0x804671566D9e584145c0340B72aF5F9904974A66;
        config
            .subscriptionId = 115411102956592612078284915388094097884731217526488649262273629406330157488272;
        vm.startBroadcast();
        GwentSystem systemImpl = new GwentSystem(config.vrfCoordinatorV2_5);
        bytes memory systemInitData = abi.encodeWithSelector(
            GwentSystem.initialize.selector,
            config.account,
            config.subscriptionId,
            config.gasLane,
            config.callbackGasLimit,
            token
        );
        ERC1967Proxy systemProxy = new ERC1967Proxy(
            address(systemImpl),
            systemInitData
        );
        GwentSystem system = GwentSystem(address(systemProxy));
        vm.stopBroadcast();

        return (system);
    }
}
