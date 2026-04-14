//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GwentSystem} from "../../src/GwentSystem.sol";
import {DeployGwent} from "../../script/Deploy.s.sol";
import {UpgradeSystem} from "./mock/UpgradeSystem.s.sol";
import {GwentSystemVersion2} from "./mock/GwentSystemVersion2.sol";
import {HelperConfig} from "../../script/Helperconfig.s.sol";

contract UpgradeableTest is Test {
    GwentSystem public gwentSystem;
    UpgradeSystem public upgradeScript;
    HelperConfig public helperConfig;

    function setUp() public {
        DeployGwent deployer = new DeployGwent();
        (, , gwentSystem, helperConfig) = deployer.run();
        upgradeScript = new UpgradeSystem();
    }

    function testProxyStartsAtVersionOne() public view {
        assertEq(gwentSystem.version(), 1);
    }

    function testUpgradeWorks() public {
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // 1. Perform the upgrade
        // The script now handles its own prank/broadcast using the admin address
        address proxyAddress = upgradeScript.run(
            address(gwentSystem),
            config.vrfCoordinatorV2_5,
            config.account
        );

        // 2. Wrap the proxy address in the V2 interface
        GwentSystemVersion2 v2 = GwentSystemVersion2(proxyAddress);

        // 3. Verify: Address should be the same, but version should be 2!
        assertEq(proxyAddress, address(gwentSystem));
        assertEq(v2.version(), 2);
    }
}
