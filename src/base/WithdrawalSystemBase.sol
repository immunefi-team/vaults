// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Timelock } from "../Timelock.sol";
import { VaultDelegate } from "../common/VaultDelegate.sol";
import { IWithdrawalSystemEvents } from "../events/IWithdrawalSystemEvents.sol";

/**
 * @title WithdrawalSystemBase
 * @author Immunefi
 * @notice Base contract for the WithdrawalSystem component
 * @dev Includes variable declaration and setter functions
 */
abstract contract WithdrawalSystemBase is OwnableUpgradeable, IWithdrawalSystemEvents {
    Timelock public timelock;
    VaultDelegate public vaultDelegate;
    uint32 public txCooldown;
    uint32 public txExpiration;

    /**
     * @notice Sets the timelock contract
     * @param newTimelock Address of the new timelock contract
     */
    function setTimelock(address newTimelock) external onlyOwner {
        emit TimelockSet(newTimelock);
        _setTimelock(newTimelock);
    }

    function _setTimelock(address newTimelock) internal {
        require(newTimelock != address(0), "WithdrawalSystem: timelock cannot be 0x00");
        timelock = Timelock(newTimelock);
    }

    /**
     * @notice Sets vault delegate
     * @param newVaultDelegate Address of the new vault delegate
     */
    function setVaultDelegate(address newVaultDelegate) external onlyOwner {
        _setVaultDelegate(newVaultDelegate);
        emit VaultDelegateSet(newVaultDelegate);
    }

    function _setVaultDelegate(address newVaultDelegate) internal {
        require(newVaultDelegate != address(0), "WithdrawalSystem: vaultDelegate cannot be 0x00");
        vaultDelegate = VaultDelegate(newVaultDelegate);
    }

    /**
     * @notice Sets the cooldown before a timelocked transaction can be executed.
     * @param cooldown Cooldown in seconds that should be required before the transaction can be executed
     */
    function setTxCooldown(uint32 cooldown) external onlyOwner {
        emit TxCooldownChanged(txCooldown, cooldown);
        _setTxCooldown(cooldown);
    }

    function _setTxCooldown(uint32 cooldown) internal {
        txCooldown = cooldown;
    }

    /**
     * @notice Sets the duration for which a timelocked transaction is valid.
     * @param expiration Duration that a transaction is valid in seconds (or 0 if valid forever) after the cooldown
     * @dev There needs to be at least 60 seconds between end of cooldown and expiration
     */
    function setTxExpiration(uint256 expiration) external onlyOwner {
        emit TxExpirationChanged(txExpiration, expiration);
        _setTxExpiration(expiration);
    }

    function _setTxExpiration(uint256 expiration) internal {
        require(expiration == 0 || expiration >= 60, "Timelock: expiration must be 0 or at least 60 seconds");
        txExpiration = uint32(expiration);
    }
}
