// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGwentCardToken} from "../interfaces/IGwentCardToken.sol";
import {CardRegistryPure} from "./CardRegistryPure.sol";
import {
    ERC1155HolderUpgradeable,
    ERC1155ReceiverUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {
    AutomationCompatibleInterface
} from "chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

import {CardGameLogic} from "./CardGameLogic.sol";
import {
    Phase,
    MatchResult,
    Faction,
    ArenaEntry,
    Match,
    MatchInfo
} from "./GwentTypes.sol";

import {
    ReentrancyGuardUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import {
    Initializable
} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {
    UUPSUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {
    AccessControlUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

contract GwentArena is
    Initializable,
    ERC1155HolderUpgradeable,
    AutomationCompatibleInterface,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    IGwentCardToken public cardToken;
    address public treasury;

    uint256 public entryFee = 50 ether;
    uint256 public waitRewardPerBlock = 0.001 ether;
    uint256 public commitTimeout = 3 days;
    uint256 public revealTimeout = 1 days;
    uint256 public callerRewardPercent = 1;
    uint256 public constant MIN_DECK_SIZE = 22;
    uint256 public constant MAX_DECK_SIZE = 30;
    uint256 public constant MAX_TOTAL_CARDS = 10;
    uint256 public houseFeePercent = 2;

    mapping(address => ArenaEntry) public playerEntries;
    address[] public waitingQueue;
    mapping(uint256 => Match) public matches;
    uint256 public matchCount;
    uint256[] public resolutionQueue;
    uint256 public waitingHead;
    uint256 public resolutionHead;

    mapping(address => uint256) public pendingRewards;
    uint256 public pendingFees;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    // Custom Errors for Size Reduction
    error GwentArena__InvalidAddress();
    error GwentArena__ActiveSessionExists();
    error GwentArena__IdsAmountsMismatch();
    error GwentArena__InvalidTotalCards();
    error GwentArena__InsufficientCurrency();
    error GwentArena__InvalidMatchState();
    error GwentArena__NotYourTurn();
    error GwentArena__DeadlinePassed();
    error GwentArena__InvalidReveal();
    error GwentArena__AlreadyInitialized();
    error GwentArena__Unauthorized(address caller);
    error GwentArena__NoFeesToClaim();
    error GwentArena__InvalidDeck();
    error GwentArena__AlreadyInArena();
    error GwentArena__HashMismatch();
    error GwentArena__InvalidCardId();
    error GwentArena__InvalidTargetRow();
    error GwentArena__InvalidPhase();
    error GwentArena__DeadlineNotPassed();
    error GwentArena__NotPlayer();
    error GwentArena__InvalidHash();
    error GwentArena__AlreadyCommitted();
    error GwentArena__NoRewardsToClaim();
    error GwentArena__NotInArena();
    error GwentArena__AlreadyMatched();

    event PlayerEntered(
        address indexed player,
        Faction faction,
        uint256[] deck,
        uint256[] deckAmounts,
        uint256 stake
    );
    event MatchCreated(
        uint256 indexed matchId,
        address indexed player1,
        address indexed player2
    );
    event PlaysCommitted(uint256 indexed matchId, address player);
    event PlaysRevealed(uint256 indexed matchId, address player);
    event MatchResolved(
        uint256 indexed matchId,
        MatchResult result,
        address winner,
        uint256 p1TotalScore,
        uint256 p2TotalScore,
        uint256[3] p1RoundScores,
        uint256[3] p2RoundScores
    );
    event RewardsClaimed(address indexed player, uint256 amount);
    event EntryCancelled(address indexed player);
    event TimeoutResolved(uint256 indexed matchId, MatchResult result);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _cardToken
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ERC1155Holder_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(UPGRADER_ROLE, initialOwner);
        _grantRole(OWNER_ROLE, initialOwner);

        cardToken = IGwentCardToken(_cardToken);
        treasury = initialOwner;
    }

    function version() external pure virtual returns (uint256) {
        return 2;
    }

    function setEntryFee(
        uint256 _fee
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        entryFee = _fee;
    }

    function setHouseFeePercent(
        uint256 _percent
    ) external virtual onlyRole(OWNER_ROLE) {
        houseFeePercent = _percent;
    }

    function setCallerRewardPercent(
        uint256 _percent
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        callerRewardPercent = _percent;
    }

    function setWaitRewardPerBlock(
        uint256 _reward
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        waitRewardPerBlock = _reward;
    }

    function setCommitTimeout(
        uint256 _timeout
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        commitTimeout = _timeout;
    }

    function setRevealTimeout(
        uint256 _timeout
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        revealTimeout = _timeout;
    }

    function setTreasury(
        address _treasury
    ) external virtual onlyRole(OWNER_ROLE) {
        if (_treasury == address(0)) revert GwentArena__InvalidAddress();
        treasury = _treasury;
    }

    /**
     * @notice Get a list of waiting players, starting from the active Head.
     */
    function getWaitingPlayers(
        uint256 limit
    ) external view virtual returns (address[] memory) {
        uint256 head = waitingHead;
        uint256 total = waitingQueue.length;
        if (head >= total) return new address[](0);
        uint256 count = total - head;
        if (count > limit) count = limit;
        address[] memory activePlayers = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            activePlayers[i] = waitingQueue[head + i];
        }
        return activePlayers;
    }

    function getWaitingCount() external view virtual returns (uint256) {
        uint256 head = waitingHead;
        uint256 total = waitingQueue.length;
        if (head >= total) return 0;
        return total - head;
    }

    function getWaitingReward(
        address player
    ) external view virtual returns (uint256) {
        ArenaEntry storage entry = playerEntries[player];
        if (entry.enterBlock == 0 || entry.isMatched) return 0;

        uint256 blocksWaited = block.number - entry.enterBlock;
        uint256 timeReward = blocksWaited * waitRewardPerBlock;

        return timeReward;
    }

    function enterArena(
        Faction faction,
        uint256[] calldata cardIds,
        uint256[] calldata cardAmounts
    ) external virtual nonReentrant {
        if (
            playerEntries[msg.sender].enterBlock != 0 ||
            playerEntries[msg.sender].isMatched
        ) {
            revert GwentArena__ActiveSessionExists();
        }
        if (cardIds.length != cardAmounts.length) {
            revert GwentArena__IdsAmountsMismatch();
        }

        if (
            !CardRegistryPure.isDeckValidForFaction(
                faction,
                cardIds,
                cardAmounts
            )
        ) {
            revert GwentArena__InvalidDeck();
        }

        // Verify Ownership & Integrity (Consolidated Pass)
        uint256 totalCards = _verifyOwnership(msg.sender, cardIds, cardAmounts);
        if (totalCards < MIN_DECK_SIZE || totalCards > MAX_DECK_SIZE) {
            revert GwentArena__InvalidTotalCards();
        }
        if (playerEntries[msg.sender].enterBlock != 0) {
            revert GwentArena__AlreadyInArena();
        }

        // Protocol Lock: Prevent transfers during match
        cardToken.setTransferLock(msg.sender, true);
        cardToken.burnGameCurrency(msg.sender, entryFee);

        ArenaEntry storage entry = playerEntries[msg.sender];
        entry.deckLength = cardIds.length;
        _packDeck(msg.sender, cardIds, cardAmounts);

        entry.enterBlock = uint64(block.timestamp);
        entry.isMatched = false;
        entry.faction = faction;
        entry.stakeAmount = entryFee;

        waitingQueue.push(msg.sender);
        entry.queueIndex = uint32(waitingQueue.length - 1);

        emit PlayerEntered(msg.sender, faction, cardIds, cardAmounts, entryFee);
    }

    function _packDeck(
        address player,
        uint256[] calldata cardIds,
        uint256[] calldata cardAmounts
    ) internal {
        ArenaEntry storage entry = playerEntries[player];
        uint256[3] memory temp;
        for (uint256 i = 0; i < cardIds.length; ) {
            uint256 slot = i / 16;
            uint256 offset = (i % 16) * 16;
            // Pack: [Amount (8 bits)][ID (8 bits)]
            uint256 packedCard = (cardAmounts[i] << 8) | cardIds[i];
            temp[slot] |= (packedCard << offset);
            unchecked {
                i++;
            }
        }
        entry.packedDeck[0] = temp[0];
        entry.packedDeck[1] = temp[1];
        entry.packedDeck[2] = temp[2];
    }

    function _unpackDeck(
        address player
    ) internal view returns (uint256[] memory ids, uint256[] memory amounts) {
        ArenaEntry storage entry = playerEntries[player];
        uint256 len = entry.deckLength;
        ids = new uint256[](len);
        amounts = new uint256[](len);

        // Manual Slot Caching: Load storage slots into memory once
        uint256[3] memory localDeck = entry.packedDeck;

        for (uint256 i = 0; i < len; ) {
            uint256 slot = i / 16;
            uint256 offset = (i % 16) * 16;
            uint256 packedCard = (localDeck[slot] >> offset) & 0xFFFF;
            ids[i] = packedCard & 0xFF;
            amounts[i] = (packedCard >> 8) & 0xFF;
            unchecked {
                i++;
            }
        }
    }

    function getUnpackedDeck(
        address player
    ) external view returns (uint256[] memory ids, uint256[] memory amounts) {
        return _unpackDeck(player);
    }

    function _verifyOwnership(
        address player,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal view returns (uint256 totalCards) {
        address[] memory players = new address[](ids.length);
        for (uint256 i = 0; i < ids.length; ) {
            require(ids[i] >= 1 && ids[i] <= 144, "Invalid card ID");
            require(amounts[i] > 0, "Amount must be > 0");
            totalCards += amounts[i];

            players[i] = player;
            unchecked {
                i++;
            }
        }
        uint256[] memory balances = cardToken.balanceOfBatch(players, ids);
        for (uint256 i = 0; i < balances.length; ) {
            require(balances[i] >= amounts[i], "Insufficient NFT balance");
            unchecked {
                i++;
            }
        }
    }

    function _calculateWaitReward(
        uint256 enterBlock
    ) internal view returns (uint256) {
        uint256 blocksWaited = block.number > enterBlock
            ? (block.number - enterBlock)
            : 0;
        uint256 timeReward = blocksWaited * waitRewardPerBlock;
        return timeReward;
    }

    function _createMatch(address player1, address player2) internal {
        uint256 matchId = matchCount++;

        ArenaEntry storage entry1 = playerEntries[player1];
        ArenaEntry storage entry2 = playerEntries[player2];

        uint256 pool = entry1.stakeAmount + entry2.stakeAmount;
        uint256 houseFee = (pool * houseFeePercent) / 100;
        uint112 actualPool = uint112(pool - houseFee);

        Match storage newMatch = matches[matchId];
        newMatch.player1 = player1;
        newMatch.player2 = player2;

        newMatch.poolAmount = actualPool;
        pendingFees += houseFee;
        newMatch.phase = Phase.WaitingForCommit;
        newMatch.commitDeadline = uint64(block.timestamp + commitTimeout);
        newMatch.revealDeadline = 0; // Will be set after commit
        newMatch.result = MatchResult.Pending;

        entry1.matchIds.push(matchId);
        entry2.matchIds.push(matchId);

        emit MatchCreated(matchId, player1, player2);
    }

    function getPlayerLatestMatchId(
        address player
    ) external view returns (uint256) {
        ArenaEntry storage entry = playerEntries[player];
        if (entry.matchIds.length == 0) {
            return 0;
        }
        return entry.matchIds[entry.matchIds.length - 1];
    }

    function commitPlays(uint256 matchId, bytes32 combinedHash) external {
        Match storage match_ = matches[matchId];
        if (msg.sender != match_.player1 && msg.sender != match_.player2) revert GwentArena__NotPlayer();
        if (match_.phase != Phase.WaitingForCommit) revert GwentArena__InvalidPhase();
        if (block.timestamp > match_.commitDeadline) revert GwentArena__DeadlinePassed();

        bool isPlayer1 = msg.sender == match_.player1;

        if (isPlayer1) {
            if (combinedHash == bytes32(0)) revert GwentArena__InvalidHash();
            if (match_.player1CombinedHash != bytes32(0)) revert GwentArena__AlreadyCommitted();
            match_.player1CombinedHash = combinedHash;
        } else {
            if (combinedHash == bytes32(0)) revert GwentArena__InvalidHash();
            if (match_.player2CombinedHash != bytes32(0)) revert GwentArena__AlreadyCommitted();
            match_.player2CombinedHash = combinedHash;
        }

        if (
            match_.player1CombinedHash != bytes32(0) &&
            match_.player2CombinedHash != bytes32(0)
        ) {
            match_.phase = Phase.WaitingForReveal;
            match_.revealDeadline = uint64(block.timestamp + revealTimeout);
        }

        emit PlaysCommitted(matchId, msg.sender);
    }

    function revealPlays(
        uint256 matchId,
        uint256[] calldata r1Packed,
        uint256[] calldata r2Packed,
        uint256[] calldata r3Packed,
        uint256 salt
    ) external {
        Match storage match_ = matches[matchId];
        require(
            msg.sender == match_.player1 || msg.sender == match_.player2,
            "Not player"
        );
        require(match_.phase == Phase.WaitingForReveal, "Not in reveal phase");
        require(
            block.timestamp <= match_.revealDeadline,
            "Reveal timeout passed"
        );

        bytes32 combinedHash = keccak256(
            abi.encode(r1Packed, r2Packed, r3Packed, salt)
        );

        bool isPlayer1 = msg.sender == match_.player1;

        if (isPlayer1) {
            if (combinedHash != match_.player1CombinedHash)
                revert GwentArena__HashMismatch();
            _packRoundData(matchId, true, r1Packed, r2Packed, r3Packed);
            match_.revealed1 = true;
        } else {
            if (combinedHash != match_.player2CombinedHash)
                revert GwentArena__HashMismatch();
            _packRoundData(matchId, false, r1Packed, r2Packed, r3Packed);
            match_.revealed2 = true;
        }

        if (match_.revealed1 && match_.revealed2) {
            match_.phase = Phase.WaitingForResolution;
            resolutionQueue.push(matchId);
        }

        emit PlaysRevealed(matchId, msg.sender);
    }

    function _resolveMatch(uint256 matchId) internal {
        Match storage match_ = matches[matchId];
        uint256 p1TotalScore;
        uint256 p2TotalScore;
        uint256[3] memory p1RoundScores;
        uint256[3] memory p2RoundScores;

        // 1. Unpack Rounds
        uint256[] memory p1r1 = _unpackRound(matchId, true, 0);
        uint256[] memory p1r2 = _unpackRound(matchId, true, 1);
        uint256[] memory p1r3 = _unpackRound(matchId, true, 2);
        uint256[] memory p2r1 = _unpackRound(matchId, false, 0);
        uint256[] memory p2r2 = _unpackRound(matchId, false, 1);
        uint256[] memory p2r3 = _unpackRound(matchId, false, 2);

        // 2. Verify Deck Integrity & Card Rules (Slashing)
        (
            bool p1Valid,
            bool p2Valid,
            uint256[] memory p1RemainingDeck,
            uint256[] memory p2RemainingDeck,
            uint256[6] memory neutrals
        ) = _verifyDeckIntegrity(matchId, p1r1, p1r2, p1r3, p2r1, p2r2, p2r3);

        // Special Case: Both Cheated
        if (!p1Valid && !p2Valid) {
            match_.result = MatchResult.Both_Cheated;
            pendingRewards[treasury] += match_.poolAmount;
            emit MatchResolved(
                matchId,
                match_.result,
                address(0),
                0,
                0,
                p1RoundScores,
                p2RoundScores
            );
            return;
        }

        if (p1Valid && p2Valid) {
            uint8 winnerIndex;
            (
                winnerIndex,
                p1TotalScore,
                p2TotalScore,
                p1RoundScores,
                p2RoundScores
            ) = CardGameLogic.FindWinner(
                    match_,
                    p1RemainingDeck,
                    p2RemainingDeck,
                    neutrals,
                    p1r1,
                    p1r2,
                    p1r3,
                    p2r1,
                    p2r2,
                    p2r3
                );
            if (winnerIndex == 1) {
                match_.result = MatchResult.Player1Wins;
                pendingRewards[match_.player1] += match_.poolAmount;
            } else if (winnerIndex == 2) {
                match_.result = MatchResult.Player2Wins;
                pendingRewards[match_.player2] += match_.poolAmount;
            } else if (winnerIndex == 3) {
                match_.result = MatchResult.Draw;
                pendingRewards[match_.player1] += match_.poolAmount / 2;
                pendingRewards[match_.player2] += match_.poolAmount / 2;
            }
        } else if (p1Valid && !p2Valid) {
            match_.result = MatchResult.Player1Wins;
            pendingRewards[match_.player1] += match_.poolAmount;
        } else if (p2Valid && !p1Valid) {
            match_.result = MatchResult.Player2Wins;
            pendingRewards[match_.player2] += match_.poolAmount;
        }
        address winner = match_.result == MatchResult.Player1Wins
            ? match_.player1
            : match_.result == MatchResult.Player2Wins
                ? match_.player2
                : address(0);

        // 4. Update Match Phase & Unlock Wallets
        match_.phase = Phase.Completed;
        cardToken.setTransferLock(match_.player1, false);
        cardToken.setTransferLock(match_.player2, false);
        delete playerEntries[match_.player1];
        delete playerEntries[match_.player2];

        emit MatchResolved(
            matchId,
            match_.result,
            winner,
            p1TotalScore,
            p2TotalScore,
            p1RoundScores,
            p2RoundScores
        );
    }

    function _verifyDeckIntegrity(
        uint256 matchId,
        uint256[] memory p1r1,
        uint256[] memory p1r2,
        uint256[] memory p1r3,
        uint256[] memory p2r1,
        uint256[] memory p2r2,
        uint256[] memory p2r3
    )
        internal
        view
        returns (
            bool p1Valid,
            bool p2Valid,
            uint256[] memory p1RemainingDeck,
            uint256[] memory p2RemainingDeck,
            uint256[6] memory neutrals
        )
    {
        Match storage m = matches[matchId];
        (uint256[] memory p1Ids, uint256[] memory p1Amounts) = _unpackDeck(
            m.player1
        );
        (uint256[] memory p2Ids, uint256[] memory p2Amounts) = _unpackDeck(
            m.player2
        );
        uint256[3] memory p1Neutrals;
        uint256[3] memory p2Neutrals;

        (p1Valid, p1RemainingDeck, p1Neutrals) = _checkPlayerIntegrity(
            p1Ids,
            p1Amounts,
            p1r1,
            p1r2,
            p1r3
        );
        (p2Valid, p2RemainingDeck, p2Neutrals) = _checkPlayerIntegrity(
            p2Ids,
            p2Amounts,
            p2r1,
            p2r2,
            p2r3
        );

        neutrals[0] = p1Neutrals[0];
        neutrals[1] = p2Neutrals[0];
        neutrals[2] = p1Neutrals[1];
        neutrals[3] = p2Neutrals[1];
        neutrals[4] = p1Neutrals[2];
        neutrals[5] = p2Neutrals[2];

        if (p1Valid) {
            uint256 p1Total = _calculateTotalCardsInRound(p1r1) +
                _calculateTotalCardsInRound(p1r2) +
                _calculateTotalCardsInRound(p1r3);
            if (p1Total > MAX_TOTAL_CARDS) p1Valid = false;
        }

        if (p2Valid) {
            uint256 p2Total = _calculateTotalCardsInRound(p2r1) +
                _calculateTotalCardsInRound(p2r2) +
                _calculateTotalCardsInRound(p2r3);
            if (p2Total > MAX_TOTAL_CARDS) p2Valid = false;
        }
    }

    function _checkPlayerIntegrity(
        uint256[] memory originalIds,
        uint256[] memory originalAmounts,
        uint256[] memory r1Packed,
        uint256[] memory r2Packed,
        uint256[] memory r3Packed
    )
        internal
        pure
        returns (
            bool isValid,
            uint256[] memory availability,
            uint256[3] memory neutrals
        )
    {
        availability = new uint256[](145);
        for (uint256 i = 0; i < originalIds.length; i++) {
            availability[originalIds[i]] = originalAmounts[i];
        }

        (isValid, neutrals[0]) = _verifyRound(r1Packed, availability);
        if (!isValid) return (false, availability, neutrals);

        (isValid, neutrals[1]) = _verifyRound(r2Packed, availability);
        if (!isValid) return (false, availability, neutrals);

        (isValid, neutrals[2]) = _verifyRound(r3Packed, availability);
        if (!isValid) return (false, availability, neutrals);

        return (true, availability, neutrals);
    }

    function _verifyRound(
        uint256[] memory packedArray,
        uint256[] memory availability
    ) internal pure returns (bool isValid, uint256 neutralPacked) {
        uint256 neutralCount = 0;
        for (uint256 i = 0; i < packedArray.length; i++) {
            uint256 packed = packedArray[i];
            uint256 cleanId = packed & 0xFFFF;
            uint256 amount = (packed >> 32) & 0xFFFF > 0
                ? (packed >> 32) & 0xFFFF
                : 1;

            if (cleanId == 0 || cleanId > 144) return (false, 0);
            if (availability[cleanId] < amount) return (false, 0);
            unchecked {
                availability[cleanId] -= amount;
            }

            if (cleanId >= 136 && cleanId <= 144) {
                neutralCount += amount;
                if (neutralCount > 1) return (false, 0);
                neutralPacked = packed;
            }
        }
        return (true, neutralPacked);
    }

    function _packRoundData(
        uint256 matchId,
        bool isPlayer1,
        uint256[] calldata r1,
        uint256[] calldata r2,
        uint256[] calldata r3
    ) internal {
        Match storage m = matches[matchId];
        uint256[] storage target = isPlayer1
            ? m.player1PackedRounds
            : m.player2PackedRounds;

        uint256 shift = isPlayer1 ? 0 : 24;
        uint256 mask = uint256(0xFFFFFF) << shift;
        uint256 l1 = r1.length > 255 ? 255 : r1.length;
        uint256 l2 = r2.length > 255 ? 255 : r2.length;
        uint256 l3 = r3.length > 255 ? 255 : r3.length;

        m.roundLengths =
            (m.roundLengths & ~mask) |
            ((l1 | (l2 << 8) | (l3 << 16)) << shift);

        uint256 total = r1.length + r2.length + r3.length;
        uint256 currentPacked = 0;
        uint256 countInSlot = 0;

        for (uint256 i = 0; i < total; ) {
            uint256 card;
            if (i < r1.length) card = r1[i];
            else if (i < r1.length + r2.length) card = r2[i - r1.length];
            else card = r3[i - r1.length - r2.length];

            currentPacked |=
                (card & 0xFFFFFFFFFFFFFFFFFFFF) <<
                (countInSlot * 80);
            countInSlot++;

            if (countInSlot == 3 || i == total - 1) {
                target.push(currentPacked);
                currentPacked = 0;
                countInSlot = 0;
            }
            unchecked {
                i++;
            }
        }
    }

    function _unpackRound(
        uint256 matchId,
        bool isPlayer1,
        uint8 roundNum
    ) internal view returns (uint256[] memory) {
        Match storage m = matches[matchId];
        uint256[] storage packed = isPlayer1
            ? m.player1PackedRounds
            : m.player2PackedRounds;
        uint256 shift = (isPlayer1 ? 0 : 24) + (roundNum * 8);
        uint256 len = (m.roundLengths >> shift) & 0xFF;

        uint256[] memory result = new uint256[](len);
        if (len == 0) return result;

        uint256 cardsBefore = 0;
        uint256 baseShift = isPlayer1 ? 0 : 24;
        for (uint8 r = 0; r < roundNum; r++) {
            cardsBefore += (m.roundLengths >> (baseShift + (r * 8))) & 0xFF;
        }

        for (uint256 i = 0; i < len; ) {
            uint256 globalIdx = cardsBefore + i;
            uint256 slotIdx = globalIdx / 3;
            uint256 subIdx = globalIdx % 3;

            result[i] =
                (packed[slotIdx] >> (subIdx * 80)) &
                0xFFFFFFFFFFFFFFFFFFFF;
            unchecked {
                i++;
            }
        }
        return result;
    }

    function _calculateTotalCardsInRound(
        uint256[] memory packedArray
    ) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < packedArray.length; i++) {
            total += (packedArray[i] >> 32) & 0xFFFF;
        }
        return total;
    }

    function encodeCard(
        uint16 cardId,
        uint16 amount,
        uint8 targetRow,
        uint8 choice,
        uint256 spy1_Or_medic,
        uint256 spy2
    ) public pure returns (uint256) {
        if (cardId > 144) revert GwentArena__InvalidCardId();
        if (targetRow > 2) revert GwentArena__InvalidTargetRow();
        return
            uint256(cardId) |
            (uint256(targetRow) << 16) |
            (uint256(choice) << 24) |
            (uint256(amount) << 32) |
            ((spy1_Or_medic & 0xFFFF) << 48) |
            ((spy2 & 0xFFFF) << 64);
    }

    function timeoutCommit(uint256 matchId) external {
        Match storage match_ = matches[matchId];
        if (match_.phase != Phase.WaitingForCommit)
            revert GwentArena__InvalidPhase();
        if (block.timestamp <= match_.commitDeadline)
            revert GwentArena__DeadlineNotPassed();

        bool p1Committed = match_.player1CombinedHash != bytes32(0);
        bool p2Committed = match_.player2CombinedHash != bytes32(0);

        uint256 callerReward = (match_.poolAmount * callerRewardPercent) / 100;
        uint256 remainingPool = match_.poolAmount - callerReward;

        if (!p1Committed && !p2Committed) {
            match_.result = MatchResult.BothTimeout;
            pendingRewards[match_.player1] += remainingPool / 2;
            pendingRewards[match_.player2] += remainingPool / 2;
        } else if (p1Committed && !p2Committed) {
            match_.result = MatchResult.Player2Timeout;
            pendingRewards[match_.player1] += remainingPool;
        } else if (!p1Committed && p2Committed) {
            match_.result = MatchResult.Player1Timeout;
            pendingRewards[match_.player2] += remainingPool;
        }

        match_.phase = Phase.Completed;

        cardToken.setTransferLock(match_.player1, false);
        cardToken.setTransferLock(match_.player2, false);

        if (callerReward > 0) {
            cardToken.mintGameCurrency(msg.sender, callerReward);
        }

        emit TimeoutResolved(matchId, match_.result);
    }

    function timeoutReveal(uint256 matchId) external {
        Match storage match_ = matches[matchId];
        if (match_.phase != Phase.WaitingForReveal) revert GwentArena__InvalidPhase();
        if (block.timestamp <= match_.revealDeadline) revert GwentArena__DeadlineNotPassed();

        bool p1Revealed = match_.player1PackedRounds.length > 0;
        bool p2Revealed = match_.player2PackedRounds.length > 0;

        uint256 callerReward = (match_.poolAmount * callerRewardPercent) / 100;
        uint256 remainingPool = match_.poolAmount - callerReward;

        if (!p1Revealed && !p2Revealed) {
            match_.result = MatchResult.BothTimeout;
            pendingRewards[match_.player1] += remainingPool / 2;
            pendingRewards[match_.player2] += remainingPool / 2;
        } else if (p1Revealed && !p2Revealed) {
            match_.result = MatchResult.Player2Timeout;
            pendingRewards[match_.player1] += remainingPool;
        } else if (!p1Revealed && p2Revealed) {
            match_.result = MatchResult.Player1Timeout;
            pendingRewards[match_.player2] += remainingPool;
        }

        match_.phase = Phase.Completed;

        cardToken.setTransferLock(match_.player1, false);
        cardToken.setTransferLock(match_.player2, false);

        if (callerReward > 0) {
            cardToken.mintGameCurrency(msg.sender, callerReward);
        }

        emit TimeoutResolved(matchId, match_.result);
    }

    function claimPendingBalance() external nonReentrant {
        uint256 reward = pendingRewards[msg.sender];
        pendingRewards[msg.sender] = 0;

        if (reward == 0) revert GwentArena__NoRewardsToClaim();
        cardToken.mintGameCurrency(msg.sender, reward);

        // Cleanup status so player can enter the arena again
        if (playerEntries[msg.sender].isMatched) {
            delete playerEntries[msg.sender];
        }

        emit RewardsClaimed(msg.sender, reward);
    }

    function claimFees() external virtual onlyRole(OWNER_ROLE) nonReentrant {
        uint256 fees = pendingFees;
        if (fees == 0) revert GwentArena__NoFeesToClaim();
        pendingFees = 0;
        cardToken.mintGameCurrency(treasury, fees);
    }


    function cancelEntry() external nonReentrant {
        ArenaEntry storage entry = playerEntries[msg.sender];
        if (entry.enterBlock == 0) revert GwentArena__NotInArena();
        if (entry.isMatched) revert GwentArena__AlreadyMatched();

        cardToken.setTransferLock(msg.sender, false);
        cardToken.mintGameCurrency(msg.sender, entry.stakeAmount);

        uint256 qIdx = entry.queueIndex;
        if (qIdx < waitingQueue.length && waitingQueue[qIdx] == msg.sender) {
            waitingQueue[qIdx] = address(0);

            if (qIdx == waitingHead) {
                while (
                    waitingHead < waitingQueue.length &&
                    waitingQueue[waitingHead] == address(0)
                ) {
                    waitingHead++;
                }
            }
        }
        delete playerEntries[msg.sender];
        emit EntryCancelled(msg.sender);
    }

    function getMatchInfo(
        uint256 matchId
    ) external view returns (MatchInfo memory) {
        Match storage match_ = matches[matchId];
        (uint256[] memory p1Ids, uint256[] memory p1Amounts) = _unpackDeck(
            match_.player1
        );
        (uint256[] memory p2Ids, uint256[] memory p2Amounts) = _unpackDeck(
            match_.player2
        );

        return
            MatchInfo({
                player1: match_.player1,
                player2: match_.player2,
                deck1Packed: p1Ids,
                deck1Amounts: p1Amounts,
                deck2Packed: p2Ids,
                deck2Amounts: p2Amounts,
                phase: match_.phase,
                commitDeadline: match_.commitDeadline,
                revealDeadline: match_.revealDeadline,
                result: match_.result,
                revealed1: match_.revealed1,
                revealed2: match_.revealed2,
                poolAmount: match_.poolAmount
            });
    }

    function getPlayerEntry(
        address player
    )
        external
        view
        returns (
            Faction faction,
            uint256 stake,
            uint256 enterBlock,
            bool isMatched,
            uint256 latestMatchId
        )
    {
        ArenaEntry storage entry = playerEntries[player];
        uint256 mId = entry.matchIds.length > 0
            ? entry.matchIds[entry.matchIds.length - 1]
            : 0;
        return (
            entry.faction,
            entry.stakeAmount,
            entry.enterBlock,
            entry.isMatched,
            mId
        );
    }

    function getFullPlayerEntry(
        address player
    ) external view returns (ArenaEntry memory) {
        return playerEntries[player];
    }

    // ============================================
    // Chainlink Automation Interface
    // ============================================

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 resHead = resolutionHead;
        while (resHead < resolutionQueue.length) {
            uint256 mId = resolutionQueue[resHead];
            if (
                mId != type(uint256).max &&
                matches[mId].phase == Phase.WaitingForResolution
            ) {
                return (
                    true,
                    abi.encode(uint8(1), address(0), address(0), mId, resHead)
                );
            }
            resHead++;
        }

        uint256 waitHead = waitingHead;
        address player1;
        uint256 idx1;

        while (waitHead < waitingQueue.length) {
            address p = waitingQueue[waitHead];
            if (
                p == address(0) ||
                playerEntries[p].isMatched ||
                playerEntries[p].enterBlock == 0
            ) {
                waitHead++;
                continue;
            }

            if (player1 == address(0)) {
                player1 = p;
                idx1 = waitHead;
                waitHead++;
            } else {
                return (true, abi.encode(uint8(0), player1, p, idx1, waitHead));
            }
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        (uint8 upkeepType, address p1, address p2, uint256 v1, uint256 v2) = abi
            .decode(performData, (uint8, address, address, uint256, uint256));

        if (upkeepType == 0) {
            _processMatchAndRewards(p1, p2, v1, v2);
            if (v2 >= waitingHead) {
                waitingHead = v2 + 1;
            }
        } else {
            _processResolution(v1, v2);
            if (v2 >= resolutionHead) {
                resolutionHead = v2 + 1;
            }
        }
    }

    function _processResolution(uint256 matchId, uint256 resIndex) internal {
        Match storage m = matches[matchId];
        if (m.phase == Phase.WaitingForResolution) {
            _resolveMatch(matchId);
            resolutionQueue[resIndex] = type(uint256).max;
        }
    }

    function _processMatchAndRewards(
        address player1,
        address player2,
        uint256 idx1,
        uint256 idx2
    ) internal returns (bool success) {
        if (
            playerEntries[player1].isMatched || playerEntries[player2].isMatched
        ) return false;
        if (
            playerEntries[player1].enterBlock == 0 ||
            playerEntries[player2].enterBlock == 0
        ) return false;
        if (waitingQueue[idx1] != player1 || waitingQueue[idx2] != player2)
            return false;

        ArenaEntry storage entry1 = playerEntries[player1];
        ArenaEntry storage entry2 = playerEntries[player2];

        waitingQueue[idx1] = address(0);
        waitingQueue[idx2] = address(0);

        uint256 reward1 = _calculateWaitReward(entry1.enterBlock);
        if (reward1 > 0) pendingRewards[player1] += reward1;

        uint256 reward2 = _calculateWaitReward(entry2.enterBlock);
        if (reward2 > 0) pendingRewards[player2] += reward2;

        _createMatch(player1, player2);

        playerEntries[player1].enterBlock = 0;
        playerEntries[player2].enterBlock = 0;
        playerEntries[player1].isMatched = true;
        playerEntries[player2].isMatched = true;
        return true;
    }


    /**
     * @notice Scans the matches for ongoing battles (not completed).
     * @param offset The matchId to start scanning from.
     * @param limit The maximum number of matches to return.
     */
    function getActiveMatches(
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory activeIds) {
        uint256 total = matchCount;
        if (offset >= total) return new uint256[](0);

        uint256 maxScan = offset + 1000; // Safety limit to prevent timeouts
        if (maxScan > total) maxScan = total;

        uint256[] memory temp = new uint256[](limit);
        uint256 count = 0;

        for (uint256 i = offset; i < maxScan && count < limit; i++) {
            if (matches[i].phase != Phase.Completed) {
                temp[count] = i;
                count++;
            }
        }

        activeIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            activeIds[i] = temp[i];
        }
        return activeIds;
    }

    function calculateFinalPower_External(
        uint256 pVal,
        uint256 rVal,
        uint256 mBoost,
        uint256 mardroeme,
        uint256 cHorn,
        uint256 tVal
    ) public pure returns (uint256) {
        return
            CardGameLogic.calculateFinalPower(
                pVal,
                rVal,
                mBoost,
                mardroeme,
                cHorn,
                tVal
            );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155ReceiverUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
