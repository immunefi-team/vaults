// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { AccessControlBaseModule } from "../base/AccessControlBaseModule.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

/**
 * @title ReturnDataModule
 * @notice A mock module to call execAndReturnData
 */
contract ReturnDataModule is AccessControlBaseModule {
    constructor() {
        setUp("");
    }

    function setUp(bytes memory) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Exposes internal exec function
     * @dev Function is rendered useless if there's an emergency shutdown
     * @dev Access control is also dependent on a guard attached to this module
     * @param target Address of avatar/modifier to execute transaction on.
     * @param to Destination address of module transaction.
     * @param value Ether value of module transaction.
     * @param data Data payload of module transaction.
     */
    function executeReturnData(
        address target,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external returns (bool, bytes memory) {
        return execAndReturnData(target, to, value, data, operation);
    }
}
