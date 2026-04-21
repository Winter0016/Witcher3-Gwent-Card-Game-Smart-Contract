//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {GwentSystem} from "../../../src/GwentSystem.sol";

contract GwentSystemVersion2 is GwentSystem {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address vrfCoordinator) GwentSystem(vrfCoordinator) {
        _disableInitializers();
    }

    function version() external pure virtual override returns (uint256) {
        return 2;
    }
}
