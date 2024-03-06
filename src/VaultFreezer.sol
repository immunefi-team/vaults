// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IVaultFreezerEvents } from "./events/IVaultFreezerEvents.sol";

/**
 * @title VaultFreezer
 * @author Immunefi
 * @dev This contract is used to tag vaults as frozen/unfrozen.
 */
contract VaultFreezer is AccessControlUpgradeable, IVaultFreezerEvents {
    bytes32 public constant FREEZER_ROLE = keccak256("freezer.role");
    mapping(address => bool) public isFrozen;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _owner Default admin role recipient
     */
    function setUp(address _owner) public initializer {
        __AccessControl_init();

        require(_owner != address(0), "VaultFreezer: owner cannot be 0x00");
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        emit VaultFreezerSetup(msg.sender, _owner);
    }

    /**
     * @notice Freezes a vault.
     * @param vault Address of the vault to freeze.
     */
    function freezeVault(address vault) external onlyRole(FREEZER_ROLE) {
        require(!isFrozen[vault], "VaultFreezer: vault already frozen");

        isFrozen[vault] = true;

        emit VaultFreezed(vault);
    }

    /**
     * @notice Unfreezes a vault.
     * @param vault Address of the vault to unfreeze.
     */
    function unfreezeVault(address vault) external onlyRole(FREEZER_ROLE) {
        require(isFrozen[vault], "VaultFreezer: vault already unfrozen");

        isFrozen[vault] = false;

        emit VaultUnfreezed(vault);
    }
}
