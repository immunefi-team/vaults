// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { TimelockBase } from "./base/TimelockBase.sol";

/**
 * @title Timelock
 * @author Immunefi
 * @notice A component which enforces timelocks on operations, to forward to the ImmunefiModule
 */
contract Timelock is TimelockBase {
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _owner Default admin role recipient
     * @param _module Address of the ImmunefiModule
     * @param _vaultFreezer Address of the VaultFreezer
     */
    function setUp(address _owner, address _module, address _vaultFreezer) public initializer {
        __AccessControl_init();

        require(_owner != address(0), "Timelock: owner cannot be 0x00");

        _setModule(_module);
        _setVaultFreezer(_vaultFreezer);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        emit TimelockSetup(msg.sender, _owner);
    }

    /**
     * @notice Queues a transction to be executed after the cooldown period.
     * @param to Destination address of vault transaction.
     * @param value Ether value of vault transaction.
     * @param data Data payload of vault transaction.
     * @param operation Operation type of vault transaction.
     */
    function queueTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        address vault,
        uint256 cooldown,
        uint256 expiration
    ) external onlyRole(QUEUER_ROLE) {
        require(!vaultFreezer.isFrozen(vault), "Timelock: vault is frozen");

        uint256 nonce = vaultTxNonce[vault];

        bytes memory encodedData = encodeQueueTransactionData(to, value, data, operation, vault, nonce);
        bytes32 txHash = _getTxHashFromData(encodedData);
        vaultTxHashes[vault].push(txHash);

        txHashData[txHash].queueTimestamp = uint40(block.timestamp);
        txHashData[txHash].cooldown = uint32(cooldown);
        txHashData[txHash].expiration = uint32(expiration);
        txHashData[txHash].state = TxState.Queued;
        txHashData[txHash].execData = abi.encode(to, value, data, operation, vault);

        vaultTxNonce[vault] = nonce + 1;

        emit TransactionQueued(txHash, to, vault, value, data, operation);
    }

    /**
     * @notice Executes a transaction that has passed cooldown.
     * @param txHash Transaction hash.
     */
    function executeTransaction(bytes32 txHash) external {
        TxStorageData memory txData = txHashData[txHash];
        require(txData.state == TxState.Queued, "Timelock: transaction is not queued");
        require(
            txData.queueTimestamp + txData.cooldown <= block.timestamp,
            "Timelock: transaction is not yet executable"
        );
        require(
            txData.expiration == 0 || txData.queueTimestamp + txData.cooldown + txData.expiration > block.timestamp,
            "Timelock: transaction is expired"
        );

        (address to, uint256 value, bytes memory data, Enum.Operation operation, address vault) = abi.decode(
            txData.execData,
            (address, uint256, bytes, Enum.Operation, address)
        );

        require(msg.sender == vault, "Timelock: only vault can execute transaction");
        require(!vaultFreezer.isFrozen(vault), "Timelock: vault is frozen");

        txHashData[txHash].state = TxState.Executed;

        emit TransactionExecuted(txHash, to, vault, value, data, operation);
        immunefiModule.execute(vault, to, value, data, operation);
    }

    /**
     * @notice Cancels a transaction that has not yet been executed.
     * @param txHash Transaction hash.
     */
    function cancelTransaction(bytes32 txHash) external {
        TxStorageData memory txData = txHashData[txHash];
        require(txData.state == TxState.Queued, "Timelock: transaction is not queued");

        (address to, uint256 value, bytes memory data, Enum.Operation operation, address vault) = abi.decode(
            txData.execData,
            (address, uint256, bytes, Enum.Operation, address)
        );

        require(msg.sender == vault, "Timelock: only vault can cancel transaction");
        require(!vaultFreezer.isFrozen(vault), "Timelock: vault is frozen");

        txHashData[txHash].state = TxState.Canceled;

        emit TransactionCanceled(txHash, to, vault, value, data, operation);
    }

    /**
     * @notice Gets the transaction hash for a queued transaction, to be signed.
     * @param to Destination address of vault transaction.
     * @param value Ether value of vault transaction.
     * @param data Data payload of vault transaction.
     * @param operation Operation type of vault transaction.
     * @param vault Address of the vault.
     * @param nonce Transaction nonce.
     */
    function getQueueTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        address vault,
        uint256 nonce
    ) public view returns (bytes32) {
        return _getTxHashFromData(encodeQueueTransactionData(to, value, data, operation, vault, nonce));
    }

    function _getTxHashFromData(bytes memory data) private pure returns (bytes32) {
        return keccak256(data);
    }

    /**
     * @notice Checks if a transaction can be executed.
     * @param txHash Transaction hash.
     */
    function canExecuteTransaction(bytes32 txHash) external view returns (bool) {
        TxStorageData memory txData = txHashData[txHash];
        (, , , , address vault) = abi.decode(txData.execData, (address, uint256, bytes, Enum.Operation, address));
        return
            !vaultFreezer.isFrozen(vault) &&
            txData.state == TxState.Queued &&
            txData.queueTimestamp + txData.cooldown <= block.timestamp &&
            (txData.expiration == 0 || txData.queueTimestamp + txData.cooldown + txData.expiration > block.timestamp);
    }
}
