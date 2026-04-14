// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract GwentTimeLock is TimelockController {
    /**
     * @param minDelay: Initial minimum delay in seconds for operations
     * @param proposers: Accounts, roles or contracts that can propose operations
     * @param executors: Accounts, roles or contracts that can execute operations
     * @param admin: Optional admin of the timelock
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
