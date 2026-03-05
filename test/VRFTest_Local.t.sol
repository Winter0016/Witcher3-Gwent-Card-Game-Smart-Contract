//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { VRFCoordinatorV2_5Mock } from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {GwentSystem} from "../src/GwentSystem.sol";
import {GwentCardToken} from "../src/GwentCardToken.sol";

contract VRFTest_Local is Test {
    VRFCoordinatorV2_5Mock vrfCoordinator;
    GwentSystem gwentSystem;
    GwentCardToken gwentCardToken;
    // address DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    uint256 subscriptionId;
    bytes32 gasLane = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 callbackGasLimit = 300000;

    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;
    address player1 = makeAddr("player1");
    function setUp() public {
        vm.deal(DEFAULT_SENDER, 100 ether);
        vm.startPrank(DEFAULT_SENDER);
        gwentCardToken = new GwentCardToken();
        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        subscriptionId = vrfCoordinator.createSubscription();
        gwentSystem = new GwentSystem(
            subscriptionId,
            gasLane,
            callbackGasLimit,
            address(vrfCoordinator),
            address(gwentCardToken)
        );
        gwentCardToken.grantRole(
            gwentCardToken.MINTER_ROLE(),
            address(gwentSystem)
        );
        gwentCardToken.grantRole(gwentCardToken.BURNER_ROLE(), address(gwentSystem));
        gwentCardToken.airdropCurrencySingle(address(player1), 100e18);
        vrfCoordinator.fundSubscription(subscriptionId, 5000 ether);
        vrfCoordinator.addConsumer(subscriptionId, address(gwentSystem));
        vm.stopPrank();
        vm.deal(address(gwentSystem), 10 ether);
    }

    function testOpenNorthernPack() public {
        vm.startPrank(player1);
        uint256 requestId = gwentSystem.openNorthenRealmsPack();
        vrfCoordinator.fulfillRandomWords(requestId, address(gwentSystem));
        uint256[] memory rolls = gwentSystem.claimRolls(requestId);
        uint256 balanceRolls1 = gwentCardToken.balanceOf(player1, rolls[0]);
        vm.stopPrank();
        assertEq(rolls.length, 6);
        assertGt(balanceRolls1, 0);

    }
    function testOpenScoialPack() public {
        vm.startPrank(player1);
        uint256 requestId = gwentSystem.openScoialTaelPack();
        vrfCoordinator.fulfillRandomWords(requestId, address(gwentSystem));
        uint256[] memory rolls = gwentSystem.claimRolls(requestId);
        uint256 balanceRolls1 = gwentCardToken.balanceOf(player1, rolls[0]);
        assertEq(rolls.length, 5);
        assertGt(balanceRolls1, 0);
        vm.stopPrank();
    }
    function testOpenNifPack() public {
        vm.startPrank(player1);
        uint256 requestId = gwentSystem.openNilfgaardPack();
        vrfCoordinator.fulfillRandomWords(requestId, address(gwentSystem));
        uint256[] memory rolls = gwentSystem.claimRolls(requestId);
        uint256 balanceRolls1 = gwentCardToken.balanceOf(player1, rolls[0]);
        assertEq(rolls.length, 3);
        assertGt(balanceRolls1, 0);
        vm.stopPrank();
    }
    function testOpenMonsterPack() public {
        vm.startPrank(player1);
        uint256 requestId = gwentSystem.openMonstersPack();
        vrfCoordinator.fulfillRandomWords(requestId, address(gwentSystem));
        uint256[] memory rolls = gwentSystem.claimRolls(requestId);
        uint256 balanceRolls1 = gwentCardToken.balanceOf(player1, rolls[0]);
        assertEq(rolls.length, 5);
        assertGt(balanceRolls1, 0);
        vm.stopPrank();
    }
    function testOpeSkillegePack() public {
        vm.startPrank(player1);
        uint256 requestId = gwentSystem.openSkelligePack();
        vrfCoordinator.fulfillRandomWords(requestId, address(gwentSystem));
        uint256[] memory rolls = gwentSystem.claimRolls(requestId);
        uint256 balanceRolls1 = gwentCardToken.balanceOf(player1, rolls[0]);
        assertEq(rolls.length, 4);
        assertGt(balanceRolls1, 0);
        vm.stopPrank();
    }
}