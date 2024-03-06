// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Rewards } from "../common/Rewards.sol";

interface IRewardSystemEvents {
    event RewardSystemSetup(address indexed initiator, address indexed owner);
    event ModuleSet(address indexed module);
    event VaultDelegateSet(address vaultDelegate);
    event ArbitrationSet(address arbitration);
    event VaultFreezerSet(address vaultFreezer);
    event FeeRecipientSet(address prevFeeRecipient, address newFeeRecipient);
    event FeeSet(uint256 prevFee, uint256 newFee);
    event RewardSent(
        address indexed from,
        bytes32 indexed referenceId,
        address to,
        Rewards.ERC20Reward[] tokenAmounts,
        uint256 nativeTokenAmount,
        address feeRecipient,
        uint256 fee
    );
}
