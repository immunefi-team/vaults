// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { TimelockOperationEncoder } from "../encoders/TimelockOperationEncoder.sol";
import { ImmunefiModule } from "../ImmunefiModule.sol";
import { VaultFreezer } from "../VaultFreezer.sol";
import { ITimelockEvents } from "../events/ITimelockEvents.sol";

/**
 * @title TimelockBase
 * @author Immunefi
 * @notice Base contract for the Timelock component
 * @dev Includes variable declaration and setter functions
 */
abstract contract TimelockBase is AccessControlUpgradeable, TimelockOperationEncoder, ITimelockEvents {
    bytes32 public constant QUEUER_ROLE = keccak256("timelock.queuer.role");

    enum TxState {
        Uninitialized, // Default state
        Queued,
        Executed,
        Canceled
    }

    struct TxDetails {
        // for getter, not stored
        uint256 index;
        bytes32 txHash;
        uint40 queueTimestamp;
        uint32 cooldown;
        uint32 expiration;
        TxState state;
        bytes execData;
    }

    struct TxStorageData {
        uint40 queueTimestamp;
        uint32 cooldown;
        uint32 expiration;
        TxState state;
        bytes execData;
    }

    ImmunefiModule public immunefiModule;
    VaultFreezer public vaultFreezer;
    mapping(address => uint256) public vaultTxNonce;
    mapping(address => bytes32[]) public vaultTxHashes;
    mapping(bytes32 => TxStorageData) public txHashData;

    /**
     * @notice Sets the module contract
     * @param newModule Address of the new module contract
     */
    function setModule(address newModule) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setModule(newModule);
        emit ModuleSet(newModule);
    }

    function _setModule(address newModule) internal {
        require(newModule != address(0), "Timelock: module cannot be 0x00");
        immunefiModule = ImmunefiModule(newModule);
    }

    /**
     * @notice Sets the vault freezer contract
     * @param newVaultFreezer Address of the new vault freezer contract
     */
    function setVaultFreezer(address newVaultFreezer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setVaultFreezer(newVaultFreezer);
        emit VaultFreezerSet(newVaultFreezer);
    }

    function _setVaultFreezer(address newVaultFreezer) internal {
        require(newVaultFreezer != address(0), "Timelock: vault freezer cannot be 0x00");
        vaultFreezer = VaultFreezer(newVaultFreezer);
    }

    /**
     * @notice Returns the number of transactions for a vault.
     * @param vault Address of the vault.
     */
    function getVaultTxHashesLength(address vault) external view returns (uint256) {
        return vaultTxHashes[vault].length;
    }

    /**
     * @notice Returns a page of transaction details for a vault.
     * @param vault Address of the vault.
     * @param start Index of the first transaction to return, or (length - 1 - start) if reverseSort is true.
     * @param pageSize Number of transactions to return.
     */
    function getVaultTxsPaginated(
        address vault,
        uint256 start,
        uint256 pageSize,
        bool reverseSort
    ) external view returns (TxDetails[] memory) {
        bytes32[] storage txHashes = vaultTxHashes[vault];
        require(start < txHashes.length, "Timelock: start out of bounds");

        if (reverseSort) {
            return _getVaultTxsPaginatedReversed(txHashes, start, pageSize);
        } else {
            return _getVaultTxsPaginated(txHashes, start, pageSize);
        }
    }

    function _getVaultTxsPaginated(
        bytes32[] storage txHashes,
        uint256 start,
        uint256 pageSize
    ) internal view returns (TxDetails[] memory) {
        TxDetails[] memory txs = new TxDetails[](pageSize);

        uint256 returnArraySize;
        uint256 length = txHashes.length;
        for (uint256 i = start; i < length; i++) {
            bytes32 txHash = txHashes[i];
            txs[returnArraySize] = TxDetails({
                index: i,
                txHash: txHash,
                queueTimestamp: txHashData[txHash].queueTimestamp,
                cooldown: txHashData[txHash].cooldown,
                expiration: txHashData[txHash].expiration,
                state: txHashData[txHash].state,
                execData: txHashData[txHash].execData
            });

            returnArraySize++;
            if (returnArraySize == pageSize) {
                break;
            }
        }

        assembly {
            // downsize array to actual amount of elements
            mstore(txs, returnArraySize)
        }
        return txs;
    }

    function _getVaultTxsPaginatedReversed(
        bytes32[] storage txHashes,
        uint256 start,
        uint256 pageSize
    ) internal view returns (TxDetails[] memory) {
        TxDetails[] memory txs = new TxDetails[](pageSize);

        uint256 returnArraySize;
        uint256 initialIndex = txHashes.length - start - 1;
        for (uint256 i = initialIndex; ; i--) {
            bytes32 txHash = txHashes[i];
            txs[returnArraySize] = TxDetails({
                index: i,
                txHash: txHash,
                queueTimestamp: txHashData[txHash].queueTimestamp,
                cooldown: txHashData[txHash].cooldown,
                expiration: txHashData[txHash].expiration,
                state: txHashData[txHash].state,
                execData: txHashData[txHash].execData
            });

            returnArraySize++;
            if (returnArraySize == pageSize || i == 0) {
                break;
            }
        }

        assembly {
            mstore(txs, returnArraySize)
        }
        return txs;
    }

    function getVaultTxsPaginatedBySighash(
        address vault,
        uint256 start,
        uint256 pageSize,
        bytes4 sighash,
        bool reverseSort
    ) external view returns (TxDetails[] memory) {
        bytes32[] storage txHashes = vaultTxHashes[vault];
        uint256 txCount = txHashes.length;
        require(start < txCount, "Timelock: start out of bounds");

        if (reverseSort) {
            return _getVaultTxsPaginatedBySighashReversed(txHashes, start, pageSize, sighash);
        } else {
            return _getVaultTxsPaginatedBySighash(txHashes, start, pageSize, sighash);
        }
    }

    function _getVaultTxsPaginatedBySighash(
        bytes32[] storage txHashes,
        uint256 start,
        uint256 pageSize,
        bytes4 sighash
    ) internal view returns (TxDetails[] memory) {
        TxDetails[] memory txs = new TxDetails[](pageSize);

        uint256 returnArraySize;
        uint256 length = txHashes.length;
        for (uint256 i = start; i < length; i++) {
            bytes32 txHash = txHashes[i];
            bytes memory execData = txHashData[txHash].execData;
            (, , bytes memory callingData, , ) = abi.decode(
                execData,
                (address, uint256, bytes, Enum.Operation, address)
            );
            if (sighash == bytes4(callingData)) {
                txs[returnArraySize] = TxDetails({
                    index: i,
                    txHash: txHash,
                    queueTimestamp: txHashData[txHash].queueTimestamp,
                    cooldown: txHashData[txHash].cooldown,
                    expiration: txHashData[txHash].expiration,
                    state: txHashData[txHash].state,
                    execData: execData
                });
                returnArraySize++;
                if (returnArraySize == pageSize) {
                    break;
                }
            }
        }

        assembly {
            mstore(txs, returnArraySize)
        }
        return txs;
    }

    function _getVaultTxsPaginatedBySighashReversed(
        bytes32[] storage txHashes,
        uint256 start,
        uint256 pageSize,
        bytes4 sighash
    ) internal view returns (TxDetails[] memory) {
        TxDetails[] memory txs = new TxDetails[](pageSize);

        uint256 returnArraySize;
        uint256 initialIndex = txHashes.length - start - 1;
        for (uint256 i = initialIndex; ; i--) {
            bytes32 txHash = txHashes[i];
            bytes memory execData = txHashData[txHash].execData;
            (, , bytes memory callingData, , ) = abi.decode(
                execData,
                (address, uint256, bytes, Enum.Operation, address)
            );
            if (sighash == bytes4(callingData)) {
                txs[returnArraySize] = TxDetails({
                    index: i,
                    txHash: txHash,
                    queueTimestamp: txHashData[txHash].queueTimestamp,
                    cooldown: txHashData[txHash].cooldown,
                    expiration: txHashData[txHash].expiration,
                    state: txHashData[txHash].state,
                    execData: execData
                });
                returnArraySize++;
                if (returnArraySize == pageSize) {
                    break;
                }
            }
            if (i == 0) {
                break;
            }
        }

        assembly {
            mstore(txs, returnArraySize)
        }
        return txs;
    }
}
