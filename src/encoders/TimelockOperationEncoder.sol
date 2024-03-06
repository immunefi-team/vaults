// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { BaseEncoder } from "./BaseEncoder.sol";

/**
 * @title TimelockOperationEncoder
 * @author Immunefi
 * @notice Message encoder for the Timelock component
 */
abstract contract TimelockOperationEncoder is BaseEncoder {
    // solhint-disable max-line-length
    // keccak256("QueueTx(address to,uint256 value,bytes data,uint8 operation,address vault,uint256 nonce)");
    bytes32 private constant QUEUE_TX_TYPEHASH = 0x8c5997cbee0e96cbb74515423607cbefdf7c33a876cfaaec589783883f006374;

    // keccak256("ExecuteTx(bytes32 queueTxHash,uint256 nonce)");
    bytes32 private constant EXECUTE_TX_TYPEHASH = 0xb01c7b7e8aaf054921cdb1c63457ee0e8123d562d13f3fd6a8047d0a21e5fa6a;

    // keccak256("CancelTx(bytes32 queueTxHash,uint256 nonce)");
    bytes32 private constant CANCEL_TX_TYPEHASH = 0x1016938b0498095bc3332f48ba1ff08b42c1729269b701c2e82fbe11355c23c8;

    // solhint-enable max-line-length

    /**
     * @notice Returns the queueTransaction message that is hashed to be signed.
     * @param to Destination address of module transaction.
     * @param value Ether value of module transaction.
     * @param data Data payload of module transaction.
     * @param operation Operation type for avatar execution.
     * @param vault Address of the vault.
     * @param nonce Timelock transaction nonce.
     */
    function encodeQueueTransactionData(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        address vault,
        uint256 nonce
    ) public view returns (bytes memory) {
        bytes32 queueTxHash = keccak256(
            abi.encode(QUEUE_TX_TYPEHASH, to, value, keccak256(data), operation, vault, nonce)
        );
        return _encodeTypedData(queueTxHash);
    }

    /**
     * @notice Returns the executeTransaction message that is hashed to be signed.
     * @param queueTxHash Queue transaction hash.
     * @param nonce Transaction nonce.
     */
    function encodeExecuteTransactionData(bytes32 queueTxHash, uint256 nonce) public view returns (bytes memory) {
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
