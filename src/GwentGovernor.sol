// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    Governor
} from "openzeppelin-contracts/contracts/governance/Governor.sol";
import {
    GovernorCountingSimple
} from "openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import {
    GovernorSettings
} from "openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import {
    GovernorTimelockControl
} from "openzeppelin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";
import {
    GovernorVotes
} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {
    IVotes
} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {
    TimelockController
} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {
    AccessControlEnumerable
} from "openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

/**
 * @title GwentGovernor
 * @dev Main governance contract for the Decentralized Gwent Protocol.
 * 
 * NOTE ON INHERITANCE: Solidity uses "C3 Linearization" (Right-to-Left priority).
 * We place 'GovernorTimelockControl' on the right so it overrides the base 'Governor' 
 * logic for specialized Timelock behavior (like the cancellation bridge).
 */
contract GwentGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    AccessControlEnumerable
{
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // Veto tracking: proposalId => guardian => hasVoted
    mapping(uint256 => mapping(address => bool)) public guardianVetoed;
    // Veto count: proposalId => number of guardians who voted to veto
    mapping(uint256 => uint256) public vetoTally;

    event VetoCast(
        uint256 indexed proposalId,
        address indexed guardian,
        uint256 currentTally,
        uint256 totalNeeded
    );
    /// @dev Basis points for the veto threshold (e.g., 66 = 66% of guardians)
    uint256 private s_vetoThresholdPercentage = 66;

    event VetoThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    constructor(
        IVotes _token,
        TimelockController _timelock,
        address _initialGuardian
    )
        Governor("GwentGovernor")
        GovernorSettings(
            7200, // 1 day voting delay
            50400, // 1 week voting period
            10 ether // 1% of our initial test supply (1000 ether)
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _initialGuardian);
        _grantRole(GUARDIAN_ROLE, _initialGuardian);
    }

    // ============================================
    // Overrides required by Solidity
    // ============================================

    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(
        uint256 blockNumber
    )
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return
            super._queueOperations(
                proposalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    /**
     * @dev Resolves inheritance ambiguity between Governor and GovernorTimelockControl.
     * Required by the Solidity compiler to satisfy the multiple inheritance "Diamond Problem".
     * 
     * EXECUTION ORDER:
     * 1. This function triggers super._cancel.
     * 2. Because of C3 Linearization, it first enters GovernorTimelockControl._cancel.
     * 3. GovernorTimelockControl then calls its own super._cancel, which runs the base Governor code.
     * 4. After the base Governor updates the state, the execution returns to GovernorTimelockControl
     *    to perform the final Timelock cancellation.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev Resolves inheritance ambiguity between Governor and GovernorTimelockControl.
     * Directs execution authority to the linked Timelock Controller.
     */
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    /**
     * @dev Resolves inheritance ambiguity across all parent contracts.
     * Required by Solidity to correctly expose supported interface IDs for ERC165.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, AccessControlEnumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Guardian Veto: Guardians call this to vote to cancel a proposal.
     * Cancelation happens when the number of vetos meets the s_vetoThresholdPercentage (default 66%).
     */
    function castVeto(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public onlyRole(GUARDIAN_ROLE) {
        uint256 proposalId = getProposalId(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        if (guardianVetoed[proposalId][msg.sender]) {
            revert("Guardian already vetoed");
        }

        guardianVetoed[proposalId][msg.sender] = true;
        vetoTally[proposalId]++;

        uint256 totalGuardians = getRoleMemberCount(GUARDIAN_ROLE);
        emit VetoCast(
            proposalId,
            msg.sender,
            vetoTally[proposalId],
            totalGuardians
        );

        // Check if the threshold (e.g. 66%) has been met
        // Uses integer math: tally * 100 >= total * percentage
        if (
            totalGuardians > 0 &&
            (vetoTally[proposalId] * 100) >= (totalGuardians * s_vetoThresholdPercentage)
        ) {
            _cancel(targets, values, calldatas, descriptionHash);
        }
    }

    /**
     * @dev Updates the percentage of guardians required to veto a proposal.
     * Only callable by the DAO (Timelock).
     */
    function updateVetoThreshold(uint256 newThreshold) external onlyGovernance {
        if (newThreshold == 0 || newThreshold > 100) revert("Invalid threshold");
        uint256 oldThreshold = s_vetoThresholdPercentage;
        s_vetoThresholdPercentage = newThreshold;
        emit VetoThresholdUpdated(oldThreshold, newThreshold);
    }

    function getVetoThreshold() external view returns (uint256) {
        return s_vetoThresholdPercentage;
    }
}
