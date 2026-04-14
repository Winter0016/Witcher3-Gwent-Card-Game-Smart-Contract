//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentSystem} from "../../../src/GwentSystem.sol";
import {GwentSystemVersion2} from "./GwentSystemVersion2.sol";

contract UpgradeSystem is Script {
    /**
     * @notice Upgrades the system proxy to Version 2.
     * @param systemProxy The address of the ERC1967 Proxy.
     * @param vrfCoordinator The VRF Coordinator address (baked into V2 bytecode).
     * @param admin The account that has the UPGRADER_ROLE on the proxy.
     */
    function run(
        address systemProxy,
        address vrfCoordinator,
        address admin
    ) external returns (address) {
        // We deploy the new logic using the admin's identity
        vm.startBroadcast(admin);
        GwentSystemVersion2 system2 = new GwentSystemVersion2(vrfCoordinator);
        vm.stopBroadcast();

        // Then perform the actual logic swap
        return upgradesystem(systemProxy, address(system2), admin);
    }

    /**
     * @notice Performs the actual proxy logic swap.
     */
    function upgradesystem(
        address systemProxy,
        address system2,
        address admin
    ) public returns (address) {
        vm.startBroadcast(admin);
        GwentSystem proxy = GwentSystem(systemProxy);
        proxy.upgradeToAndCall(system2, "");
        vm.stopBroadcast();
        return address(proxy);
    }
}
