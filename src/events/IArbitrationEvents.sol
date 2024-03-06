// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

interface IArbitrationEvents {
    event ModuleSet(address module);
    event RewardSystemSet(address rewardSystem);
    event VaultDelegateSet(address vaultDelegate);
    event FeeTokenSet(address feeToken);
    event FeeAmountSet(uint256 feeAmount);
    event FeeRecipientSet(address newFeeRecipient);
    event ArbitrationSetup(address indexed initiator, address indexed owner);
    event ArbitrationRequestedByWhitehat(uint96 indexed referenceId, address indexed vault, address indexed whitehat);
    event ArbitrationRequestedByVault(uint96 indexed referenceId, address indexed vault, address indexed whitehat);
    event ArbitrationClosed(bytes32 indexed arbitrationId);
}
