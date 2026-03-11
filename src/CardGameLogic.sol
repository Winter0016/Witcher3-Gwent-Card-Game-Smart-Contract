// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CardRegistryPure} from "./CardRegistryPure.sol";
import {Match} from "./GwentTypes.sol";

library CardGameLogic {
    struct RowState {
        uint16[] ids;
        uint256[] amounts;
        bool hasSpecial; // For "Max 1 Special per row" validation
        uint256 moraleCount;
    }

    struct GlobalWeather {
        bool bitingFrost;
        bool impenetrableFog;
        bool torrentialRain;
        bool skelligeStorm;
    }

    struct BoardState {
        RowState close;
        RowState ranged;
        RowState siege;
        bool isInvalid; // Flag for placement violations
    }
    /// @notice Decodes the target row for a card, respecting Agile/Special flexibility.
    /// @param packedCard The raw packed integer from the user `(row << 32) | (amount << 16) | id`.
    /// @param card The card data from the registry.
    /// @return rowIndex The validated target row index (0=Close, 1=Ranged, 2=Siege).
    function getTargetRow(
        uint256 packedCard,
        CardRegistryPure.Card memory card
    ) public pure returns (uint8 rowIndex) {
        uint8 encodedRow = uint8((packedCard >> 32) & 0x03);

        // NOTE: If packedCard has no high bits (user just passed the card ID),
        // encodedRow will be 0, defaulting all flexible cards to Close Combat.

        // 1. Check if card is Agile (Close or Ranged only)
        if (card.unitType == CardRegistryPure.UnitType.Agile) {
            // Agile units only respect Row 0 (Close) or Row 1 (Ranged)
            return (encodedRow == 1) ? 1 : 0;
        }

        // 2. Check if card is Special (Full flexible)
        if (card.unitType == CardRegistryPure.UnitType.Special) {
            // Commander's Horn/Mardroeme can be placed in any of the 3 rows
            return encodedRow > 2 ? 0 : encodedRow;
        }

        // 2. Fixed row units ignore the encoding bits
        if (card.unitType == CardRegistryPure.UnitType.Close_Combat) return 0;
        if (card.unitType == CardRegistryPure.UnitType.Ranged) return 1;
        if (card.unitType == CardRegistryPure.UnitType.Siege) return 2;

        // Default fallback (e.g. Weather or unknown types)
        return 0;
    }

    function FindWinner(Match memory match_) external pure returns (uint8) {}
}
