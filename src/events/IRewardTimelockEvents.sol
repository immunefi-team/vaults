// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Rewards } from "../common/Rewards.sol";

interface IRewardTimelockEvents {
    event RewardTimelockSetup(address indexed initiator, address indexed owner);
    event TxCooldownSet(uint32 txCooldown);
    event TxExpirationSet(uint32 txExpiration);
    event ModuleSet(address indexed module);
    event VaultFreezerSet(address indexed vaultFreezer);
    event VaultDelegateSet(address indexed vaultDelegate);
    event PriceConsumerSet(address indexed priceConsumer);
    event ArbitrationSet(address arbitration);
    event TransactionQueued(bytes32 indexed txHash, address indexed to, address indexed vault, uint256 dollarAmount);
    event TransactionExecuted(
        bytes32 indexed txHash,
        address indexed to,
        address indexed vault,
        uint256 dollarAmount,
        Rewards.ERC20Reward[] tokenAmounts,
        uint256 nativeTokenAmount
    );
    event TransactionCanceled(bytes32 indexed txHash, address indexed to, address indexed vault, uint256 dollarAmount);
}
