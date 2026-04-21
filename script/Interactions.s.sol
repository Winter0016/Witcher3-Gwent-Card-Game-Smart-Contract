// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./Helperconfig.s.sol";
import {
    IVRFCoordinatorV2Plus
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {
    VRFV2PlusClient
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig(
        address vrfCoordinatorV2_5,
        address account
    ) public returns (uint256) {
        vm.startBroadcast(account);
        uint256 subId = IVRFCoordinatorV2Plus(vrfCoordinatorV2_5)
            .createSubscription();
        vm.stopBroadcast();
        console2.log("Your subscription Id is: ", subId);
        console2.log(
            "Please update your subscription Id in HelperConfig.s.sol"
        );
        return subId;
    }

    function run() external returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        return
            createSubscriptionUsingConfig(
                config.vrfCoordinatorV2_5,
                config.account
            );
    }
}

contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig(
        address vrfCoordinatorV2_5,
        uint256 subId,
        address link,
        address account
    ) public {
        console2.log("Funding subscription: ", subId);
        console2.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console2.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(account);
            IVRFCoordinatorV2Plus(vrfCoordinatorV2_5)
                .fundSubscriptionWithNative{value: FUND_AMOUNT}(subId);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(
                vrfCoordinatorV2_5,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        fundSubscriptionUsingConfig(
            config.vrfCoordinatorV2_5,
            config.subscriptionId,
            config.link,
            config.account
        );
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(
        address vrfCoordinatorV2_5,
        uint256 subId,
        address consumer,
        address account
    ) public {
        console2.log("Adding consumer contract: ", consumer);
        console2.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console2.log("On subId: ", subId);
        vm.startBroadcast(account);
        IVRFCoordinatorV2Plus(vrfCoordinatorV2_5).addConsumer(subId, consumer);
        vm.stopBroadcast();
    }

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        // Since this script is typically run after deployment,
        // you'd need the Deployed Contract address here.
    }
}
