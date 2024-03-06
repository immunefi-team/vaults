// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

interface IWithdrawalSystemEvents {
    event WithdrawalSystemSetup(address indexed initiator, address indexed owner);
    event TimelockSet(address indexed timelock);
    event VaultDelegateSet(address vaultDelegate);
    event TxCooldownChanged(uint32 oldCooldown, uint32 newCooldown);
    event TxExpirationChanged(uint256 oldExpiration, uint256 newExpiration);
}
