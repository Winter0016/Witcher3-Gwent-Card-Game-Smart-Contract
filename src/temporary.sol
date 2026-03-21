 // function _AbilityProcess(
//     uint16 id,
//     CardRegistryPure.Card memory card,
//     uint16 amount,
//     CardRegistryPure.Ability Decoy,
//     CardRegistryPure.Ability Scorch,
//     uint256[] memory remaining,
//     uint256 spy1,
//     uint256 spy2
// )
//     internal
//     pure
//     returns (
//         uint256 power_update,
//         uint256 rowcount_update,
//         uint256 commander_horn,
//         uint256 morale_boost,
//         uint256 mardroeme,
//         uint256 spy,
//         uint256[] memory remaining_update
//     )
// {
//     if (card.ability == Scorch && card.ability != Decoy) {
//         if (card.ability == CardRegistryPure.Ability.Spy) {
//             spy += amount;
//         } else {
//             power_update += card.power * amount;
//             rowcount_update += amount;
//         }
//     } else {
//         if (card.ability == CardRegistryPure.Ability.Hero) {
//             power_update += card.power * amount;
//         } else if (card.ability == CardRegistryPure.Ability.Tight_Bond) {
//             power_update += amount * card.power * 2;
//             rowcount_update += amount;
//         } else if (card.ability == CardRegistryPure.Ability.Morale_Boost) {
//             power_update += card.power * amount;
//             morale_boost += amount;
//             rowcount_update += amount;
//         } else if (card.ability == CardRegistryPure.Ability.Spy) {
//             spy += amount;
//             if (spy1 > 0) {
//                 (, CardRegistryPure.Card memory card, , , , , ) = unpack(spy1);
//                 power_update += card.power * amount;
//                 rowcount_update += amount;
//                 remaining[spy1] -= amount;
//             }
//             if (spy2 > 0) {
//                 (, CardRegistryPure.Card memory card, , , , , ) = unpack(spy2);
//                 power_update += card.power * amount;
//                 rowcount_update += amount;
//                 remaining[spy2] -= amount;
//             }
//         } else if (card.ability == CardRegistryPure.Ability.Commander_horn) {
//             commander_horn += 1;
//         } else if (card.ability == CardRegistryPure.Ability.Medic) {
//             power_update += card.power * amount;
//             if (spy1 > 0) {
//                 (, CardRegistryPure.Card memory card, , , , , ) = unpack(spy1);
//                 power_update += card.power * amount;
//                 rowcount_update += amount;
//                 remaining[spy1] -= amount;
//             }
//         } else if (card.ability == CardRegistryPure.Ability.Muster) {
//             uint256 packedM = CardRegistryPure.getMusterMembersByID(id);
//             uint256 countM = packedM & 0xFF;
//             for (uint256 j = 0; j < countM; j++) {
//                 uint16 mId = uint16((packedM >> (8 + j * 16)) & 0xFFFF);
//                 uint16 mAmount = uint16(remaining[mId]);
//                 amount += mAmount;
//                 remaining[mId] -= mAmount;
//             }
//             power_update += card.power * amount;
//             rowcount_update += amount;
//         } else if (card.ability == CardRegistryPure.Ability.Summon) {
//             power_update += amount * card.power;
//             uint256 packedM = CardRegistryPure.getMusterMembersByID(id);
//             uint256 countM = packedM & 0xFF;
//             for (uint256 j = 0; j < countM; j++) {
//                 uint16 mId = uint16((packedM >> (8 + j * 16)) & 0xFFFF);
//                 uint16 mAmount = uint16(remaining[mId]);
//                 amount += mAmount;
//                 remaining[mId] -= mAmount;
//                 power_update += mAmount * card.power * 2;
//             }
//             rowcount_update += amount;
//         } else if (card.ability == CardRegistryPure.Ability.Mardroeme) {
//             power_update += card.power * amount;
//             rowcount_update += amount;
//             mardroeme += amount;
//         } else if (
//             card.ability == CardRegistryPure.Ability.Transform_After_Death
//         ) {
//             //
//         } else if (card.ability == CardRegistryPure.Ability.Berserker) {
//             power_update += card.power * amount;
//             rowcount_update += amount;
//             power_update +=
//                 ((card.berserker_power * amount) - (card.power * amount)) <<
//                 24;
//         }
//     }
//     remaining_update = remaining;
// }
