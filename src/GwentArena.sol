// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGwentCardToken} from "../interfaces/IGwentCardToken.sol";
import {CardRegistryPure} from "./CardRegistryPure.sol";
import {
    ERC1155Holder
} from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {
    AutomationCompatibleInterface
} from "chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract GwentArena is ERC1155Holder, AutomationCompatibleInterface {
    enum Faction {
        Northern,
        Nilfgaard,
        Monster,
        Scoiatael,
        Skellige
    }

    enum Phase {
        WaitingForCommit,
        WaitingForReveal,
        WaitingForResolution,
        Completed
    }

    enum MatchResult {
        Pending,
        Player1Wins,
        Player2Wins,
        Draw,
        Player1Timeout,
        Player2Timeout,
        BothTimeout
    }

    struct ArenaEntry {
        address player;
        Faction faction;
        uint256[] cardIds;
        uint256[] cardAmounts;
        uint256 stakeAmount;
        uint256 enterTime;
        uint256 waitReward;
        uint256[] matchIds;
        bool isMatched;
    }

    struct Match {
        address player1;
        address player2;
        Faction faction1;
        Faction faction2;
        bytes32 player1R1Hash;
        bytes32 player1R2Hash;
        bytes32 player1R3Hash;
        bytes32 player2R1Hash;
        bytes32 player2R2Hash;
        bytes32 player2R3Hash;
        uint256[] player1R1Ids;
        uint256[] player1R1Amounts;
        uint256[] player1R2Ids;
        uint256[] player1R2Amounts;
        uint256[] player1R3Ids;
        uint256[] player1R3Amounts;
        uint256[] player2R1Ids;
        uint256[] player2R1Amounts;
        uint256[] player2R2Ids;
        uint256[] player2R2Amounts;
        uint256[] player2R3Ids;
        uint256[] player2R3Amounts;
        uint256 stakeAmount;
        uint256 poolAmount;
        Phase phase;
        uint256 commitDeadline;
        uint256 revealDeadline;
        MatchResult result;
    }

    struct MatchInfo {
        address player1;
        address player2;
        uint256[] deck1Ids;
        uint256[] deck1Amounts;
        uint256[] deck2Ids;
        uint256[] deck2Amounts;
        uint256 stakeAmount;
        Phase phase;
        uint256 commitDeadline;
        uint256 revealDeadline;
        MatchResult result;
    }

    IGwentCardToken public cardToken;
    address public owner;

    uint256 public entryFee = 50 ether;
    uint256 public waitRewardPerBlock = 0.001 ether;
    uint256 public commitTimeout = 3 days;
    uint256 public revealTimeout = 1 days;
    uint256 public callerRewardPercent = 1;
    uint256 public constant MIN_DECK_SIZE = 22;
    uint256 public constant MAX_DECK_SIZE = 30;
    uint256 public constant MIN_ROUND_CARDS = 5;
    uint256 public houseFeePercent = 2;

    mapping(address => ArenaEntry) public playerEntries;
    address[] public waitingQueue;
    mapping(uint256 => Match) public matches;
    uint256 public matchCount;
    uint256[] public resolutionQueue;
    uint256 public waitingHead;
    uint256 public resolutionHead;

    mapping(address => uint256) public pendingRewards;

    event PlayerEntered(
        address indexed player,
        Faction faction,
        uint256[] deck,
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
        address winner
    );
    event RewardsClaimed(address indexed player, uint256 amount);
    event EntryCancelled(address indexed player);
    event TimeoutResolved(uint256 indexed matchId, MatchResult result);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _cardToken) {
        owner = msg.sender;
        cardToken = IGwentCardToken(_cardToken);
    }

    function setEntryFee(uint256 _fee) external onlyOwner {
        entryFee = _fee;
    }

    function setHouseFeePercent(uint256 _percent) external onlyOwner {
        houseFeePercent = _percent;
    }

    function setCallerRewardPercent(uint256 _percent) external onlyOwner {
        callerRewardPercent = _percent;
    }

    function setWaitRewardPerBlock(uint256 _reward) external onlyOwner {
        waitRewardPerBlock = _reward;
    }

    function setCommitTimeout(uint256 _timeout) external onlyOwner {
        commitTimeout = _timeout;
    }

    function setRevealTimeout(uint256 _timeout) external onlyOwner {
        revealTimeout = _timeout;
    }

    function getWaitingPlayers() external view returns (address[] memory) {
        return waitingQueue;
    }

    function getWaitingCount() external view returns (uint256) {
        return waitingQueue.length;
    }

    function getWaitingReward(address player) external view returns (uint256) {
        ArenaEntry storage entry = playerEntries[player];
        if (entry.enterTime == 0 || entry.isMatched) return 0;

        uint256 blocksWaited = block.timestamp - entry.enterTime;
        uint256 timeReward = blocksWaited * waitRewardPerBlock;

        return timeReward;
    }

    function enterArena(
        Faction faction,
        uint256[] calldata cardIds,
        uint256[] calldata cardAmounts
    ) external {
        require(playerEntries[msg.sender].enterTime == 0, "Already in arena");
        require(
            cardIds.length == cardAmounts.length,
            "Ids and amounts mismatch"
        );
        require(
            cardIds.length >= MIN_DECK_SIZE && cardIds.length <= MAX_DECK_SIZE,
            "Invalid deck size"
        );

        require(
            CardRegistryPure.isDeckValidForFaction(
                CardRegistryPure.Faction(uint8(faction)),
                cardIds
            ),
            "Invalid deck for faction"
        );

        uint256 totalCards;
        for (uint256 i = 0; i < cardIds.length; i++) {
            require(cardIds[i] >= 1 && cardIds[i] <= 144, "Invalid card ID");
            require(cardAmounts[i] > 0, "Amount must be > 0");
            totalCards += cardAmounts[i];
        }
        require(
            totalCards >= MIN_DECK_SIZE && totalCards <= MAX_DECK_SIZE,
            "Invalid total cards"
        );

        cardToken.safeBatchTransferFrom(
            msg.sender,
            address(this),
            cardIds,
            cardAmounts,
            ""
        );

        uint256 currencyId = cardToken.GAME_CURRENCY_ID();

        require(
            cardToken.balanceOf(msg.sender, currencyId) >= entryFee,
            "Insufficient balance"
        );
        cardToken.burnGameCurrency(msg.sender, entryFee);

        playerEntries[msg.sender] = ArenaEntry({
            player: msg.sender,
            faction: faction,
            cardIds: cardIds,
            cardAmounts: cardAmounts,
            stakeAmount: entryFee,
            enterTime: block.timestamp,
            waitReward: 0,
            matchIds: new uint256[](0),
            isMatched: false
        });

        waitingQueue.push(msg.sender);

        emit PlayerEntered(msg.sender, faction, cardIds, entryFee);
    }

    // _matchPlayers logic has been moved to Chainlink Automation (checkUpkeep/performUpkeep)

    function _calculateWaitReward(
        uint256 enterTime
    ) internal view returns (uint256) {
        uint256 blocksWaited = block.timestamp - enterTime;
        uint256 timeReward = blocksWaited * waitRewardPerBlock;
        return timeReward;
    }

    function _createMatch(address player1, address player2) internal {
        uint256 matchId = matchCount++;

        ArenaEntry storage entry1 = playerEntries[player1];
        ArenaEntry storage entry2 = playerEntries[player2];

        uint256 pool = entry1.stakeAmount + entry2.stakeAmount;
        uint256 houseFee = (pool * houseFeePercent) / 100;
        uint256 actualPool = pool - houseFee;

        Match storage newMatch = matches[matchId];
        newMatch.player1 = player1;
        newMatch.player2 = player2;
        newMatch.faction1 = entry1.faction;
        newMatch.faction2 = entry2.faction;

        newMatch.stakeAmount = entry1.stakeAmount;
        newMatch.poolAmount = actualPool;
        newMatch.phase = Phase.WaitingForCommit;
        newMatch.commitDeadline = block.timestamp + commitTimeout;
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
            return 0; // Or handle as an error, depending on desired behavior
        }
        return entry.matchIds[entry.matchIds.length - 1];
    }

    function commitPlays(
        uint256 matchId,
        bytes32 r1Hash,
        bytes32 r2Hash,
        bytes32 r3Hash
    ) external {
        Match storage match_ = matches[matchId];
        require(
            msg.sender == match_.player1 || msg.sender == match_.player2,
            "Not player"
        );
        require(match_.phase == Phase.WaitingForCommit, "Not in commit phase");
        require(
            block.timestamp <= match_.commitDeadline,
            "Commit timeout passed"
        );

        bool isPlayer1 = msg.sender == match_.player1;

        if (isPlayer1) {
            require(match_.player1R1Hash == bytes32(0), "Already committed");
            match_.player1R1Hash = r1Hash;
            match_.player1R2Hash = r2Hash;
            match_.player1R3Hash = r3Hash;
        } else {
            require(match_.player2R1Hash == bytes32(0), "Already committed");
            match_.player2R1Hash = r1Hash;
            match_.player2R2Hash = r2Hash;
            match_.player2R3Hash = r3Hash;
        }

        if (
            match_.player1R1Hash != bytes32(0) &&
            match_.player2R1Hash != bytes32(0)
        ) {
            match_.phase = Phase.WaitingForReveal;
            match_.revealDeadline = block.timestamp + revealTimeout;
        }

        emit PlaysCommitted(matchId, msg.sender);
    }

    function revealPlays(
        uint256 matchId,
        uint256[] calldata r1Ids,
        uint256[] calldata r1Amounts,
        uint256[] calldata r2Ids,
        uint256[] calldata r2Amounts,
        uint256[] calldata r3Ids,
        uint256[] calldata r3Amounts,
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

        bytes32 r1Hash = keccak256(abi.encode(r1Ids, r1Amounts, salt));
        bytes32 r2Hash = keccak256(abi.encode(r2Ids, r2Amounts, salt));
        bytes32 r3Hash = keccak256(abi.encode(r3Ids, r3Amounts, salt));

        // Simplified revealPlays for gas efficiency.
        // Rule checks (min 5 cards in R1/R2 and deck integrity)
        // are offloaded to Automated Resolution Phase.

        bool isPlayer1 = msg.sender == match_.player1;

        if (isPlayer1) {
            require(r1Hash == match_.player1R1Hash, "R1 hash mismatch");
            require(r2Hash == match_.player1R2Hash, "R2 hash mismatch");
            require(r3Hash == match_.player1R3Hash, "R3 hash mismatch");
            match_.player1R1Ids = r1Ids;
            match_.player1R1Amounts = r1Amounts;
            match_.player1R2Ids = r2Ids;
            match_.player1R2Amounts = r2Amounts;
            match_.player1R3Ids = r3Ids;
            match_.player1R3Amounts = r3Amounts;
        } else {
            require(r1Hash == match_.player2R1Hash, "R1 hash mismatch");
            require(r2Hash == match_.player2R2Hash, "R2 hash mismatch");
            require(r3Hash == match_.player2R3Hash, "R3 hash mismatch");
            match_.player2R1Ids = r1Ids;
            match_.player2R1Amounts = r1Amounts;
            match_.player2R2Ids = r2Ids;
            match_.player2R2Amounts = r2Amounts;
            match_.player2R3Ids = r3Ids;
            match_.player2R3Amounts = r3Amounts;
        }

        if (match_.player1R1Ids.length > 0 && match_.player2R1Ids.length > 0) {
            match_.phase = Phase.WaitingForResolution;
            resolutionQueue.push(matchId);
        }

        emit PlaysRevealed(matchId, msg.sender);
    }

    function _resolveMatch(uint256 matchId) internal {
        Match storage match_ = matches[matchId];

        // 1. Verify Deck Integrity & Card Rules (Slashing)
        bool p1Valid = _verifyDeckIntegrity(
            match_.player1,
            match_.player1R1Ids,
            match_.player1R1Amounts,
            match_.player1R2Ids,
            match_.player1R2Amounts,
            match_.player1R3Ids,
            match_.player1R3Amounts
        );
        bool p2Valid = _verifyDeckIntegrity(
            match_.player2,
            match_.player2R1Ids,
            match_.player2R1Amounts,
            match_.player2R2Ids,
            match_.player2R2Amounts,
            match_.player2R3Ids,
            match_.player2R3Amounts
        );

        // Rule: Min 5 cards in R1 and R2
        if (
            _calculateScore(match_.player1R1Amounts) < MIN_ROUND_CARDS ||
            _calculateScore(match_.player1R2Amounts) < MIN_ROUND_CARDS
        ) p1Valid = false;
        if (
            _calculateScore(match_.player2R1Amounts) < MIN_ROUND_CARDS ||
            _calculateScore(match_.player2R2Amounts) < MIN_ROUND_CARDS
        ) p2Valid = false;

        uint256 score1 = 0;
        uint256 score2 = 0;

        if (p1Valid) {
            score1 =
                _calculateScore(match_.player1R1Amounts) +
                _calculateScore(match_.player1R2Amounts) +
                _calculateScore(match_.player1R3Amounts);
        }
        if (p2Valid) {
            score2 =
                _calculateScore(match_.player2R1Amounts) +
                _calculateScore(match_.player2R2Amounts) +
                _calculateScore(match_.player2R3Amounts);
        }

        // Special Case: Both Cheated -> System earns everything
        if (!p1Valid && !p2Valid) {
            match_.result = MatchResult.Draw;
            // Send pool to system/owner
            cardToken.mintGameCurrency(owner, match_.poolAmount);
            emit MatchResolved(matchId, MatchResult.Draw, address(0));
            return;
        }

        // Special Case: If only one cheated, the other wins automatically
        // This is naturally handled by score1=0 or score2=0 unless it's a tie at 0
        // But if score1 == score2 and one is invalid, the valid one should win.

        if (p1Valid && !p2Valid) {
            match_.result = MatchResult.Player1Wins;
            pendingRewards[match_.player1] = match_.poolAmount;
        } else if (p2Valid && !p1Valid) {
            match_.result = MatchResult.Player2Wins;
            pendingRewards[match_.player2] = match_.poolAmount;
        } else if (score1 > score2) {
            match_.result = MatchResult.Player1Wins;
            pendingRewards[match_.player1] = match_.poolAmount;
        } else if (score2 > score1) {
            match_.result = MatchResult.Player2Wins;
            pendingRewards[match_.player2] = match_.poolAmount;
        } else {
            match_.result = MatchResult.Draw;
            pendingRewards[match_.player1] = match_.poolAmount / 2;
            pendingRewards[match_.player2] = match_.poolAmount / 2;
        }

        address winner = match_.result == MatchResult.Player1Wins
            ? match_.player1
            : match_.result == MatchResult.Player2Wins
                ? match_.player2
                : address(0);

        emit MatchResolved(matchId, match_.result, winner);
    }

    function _verifyDeckIntegrity(
        address player,
        uint256[] memory r1Ids,
        uint256[] memory r1Amounts,
        uint256[] memory r2Ids,
        uint256[] memory r2Amounts,
        uint256[] memory r3Ids,
        uint256[] memory r3Amounts
    ) internal view returns (bool) {
        ArenaEntry storage entry = playerEntries[player];
        uint256[] storage originalIds = entry.cardIds;
        uint256[] storage originalAmounts = entry.cardAmounts;

        if (r1Ids.length != r1Amounts.length) return false;
        if (r2Ids.length != r2Amounts.length) return false;
        if (r3Ids.length != r3Amounts.length) return false;

        // Use a memory array to track usage. Max ID is 144 based on rules.
        uint256[] memory revealedCounts = new uint256[](145);

        // Fill revealed counts using amounts
        for (uint256 i = 0; i < r1Ids.length; i++) {
            if (r1Ids[i] > 144) return false;
            revealedCounts[r1Ids[i]] += r1Amounts[i];
        }
        for (uint256 i = 0; i < r2Ids.length; i++) {
            if (r2Ids[i] > 144) return false;
            revealedCounts[r2Ids[i]] += r2Amounts[i];
        }
        for (uint256 i = 0; i < r3Ids.length; i++) {
            if (r3Ids[i] > 144) return false;
            revealedCounts[r3Ids[i]] += r3Amounts[i];
        }

        // Verify against original entry
        for (uint256 i = 0; i < originalIds.length; i++) {
            uint256 id = originalIds[i];
            if (revealedCounts[id] > originalAmounts[i]) {
                return false; // Cheated: more cards revealed than owned in entry
            }
            // Clear used counts so we can detect "phantom" cards later
            revealedCounts[id] = 0;
        }

        // Ensure no cards were revealed that WEREN'T in the original deck at all
        for (uint256 i = 0; i < r1Ids.length; i++)
            if (revealedCounts[r1Ids[i]] > 0) return false;
        for (uint256 i = 0; i < r2Ids.length; i++)
            if (revealedCounts[r2Ids[i]] > 0) return false;
        for (uint256 i = 0; i < r3Ids.length; i++)
            if (revealedCounts[r3Ids[i]] > 0) return false;

        return true;
    }

    function _calculateScore(
        uint256[] memory amounts
    ) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }

    function timeoutCommit(uint256 matchId) external {
        Match storage match_ = matches[matchId];
        require(match_.phase == Phase.WaitingForCommit, "Not in commit phase");
        require(block.timestamp > match_.commitDeadline, "Commit still active");

        bool p1Committed = match_.player1R1Hash != bytes32(0);
        bool p2Committed = match_.player2R1Hash != bytes32(0);

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

        if (callerReward > 0) {
            cardToken.mintGameCurrency(msg.sender, callerReward);
        }

        emit TimeoutResolved(matchId, match_.result);
    }

    function timeoutReveal(uint256 matchId) external {
        Match storage match_ = matches[matchId];
        require(match_.phase == Phase.WaitingForReveal, "Not in reveal phase");
        require(block.timestamp > match_.revealDeadline, "Reveal still active");

        bool p1Revealed = match_.player1R1Ids.length > 0;
        bool p2Revealed = match_.player2R1Ids.length > 0;

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

        if (callerReward > 0) {
            cardToken.mintGameCurrency(msg.sender, callerReward);
        }

        emit TimeoutResolved(matchId, match_.result);
    }

    function claimRewards(uint256 matchId) external {
        Match storage match_ = matches[matchId];
        require(
            msg.sender == match_.player1 || msg.sender == match_.player2,
            "Not player"
        );
        require(match_.phase == Phase.Completed, "Match not completed");

        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, "No reward");

        pendingRewards[msg.sender] = 0;
        cardToken.mintGameCurrency(msg.sender, reward);

        // Allow re-entry after claiming results
        ArenaEntry storage entry = playerEntries[msg.sender];
        if (entry.isMatched) {
            entry.enterTime = 0;
            entry.isMatched = false;
        }

        emit RewardsClaimed(msg.sender, reward);
    }

    function cancelEntry() external {
        ArenaEntry storage entry = playerEntries[msg.sender];
        require(entry.enterTime > 0, "Not in arena");
        require(!entry.isMatched, "Already matched");

        uint256 reward = _calculateWaitReward(entry.enterTime);
        if (reward > 0) {
            cardToken.mintGameCurrency(msg.sender, reward);
        }

        cardToken.mintGameCurrency(msg.sender, entry.stakeAmount);

        cardToken.mintBatch(msg.sender, entry.cardIds, entry.cardAmounts, "");

        address[] storage queue = waitingQueue;
        for (uint256 i = 0; i < queue.length; i++) {
            if (queue[i] == msg.sender) {
                queue[i] = address(0);
                break;
            }
        }

        delete playerEntries[msg.sender];

        emit EntryCancelled(msg.sender);
    }

    function claimCards(uint256 matchId) external {
        Match storage match_ = matches[matchId];
        require(
            msg.sender == match_.player1 || msg.sender == match_.player2,
            "Not player"
        );
        require(match_.phase == Phase.Completed, "Match not completed");

        uint256[] storage deckIds = playerEntries[msg.sender].cardIds;
        uint256[] storage deckAmounts = playerEntries[msg.sender].cardAmounts;

        cardToken.mintBatch(msg.sender, deckIds, deckAmounts, "");

        // Allow re-entry after claiming cards
        ArenaEntry storage entry = playerEntries[msg.sender];
        if (entry.isMatched) {
            entry.enterTime = 0;
            entry.isMatched = false;
        }
    }

    function getMatchInfo(
        uint256 matchId
    ) external view returns (MatchInfo memory) {
        Match storage match_ = matches[matchId];
        return
            MatchInfo({
                player1: match_.player1,
                player2: match_.player2,
                deck1Ids: playerEntries[match_.player1].cardIds,
                deck1Amounts: playerEntries[match_.player1].cardAmounts,
                deck2Ids: playerEntries[match_.player2].cardIds,
                deck2Amounts: playerEntries[match_.player2].cardAmounts,
                stakeAmount: match_.stakeAmount,
                phase: match_.phase,
                commitDeadline: match_.commitDeadline,
                revealDeadline: match_.revealDeadline,
                result: match_.result
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
            uint256 enterTime,
            bool isMatched,
            uint256 deckLength,
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
            entry.enterTime,
            entry.isMatched,
            entry.cardIds.length,
            mId
        );
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
        // 1. Check Resolution Queue (Higher Priority)
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

        // 2. Check Matchmaking
        uint256 waitHead = waitingHead;
        address player1;
        uint256 idx1;

        while (waitHead < waitingQueue.length) {
            address p = waitingQueue[waitHead];
            // Skip cancelled/null entries
            if (
                p == address(0) ||
                playerEntries[p].isMatched ||
                playerEntries[p].enterTime == 0
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
            // Matchmaking
            _processMatchAndRewards(p1, p2, v1, v2);
            // Optimization: Update waitingHead to skip processed/null entries
            if (v2 >= waitingHead) {
                waitingHead = v2 + 1;
            }
        } else {
            // Resolution
            _processResolution(v1, v2);
            // Optimization: Update resolutionHead
            if (v2 >= resolutionHead) {
                resolutionHead = v2 + 1;
            }
        }
    }

    function _processResolution(uint256 matchId, uint256 queueIdx) internal {
        Match storage match_ = matches[matchId];
        require(
            match_.phase == Phase.WaitingForResolution,
            "Not waiting for resolution"
        );

        // Remove from queue by swapping with last and popping (standard gas optimization)
        // or just set to a dummy ID if we want to keep it simple like waitingQueue
        // Let's use the same address(0) pattern but with a high number for safety
        if (queueIdx < resolutionQueue.length) {
            // Shift elements or use a pointer?
            // For simplicity and matching waitingQueue pattern:
            resolutionQueue[queueIdx] = type(uint256).max;
        }

        match_.phase = Phase.Completed;
        _resolveMatch(matchId);
    }

    function _processMatchAndRewards(
        address player1,
        address player2,
        uint256 idx1,
        uint256 idx2
    ) internal {
        require(!playerEntries[player1].isMatched, "Player 1 already matched");
        require(!playerEntries[player2].isMatched, "Player 2 already matched");
        require(playerEntries[player1].enterTime > 0, "Player 1 not in arena");
        require(playerEntries[player2].enterTime > 0, "Player 2 not in arena");
        require(waitingQueue[idx1] == player1, "Invalid queue index 1");
        require(waitingQueue[idx2] == player2, "Invalid queue index 2");

        uint256 enterTime1 = playerEntries[player1].enterTime;
        uint256 enterTime2 = playerEntries[player2].enterTime;

        _createMatch(player1, player2);

        playerEntries[player1].isMatched = true;
        playerEntries[player2].isMatched = true;

        waitingQueue[idx1] = address(0);
        waitingQueue[idx2] = address(0);

        uint256 reward1 = _calculateWaitReward(enterTime1);
        if (reward1 > 0) {
            cardToken.mintGameCurrency(player1, reward1);
        }

        uint256 reward2 = _calculateWaitReward(enterTime2);
        if (reward2 > 0) {
            cardToken.mintGameCurrency(player2, reward2);
        }
    }
}
