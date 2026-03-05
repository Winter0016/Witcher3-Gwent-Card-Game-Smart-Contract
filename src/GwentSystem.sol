//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VRFConsumerBaseV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {CardRegistryPure} from "./CardRegistryPure.sol";
import {IGwentCardToken} from "../interfaces/IGwentCardToken.sol";
contract GwentSystem is VRFConsumerBaseV2Plus {
    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    address private immutable i_cardTokenAddress;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint256 public constant PACK_PRICE = 100e18; // 100 tokens

    
    mapping(uint256 => address) private s_requestOwner;
    mapping(uint256 => uint256[]) private s_packCards;
    mapping(uint256 => PackType) private s_packTypes;
    event PackClaimed(address indexed user, uint256 indexed requestId, PackType indexed packtype);
    event PackOpened(address indexed user, uint256 indexed requestId, PackType indexed packtype, uint256 price);
    enum PackType {
        NorthernRealms,
        ScoiaTael,
        Nilfgaard,
        Monsters,
        Skellige
    }

    
    constructor(
        uint256 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2,
        address cardTokenAddress
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        i_cardTokenAddress = cardTokenAddress;
    }
    
    function openNorthenRealmsPack() external returns (uint256) {
        _burnPackPrice();
        uint256 requestID = requestcard(6);
        s_packTypes[requestID] = PackType.NorthernRealms;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(msg.sender, requestID, PackType.NorthernRealms, PACK_PRICE);
        return requestID;
    }

    function openScoialTaelPack() external returns (uint256) {
        _burnPackPrice();
        uint256 requestID = requestcard(5);
        s_packTypes[requestID] = PackType.ScoiaTael;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(msg.sender, requestID, PackType.ScoiaTael, PACK_PRICE);
        return requestID;
    }
    function openNilfgaardPack() external returns (uint256) {
        _burnPackPrice();
        uint256 requestID = requestcard(3);
        s_packTypes[requestID] = PackType.Nilfgaard;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(msg.sender, requestID, PackType.Nilfgaard, PACK_PRICE);
        return requestID;
    }
    function openMonstersPack() external returns (uint256) {
        _burnPackPrice();
        uint256 requestID = requestcard(5);
        s_packTypes[requestID] = PackType.Monsters;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(msg.sender, requestID, PackType.Monsters, PACK_PRICE);
        return requestID;
    }
    function openSkelligePack() external returns (uint256) {
        _burnPackPrice();
        uint256 requestID = requestcard(4);
        s_packTypes[requestID] = PackType.Skellige;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(msg.sender, requestID, PackType.Skellige, PACK_PRICE);
        return requestID;
    }

    function _burnPackPrice() internal {
        IGwentCardToken cardToken = IGwentCardToken(i_cardTokenAddress);
        cardToken.burnGameCurrency(msg.sender, PACK_PRICE);
    }
    
    function requestcard(uint32 numwords) internal returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: numwords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        return requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        PackType pack = s_packTypes[requestId];
        uint256[] storage cards = s_packCards[requestId];

        for (uint256 i = 0; i < randomWords.length; i++) {
            cards.push(_cardFromRandom(pack, randomWords[i]));
        }
    }


    function _cardFromRandom(
        PackType pack,
        uint256 randomWord
    ) internal pure returns (uint256) {
        uint256 roll = randomWord % 100;      // rarity
        uint256 pick = uint256(keccak256(abi.encode(randomWord)));   // card choice entropy

        if (pack == PackType.NorthernRealms) {
            return _northernRealmsCard(roll, pick);
        }
        if (pack == PackType.ScoiaTael) {
            return _sociaTaelCard(roll, pick);
        }
        if (pack == PackType.Nilfgaard) {
            return _nilfgaardCard(roll, pick);
        }
        if (pack == PackType.Monsters) {
            return _monsterCard(roll, pick);
        }
        if (pack == PackType.Skellige) {
            return _skelligeCard(roll, pick);
        }

        revert("Unknown pack");
    }


    function _northernRealmsCard(
        uint256 roll,
        uint256 pick
    ) internal pure returns (uint256) {

        // COMMON 50% → IDs 1–5
        if (roll < 50) {
            return 1 + (pick % 5); // 1..5
        }

        // UNCOMMON 30% → IDs 6–16
        if (roll < 80) {
            return 6 + (pick % 11); // 6..16
        }

        // RARE 15% → IDs 17–20
        if (roll < 95) {
            return 17 + (pick % 4); // 17..20
        }

        // RARE+ 4% → ID 21
        if (roll < 99) {
            return 21;
        }

        // HERO 1% → IDs 22–25
        return 22 + (pick % 4); // 22..25
    }
    function _sociaTaelCard(
        uint256 roll,
        uint256 pick
    ) internal pure returns (uint256) {

        if (roll < 50) {
            return 26 + (pick % 4); 
        }

        if (roll < 80) {
            return 30 + (pick % 7); 
        }

        if (roll < 95) {
            return 37 + (pick % 6); 
        }

        if (roll < 99) {
            return 43;
        }

        return 44 + (pick % 5); 
    }
    function _nilfgaardCard(
        uint256 roll,
        uint256 pick
    ) internal pure returns (uint256) {

        if (roll < 50) {
            return 49 + (pick % 6); 
        }

        if (roll < 80) {
            return 55 + (pick % 11); 
        }

        if (roll < 95) {
            return 66 + (pick % 5); 
        }

        if (roll < 99) {
            return 71 + (pick % 3); 
        }

        return 74 + (pick % 4); 
    }
    function _monsterCard(
        uint256 roll,
        uint256 pick
    ) internal pure returns (uint256) {

        if (roll < 50) {
            return 78 + (pick % 9); 
        }

        if (roll < 80) {
            return 87 + (pick % 14); 
        }

        if (roll < 95) {
            return 101 + (pick % 8); 
        }

        if (roll < 99) {
            return 109 ; 
        }

        return 110 + (pick % 3); 
    }
    function _skelligeCard(
        uint256 roll,
        uint256 pick
    ) internal pure returns (uint256) {

        if (roll < 50) {
            return 113 + (pick % 4); 
        }

        if (roll < 80) {
            return 117 + (pick % 9); 
        }

        if (roll < 95) {
            return 126 + (pick % 6); 
        }

        if (roll < 99) {
            return 132 ; 
        }

        return 133 + (pick % 3); 
    }

    function claimRolls(uint256 requestId) external returns (uint256[] memory) {
        require(s_requestOwner[requestId] == msg.sender, "Not owner");
        require(s_packCards[requestId].length > 0, "Not fulfilled");

        uint256[] storage cards = s_packCards[requestId];

        for (uint256 i = 0; i < cards.length; i++) {
            IGwentCardToken(i_cardTokenAddress).mint(msg.sender, cards[i], 1);
        }
        emit PackClaimed(msg.sender, requestId, s_packTypes[requestId]);
        return cards;
        // cleanup
        delete s_packCards[requestId];
        delete s_packTypes[requestId];
        delete s_requestOwner[requestId];
    }


    function InspectCard(uint16 id) external pure returns (CardRegistryPure.Card memory) {
        return CardRegistryPure.getCard(id);
    }
}