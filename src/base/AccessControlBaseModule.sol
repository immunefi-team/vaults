// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { IGuard } from "@gnosis.pm/zodiac/contracts/guard/BaseGuard.sol";
import { IAvatar } from "@gnosis.pm/zodiac/contracts/interfaces/IAvatar.sol";
import { AccessControlGuardable } from "./AccessControlGuardable.sol";

/**
 * @title ImmunefiModule
 * @author Immunefi
 * @notice A modified zodiac module that can forward to different avatars
 * @dev Logic is rendered useless if there's an emergency shutdown
 * @dev Access control is dependent on roles and on a guard attached to this module
 */
abstract contract AccessControlBaseModule is AccessControlGuardable {
    /**
     * @notice Passes a transaction to be executed by an avatar.
     * @param target Address of avatar/modifier to execute transaction on.
     * @param to Destination address of module transaction.
     * @param value Ether value of module transaction.
     * @param data Data payload of module transaction.
     * @param operation Operation type for avatar execution.
     */
    function exec(
        address target,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) internal returns (bool success) {
        address currentGuard = guard;
        if (currentGuard != address(0)) {
            IGuard(currentGuard).checkTransaction(
                to,
                value,
                data,
                operation,
                // Zero out the redundant transaction information only used for Safe multisig transactions.
                0,
                0,
                0,
                address(0),
                payable(0),
                bytes("0x"),
                msg.sender
            );
            success = IAvatar(target).execTransactionFromModule(to, value, data, operation);
            IGuard(currentGuard).checkAfterExecution(bytes32("0x"), success);
        } else {
            success = IAvatar(target).execTransactionFromModule(to, value, data, operation);
        }
        return success;
    }

    /**
     * @notice Passes a transaction to be executed by an avatar and returns data.
     * @param target Address of avatar/modifier to execute transaction on.
     * @param to Destination address of module transaction.
     * @param value Ether value of module transaction.
     * @param data Data payload of module transaction.
     * @param operation Operation type for avatar execution.
     */
    function execAndReturnData(
        address target,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) internal returns (bool success, bytes memory returnData) {
        address currentGuard = guard;
        if (currentGuard != address(0)) {
            IGuard(currentGuard).checkTransaction(
                to,
                value,
                data,
                operation,
                // Zero out the redundant transaction information only used for Safe multisig transactions.
                0,
                0,
                0,
                address(0),
                payable(0),
                bytes("0x"),
                msg.sender
            );
            (success, returnData) = IAvatar(target).execTransactionFromModuleReturnData(to, value, data, operation);
            IGuard(currentGuard).checkAfterExecution(bytes32("0x"), success);
        } else {
            (success, returnData) = IAvatar(target).execTransactionFromModuleReturnData(to, value, data, operation);
        }
        return (success, returnData);
    }
}
