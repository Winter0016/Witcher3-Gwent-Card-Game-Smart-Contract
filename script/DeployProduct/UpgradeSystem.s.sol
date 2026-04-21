// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentSystem} from "../../src/GwentSystem.sol";
import {
    ERC1967Proxy
} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeSystem is Script {
    function run() external {
        address proxyAddress = 0x49eE0547272E50Fec45e8C11E0148BF97c803f24;
        address vrfCoordinator = 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61;

        vm.startBroadcast();
        GwentSystem newImpl = new GwentSystem(vrfCoordinator);

        GwentSystem proxy = GwentSystem(proxyAddress);
        proxy.upgradeToAndCall(
            address(newImpl),
            abi.encodeWithSelector(
                GwentSystem.setVRFCoordinator.selector,
                vrfCoordinator
            )
        );
        vm.stopBroadcast();
    }
}
