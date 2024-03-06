// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { BaseEncoder } from "./BaseEncoder.sol";

/**
 * @title RewardTimelockOperationEncoder
 * @author Immunefi
 * @notice Message encoder for the RewardTimelock component
 */
abstract contract RewardTimelockOperationEncoder is BaseEncoder {
    // solhint-disable max-line-length
    // keccak256("QueueTx(address to,uint256 dollarAmount,address vault,uint256 nonce)");
    bytes32 private constant QUEUE_TX_TYPEHASH = 0x4af330736ab3907551d441237f96d189a0ed673a73e997899843c3d7535df861;

    // keccak256("ExecuteTx(bytes32 queueTxHash,uint256 nonce)");
    bytes32 private constant EXECUTE_TX_TYPEHASH = 0xb01c7b7e8aaf054921cdb1c63457ee0e8123d562d13f3fd6a8047d0a21e5fa6a;

    // keccak256("CancelTx(bytes32 queueTxHash,uint256 nonce)");
    bytes32 private constant CANCEL_TX_TYPEHASH = 0x1016938b0498095bc3332f48ba1ff08b42c1729269b701c2e82fbe11355c23c8;

    // solhint-enable max-line-length

    /**
     * @notice Returns the queueTransaction message that is hashed to be signed.
     * @param to Destination address of module transaction.
     * @param dollarAmount Dollar amount to be rewarded.
     * @param vault Address of the vault.
     * @param nonce RewardTimelock transaction nonce.
     */
    function encodeQueueRewardData(
        address to,
        uint256 dollarAmount,
        address vault,
        uint256 nonce
    ) public view returns (bytes memory) {
        bytes32 queueTxHash = keccak256(abi.encode(QUEUE_TX_TYPEHASH, to, dollarAmount, vault, nonce));
        return _encodeTypedData(queueTxHash);
    }

    /**
     * @notice Returns the executeTransaction message that is hashed to be signed.
     * @param queueTxHash Queue transaction hash.
     * @param nonce Transaction nonce.
     */
    function encodeExecuteRewardData(bytes32 queueTxHash, uint256 nonce) public view returns (bytes memory) {
        bytes32 executeTxHash = keccak256(abi.encode(EXECUTE_TX_TYPEHASH, queueTxHash, nonce));
        return _encodeTypedData(executeTxHash);
    }

    /**
     * @notice Returns the cancelTransaction message that is hashed to be signed.
     * @param queueTxHash Queue transaction hash.
     * @param nonce Transaction nonce.
     */
    function encodeCancelTransactionData(bytes32 queueTxHash, uint256 nonce) public view returns (bytes memory) {
        bytes32 cancelTxHash = keccak256(abi.encode(CANCEL_TX_TYPEHASH, queueTxHash, nonce));
        return _encodeTypedData(cancelTxHash);
    }
}
