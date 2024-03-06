// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { BaseGuard } from "@gnosis.pm/zodiac/contracts/guard/BaseGuard.sol";
import { FactoryFriendly } from "@gnosis.pm/zodiac/contracts/factory/FactoryFriendly.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

import { ScopeGuard } from "./ScopeGuard.sol";
import { EmergencySystem } from "../EmergencySystem.sol";
import { IImmunefiGuardEvents } from "../events/IImmunefiGuardEvents.sol";

/**
 * @title ImmunefiGuard
 * @author Immunefi
 * @notice A guard to be attached to Safe Contracts.
 * @dev Logic is rendered useless if there's an emergency shutdown
 */
contract ImmunefiGuard is ScopeGuard, IImmunefiGuardEvents {
    EmergencySystem public immutable emergencySystem;
    mapping(address => bool) public guardBypassers;

    constructor(address _emergencySystem) {
        emergencySystem = EmergencySystem(_emergencySystem);
    }

    /**
     * @notice Sets whether or not a caller is allowed to bypass guard logic.
     * @param caller Address to be allowed/disallowed.
     * @param allow Bool to allow (true) or disallow (false) calls by caller.
     */
    function setGuardBypasser(address caller, bool allow) public onlyOwner {
        guardBypassers[caller] = allow;
        emit SetGuardBypasser(caller, allow);
    }

    /**
     * @notice Checks a transaction before execution.
     * @param to Destination address of vault transaction.
     * @param value Ether value of vault transaction.
     * @param data Data payload of vault transaction.
     * @param operation Operation type for avatar execution.
     * @param safeTxGas Gas to be used for avatar execution.
     * @param baseGas Gas to be used for avatar execution.
     * @param gasPrice Gas price to be used for avatar execution.
     * @param gasToken Gas token to be used for avatar execution.
     * @param refundReceiver Address to receive gas payment for avatar execution.
     * @param signatures Signatures for avatar execution.
     * @param msgSender Address of the sender of the transaction.
     */
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) public view override {
        // if the system is shutdown, guard logic is detached
        // project can use as a vanilla safe
        if (emergencySystem.emergencyShutdownActive()) {
            return;
        }

        if (guardBypassers[msgSender]) {
            return;
        }

        super.checkTransaction(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            signatures,
            msgSender
        );
    }
}
