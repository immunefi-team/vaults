// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IRewardSystemEvents } from "../events/IRewardSystemEvents.sol";
import { ImmunefiModule } from "../ImmunefiModule.sol";
import { Timelock } from "../Timelock.sol";
import { VaultDelegate } from "../common/VaultDelegate.sol";
import { VaultFreezer } from "../VaultFreezer.sol";
import { Arbitration } from "../Arbitration.sol";

/**
 * @title RewardSystemBase
 * @author Immunefi
 * @notice Base contract for the RewardSystem component
 * @dev Includes variable declaration and setter functions
 * @dev Constructor is included to initialize immutable variables
 */
abstract contract RewardSystemBase is AccessControlUpgradeable, IRewardSystemEvents {
    bytes32 public constant ENFORCER_ROLE = keccak256("reward.enforcer.role");

    ImmunefiModule public immunefiModule;
    VaultDelegate public vaultDelegate;
    Arbitration public arbitration;
    VaultFreezer public vaultFreezer;

    /**
     * @notice Sets the module contract
     * @param newModule Address of the new module contract
     */
    function setModule(address newModule) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setModule(newModule);
        emit ModuleSet(newModule);
    }

    function _setModule(address newModule) internal {
        require(newModule != address(0), "RewardSystem: module cannot be 0x00");
        immunefiModule = ImmunefiModule(newModule);
    }

    /**
     * @notice Sets vault delegate
     * @param newVaultDelegate Address of the new vault delegate
     */
    function setVaultDelegate(address newVaultDelegate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setVaultDelegate(newVaultDelegate);
        emit VaultDelegateSet(newVaultDelegate);
    }

    function _setVaultDelegate(address newVaultDelegate) internal {
        require(newVaultDelegate != address(0), "RewardSystem: vaultDelegate cannot be 0x00");
        vaultDelegate = VaultDelegate(newVaultDelegate);
    }

    /**
     * @notice Sets arbitration contract
     * @param newArbitration Address of the new arbitration contract
     */
    function setArbitration(address newArbitration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setArbitration(newArbitration);
        emit ArbitrationSet(newArbitration);
    }

    function _setArbitration(address newArbitration) internal {
        require(newArbitration != address(0), "RewardSystem: arbitration cannot be 0x00");
        arbitration = Arbitration(newArbitration);
    }

    /**
     * @notice Sets vault freezer
     * @param newVaultFreezer Address of the new vault freezer
     */
    function setVaultFreezer(address newVaultFreezer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setVaultFreezer(newVaultFreezer);
        emit VaultFreezerSet(newVaultFreezer);
    }

    function _setVaultFreezer(address newVaultFreezer) internal {
        require(newVaultFreezer != address(0), "RewardSystem: vaultFreezer cannot be 0x00");
        vaultFreezer = VaultFreezer(newVaultFreezer);
    }
}
