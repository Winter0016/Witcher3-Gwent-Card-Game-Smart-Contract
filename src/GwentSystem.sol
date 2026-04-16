//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    IVRFCoordinatorV2Plus
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {
    VRFConsumerBaseV2Plus
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {CardRegistryPure} from "./CardRegistryPure.sol";
import {IGwentCardToken} from "../interfaces/IGwentCardToken.sol";
import {
    UUPSUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {
    Initializable
} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {
    AccessControlUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

contract GwentSystem is
    Initializable,
    VRFConsumerBaseV2Plus,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    // Chainlink VRF Variables
    uint256 private s_subscriptionId;
    bytes32 private s_gasLane;
    uint32 private s_callbackGasLimit;
    address private s_cardTokenAddress;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint256 public constant PACK_PRICE = 100; // 100 tokens

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    mapping(uint256 => address) private s_requestOwner;
    mapping(uint256 => uint256[]) private s_packCards;
    mapping(uint256 => PackType) private s_packTypes;
    mapping(address => bool) public s_hasOpenedFirstPack;

    event PackClaimed(
        address indexed user,
        uint256 indexed requestId,
        PackType indexed packtype
    );
    event PackOpened(
        address indexed user,
        uint256 indexed requestId,
        PackType indexed packtype,
        uint256 amount,
        uint256 totalPrice
    );

    enum PackType {
        NorthernRealms,
        ScoiaTael,
        Nilfgaard,
        Monsters,
        Skellige
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address vrfCoordinator) VRFConsumerBaseV2Plus(vrfCoordinator) {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        uint256 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        address cardTokenAddress
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(UPGRADER_ROLE, initialOwner);

        s_subscriptionId = subscriptionId;
        s_gasLane = gasLane;
        s_callbackGasLimit = callbackGasLimit;
        s_cardTokenAddress = cardTokenAddress;
    }

    function version() external pure virtual returns (uint256) {
        return 7;
    }

    function setVRFCoordinator(
        address _vrfCoordinator
    ) external onlyRole(UPGRADER_ROLE) {
        s_vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
    }

    function openNorthenRealmsPack(
        uint32 amount
    ) external virtual returns (uint256) {
        uint32 finalAmount = _determineAmountAndCharge(amount);
        uint256 requestID = requestcard(6, finalAmount);
        s_packTypes[requestID] = PackType.NorthernRealms;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(
            msg.sender,
            requestID,
            PackType.NorthernRealms,
            finalAmount,
            s_hasOpenedFirstPack[msg.sender] ? 0 : PACK_PRICE * finalAmount
        );
        return requestID;
    }

    function openScoiaTaelPack(
        uint32 amount
    ) external virtual returns (uint256) {
        uint32 finalAmount = _determineAmountAndCharge(amount);
        uint256 requestID = requestcard(5, finalAmount);
        s_packTypes[requestID] = PackType.ScoiaTael;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(
            msg.sender,
            requestID,
            PackType.ScoiaTael,
            finalAmount,
            s_hasOpenedFirstPack[msg.sender] ? 0 : PACK_PRICE * finalAmount
        );
        return requestID;
    }

    function openNilfgaardPack(
        uint32 amount
    ) external virtual returns (uint256) {
        uint32 finalAmount = _determineAmountAndCharge(amount);
        uint256 requestID = requestcard(3, finalAmount);
        s_packTypes[requestID] = PackType.Nilfgaard;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(
            msg.sender,
            requestID,
            PackType.Nilfgaard,
            finalAmount,
            s_hasOpenedFirstPack[msg.sender] ? 0 : PACK_PRICE * finalAmount
        );
        return requestID;
    }

    function openMonstersPack(
        uint32 amount
    ) external virtual returns (uint256) {
        uint32 finalAmount = _determineAmountAndCharge(amount);
        uint256 requestID = requestcard(5, finalAmount);
        s_packTypes[requestID] = PackType.Monsters;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(
            msg.sender,
            requestID,
            PackType.Monsters,
            finalAmount,
            s_hasOpenedFirstPack[msg.sender] ? 0 : PACK_PRICE * finalAmount
        );
        return requestID;
    }

    function openSkelligePack(
        uint32 amount
    ) external virtual returns (uint256) {
        uint32 finalAmount = _determineAmountAndCharge(amount);
        uint256 requestID = requestcard(4, finalAmount);
        s_packTypes[requestID] = PackType.Skellige;
        s_requestOwner[requestID] = msg.sender;
        emit PackOpened(
            msg.sender,
            requestID,
            PackType.Skellige,
            finalAmount,
            s_hasOpenedFirstPack[msg.sender] ? 0 : PACK_PRICE * finalAmount
        );
        return requestID;
    }

    function _determineAmountAndCharge(
        uint32 amount
    ) internal virtual returns (uint32) {
        if (!s_hasOpenedFirstPack[msg.sender]) {
            s_hasOpenedFirstPack[msg.sender] = true;
            return 4; // Free starter pack worth 4 units
        } else {
            _burnPackPrice(amount);
            return amount;
        }
    }

    function _burnPackPrice(uint32 amount) internal {
        require(amount > 0, "Invalid amount");
        IGwentCardToken cardToken = IGwentCardToken(s_cardTokenAddress);
        cardToken.burnGameCurrency(msg.sender, PACK_PRICE * amount);
    }

    function requestcard(
        uint32 numWordsPerPack,
        uint32 amount
    ) internal virtual returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_gasLane,
                subId: s_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: s_callbackGasLimit,
                numWords: numWordsPerPack * amount,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        return requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {
        PackType pack = s_packTypes[requestId];
        uint256[] storage packedCards = s_packCards[requestId];

        packedCards.push(randomWords.length);

        uint256 currentPacked;
        for (uint256 i = 0; i < randomWords.length; i++) {
            uint256 cardId = _cardFromRandom(pack, randomWords[i]);
            uint256 subIdx = i % 32;

            currentPacked |= (cardId << (subIdx * 8));

            if (subIdx == 31 || i == randomWords.length - 1) {
                packedCards.push(currentPacked);
                currentPacked = 0;
            }
        }
    }

    function claimRolls(uint256 requestId) external returns (uint256[] memory) {
        address owner = s_requestOwner[requestId];
        require(owner == msg.sender, "Not owner");
        uint256[] storage packed = s_packCards[requestId];
        require(packed.length > 0, "Not fulfilled");

        uint256 totalCards = packed[0];
        uint256[] memory fullIds = new uint256[](totalCards);
        uint256[] memory counts = new uint256[](146);
        uint256 uniqueCount = 0;

        for (uint256 i = 0; i < totalCards; i++) {
            uint256 slotIdx = (i / 32) + 1;
            uint256 subIdx = i % 32;
            uint256 cardId = (packed[slotIdx] >> (subIdx * 8)) & 0xFF;

            fullIds[i] = cardId;
            if (counts[cardId] == 0) {
                uniqueCount++;
            }
            counts[cardId]++;
        }

        uint256[] memory uniqueIds = new uint256[](uniqueCount);
        uint256[] memory uniqueAmounts = new uint256[](uniqueCount);
        uint256 current = 0;
        for (uint256 i = 0; i < 146; i++) {
            if (counts[i] > 0) {
                uniqueIds[current] = i;
                uniqueAmounts[current] = counts[i];
                current++;
            }
        }

        IGwentCardToken(s_cardTokenAddress).mintBatch(
            owner,
            uniqueIds,
            uniqueAmounts,
            ""
        );

        emit PackClaimed(owner, requestId, s_packTypes[requestId]);

        delete s_packCards[requestId];
        delete s_packTypes[requestId];
        delete s_requestOwner[requestId];

        return fullIds;
    }

    function _cardFromRandom(
        PackType pack,
        uint256 randomWord
    ) internal pure virtual returns (uint256) {
        uint256 roll = randomWord % 100;
        uint256 pick = uint256(keccak256(abi.encode(randomWord)));

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
    ) internal pure virtual returns (uint256) {
        if (roll < 50) return 1 + (pick % 5);
        if (roll < 80) return 6 + (pick % 11);
        if (roll < 95) return 17 + (pick % 4);
        if (roll < 99) return 21;
        return 22 + (pick % 4);
    }

    function _sociaTaelCard(
        uint256 roll,
        uint256 pick
    ) internal pure virtual returns (uint256) {
        if (roll < 50) return 26 + (pick % 4);
        if (roll < 80) return 30 + (pick % 7);
        if (roll < 95) return 37 + (pick % 6);
        if (roll < 99) return 43;
        return 44 + (pick % 5);
    }

    function _nilfgaardCard(
        uint256 roll,
        uint256 pick
    ) internal pure virtual returns (uint256) {
        if (roll < 50) return 49 + (pick % 6);
        if (roll < 80) return 55 + (pick % 11);
        if (roll < 95) return 66 + (pick % 5);
        if (roll < 99) return 71 + (pick % 3);
        return 74 + (pick % 4);
    }

    function _monsterCard(
        uint256 roll,
        uint256 pick
    ) internal pure virtual returns (uint256) {
        if (roll < 50) return 78 + (pick % 9);
        if (roll < 80) return 87 + (pick % 14);
        if (roll < 95) return 101 + (pick % 8);
        if (roll < 99) return 109;
        return 110 + (pick % 3);
    }

    function _skelligeCard(
        uint256 roll,
        uint256 pick
    ) internal pure virtual returns (uint256) {
        if (roll < 50) return 113 + (pick % 4);
        if (roll < 80) return 117 + (pick % 9);
        if (roll < 95) return 126 + (pick % 6);
        if (roll < 99) return 132;
        return 133 + (pick % 3);
    }

    function InspectCard(
        uint16 id
    )
        external
        pure
        virtual
        returns (
            uint8 power,
            uint8 berserker_power,
            string memory ability,
            string memory unitType,
            string memory faction
        )
    {
        CardRegistryPure.Card memory card = CardRegistryPure.getCard(id);

        string[6] memory factionNames = [
            "Northern",
            "Nilfgaard",
            "Monster",
            "Scoiatael",
            "Skellige",
            "Neutral"
        ];
        faction = factionNames[uint256(card.faction)];

        string[18] memory abilityNames = [
            "None",
            "Berserker",
            "Commander_horn",
            "Decoy",
            "Hero",
            "Medic",
            "Morale_Boost",
            "Mardroeme",
            "Muster",
            "Summon",
            "Spy",
            "Tight_Bond",
            "Scorch",
            "Weather Close",
            "Weather Clears",
            "Weather Range",
            "Weather Red. Close",
            "Weather Siege"
        ];
        ability = abilityNames[uint256(card.ability)];

        string[6] memory unitTypeNames = [
            "Close Combat",
            "Ranged",
            "Siege",
            "Agile",
            "Weather",
            "Special"
        ];
        unitType = unitTypeNames[uint256(card.unitType)];

        power = card.power;
        berserker_power = card.berserker_power;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function getCardTokenAddress() external view returns (address) {
        return s_cardTokenAddress;
    }

    uint256[50] private __gap;
}
