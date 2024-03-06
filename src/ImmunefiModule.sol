// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { AccessControlBaseModule } from "./base/AccessControlBaseModule.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { EmergencySystem } from "./EmergencySystem.sol";

/**
 * @title ImmunefiModule
 * @author Immunefi
 * @notice A zodiac module that can forward to different Safe contracts
 * @dev Logic is rendered useless if there's an emergency shutdown
 * @dev Access control is dependent on roles and on a guard attached to this module
 */
contract ImmunefiModule is AccessControlBaseModule {
    bytes32 public constant EXECUTOR_ROLE = keccak256("module.executor.role");
    EmergencySystem public immutable emergencySystem;

    constructor(address _emergencySystem) {
        emergencySystem = EmergencySystem(_emergencySystem);
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _owner Default admin role recipient
     */
    function setUp(address _owner) public initializer {
        __AccessControl_init();

        require(_owner != address(0), "ImmunefiModule: owner cannot be 0x00");

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
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
    function execute(
        address target,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external onlyRole(EXECUTOR_ROLE) {
        require(target != address(0), "ImmunefiModule: target is zero address");
        require(!emergencySystem.emergencyShutdownActive(), "ImmunefiModule: emergency shutdown is active");
        bool success = exec(target, to, value, data, operation);
        require(success, "ImmunefiModule: execution failed");
    }
}
