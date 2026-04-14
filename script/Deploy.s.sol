// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GwentCardToken} from "../src/GwentCardToken.sol";
import {GwentArena} from "../src/GwentArena.sol";
import {GwentSystem} from "../src/GwentSystem.sol";
import {HelperConfig} from "./Helperconfig.s.sol";
import {
    IVRFCoordinatorV2Plus
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {
    CreateSubscription,
    FundSubscription,
    AddConsumer
} from "./Interactions.s.sol";
import {
    ERC1967Proxy
} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployGwent is Script {
    function run()
        external
        returns (GwentCardToken, GwentArena, GwentSystem, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // If we don't have a subId, create and fund one
        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            config.subscriptionId = createSubscription
                .createSubscriptionUsingConfig(
                    config.vrfCoordinatorV2_5,
                    config.account
                );

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscriptionUsingConfig(
                config.vrfCoordinatorV2_5,
                config.subscriptionId,
                config.link,
                config.account
            );
        }

        vm.startBroadcast(config.account);
        GwentCardToken token = new GwentCardToken();

        // 1. Deploy GwentSystem Implementation
        GwentSystem systemImpl = new GwentSystem(config.vrfCoordinatorV2_5);

        // 2. Deploy GwentSystem Proxy + Initialize
        bytes memory systemInitData = abi.encodeWithSelector(
            GwentSystem.initialize.selector,
            config.account,
            config.subscriptionId,
            config.gasLane,
            config.callbackGasLimit,
            address(token)
        );
        ERC1967Proxy systemProxy = new ERC1967Proxy(
            address(systemImpl),
            systemInitData
        );
        GwentSystem system = GwentSystem(address(systemProxy));

        // 3. Deploy GwentArena Implementation
        GwentArena arenaImpl = new GwentArena();

        // 4. Deploy GwentArena Proxy + Initialize
        bytes memory arenaInitData = abi.encodeWithSelector(
            GwentArena.initialize.selector,
            config.account,
            address(token)
        );
        ERC1967Proxy arenaProxy = new ERC1967Proxy(
            address(arenaImpl),
            arenaInitData
        );
        GwentArena arena = GwentArena(address(arenaProxy));

        // Registry handshake (pointing to Proxy addresses)
        token.grantRole(token.MINTER_ROLE(), address(system));
        token.grantRole(token.BURNER_ROLE(), address(system));
        token.grantRole(token.MINTER_ROLE(), address(arena));
        token.grantRole(token.LOCKER_ROLE(), address(arena));
        token.grantRole(token.BURNER_ROLE(), address(arena));
        vm.stopBroadcast();

        // Add consumer - pointing to System Proxy address
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumerUsingConfig(
            config.vrfCoordinatorV2_5,
            config.subscriptionId,
            address(system),
            config.account
        );

        return (token, arena, system, helperConfig);
    }
}
