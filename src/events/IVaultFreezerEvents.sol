// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

interface IVaultFreezerEvents {
    event VaultFreezerSetup(address indexed initiator, address indexed owner);
    event VaultFreezed(address indexed vault);
    event VaultUnfreezed(address indexed vault);
}
