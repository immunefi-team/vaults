// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

interface ITimelockEvents {
    event TimelockSetup(address indexed initiator, address indexed owner);
    event ModuleSet(address indexed module);
    event VaultFreezerSet(address indexed vaultFreezer);
    event TransactionQueued(
        bytes32 indexed txHash,
        address indexed to,
        address indexed vault,
        uint256 value,
        bytes data,
        Enum.Operation operation
    );
    event TransactionExecuted(
        bytes32 indexed txHash,
        address indexed to,
        address indexed vault,
        uint256 value,
        bytes data,
        Enum.Operation operation
    );
    event TransactionCanceled(
        bytes32 indexed txHash,
        address indexed to,
        address indexed vault,
        uint256 value,
        bytes data,
        Enum.Operation operation
    );
}
