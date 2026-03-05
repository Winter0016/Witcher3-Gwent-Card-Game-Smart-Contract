# Chainlink Automation Matchmaking Design 

## Objective
To implement an automated, gas-efficient matchmaking system for the `GwentArena.sol` smart contract using Chainlink Keepers (AutomationCompatibleInterface). This ensures `player2` doesn't have to foot the gas bill for match creation.

## Match Struct Storage Optimization
Previously, the `Match` struct contained `uint256[] deckIds` and `uint256[] deckAmounts` for both players. This resulted in extremely high gas costs due to array copies into storage during `_createMatch`. 

We have optimized this by removing these duplicate arrays from the `Match` struct entirely. Decks are now exclusively stored in the `playerEntries` mapping under the `ArenaEntry` struct, acting as highly efficient **Storage Pointers**.
* **Impact**: `_createMatch` is now incredibly lightweight.
* **Impact**: Functions like `claimCards` and `getMatchInfo` simply pull the `playerEntries[player1].cardIds` and `playerEntries[player1].cardAmounts`.

## Chainlink `checkUpkeep` Logic
`checkUpkeep` is called entirely off-chain by the node, meaning computationally heavy loops are essentially free. 

The strategy is:
1. Loop through the `Faction` enum (`Northern`, `Nilfgaard`, etc.) to find queues with `>= 2` players.
2. Ensure the players in the queue haven't already been matched since entering.
3. If two unmatched players are found in the same faction queue, return `upkeepNeeded = true`.
4. Pack the two addresses into the `performData` payload using `abi.encode(player1, player2)`.

## Chainlink `performUpkeep` Logic
`performUpkeep` is executed on-chain, utilizing LINK tokens for gas. 

The strategy is:
1. Accept the `performData` from `checkUpkeep` and immediately unpack it using `abi.decode(performData, (address, address))`.
2. Retrieve `entry1` and `entry2` from `playerEntries`.
3. Verify `!entry1.isMatched` and `!entry2.isMatched` for security.
4. Execute `_createMatch(player1, player2)`.

## Why this works so well
Using `performData` restricts all expensive "searching" computations to the off-chain environment. The on-chain `performUpkeep` pays almost nothing, creating instantaneous matches seamlessly!
