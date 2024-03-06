// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import { RewardTimelockOperationEncoder } from "../encoders/RewardTimelockOperationEncoder.sol";
import { ImmunefiModule } from "../ImmunefiModule.sol";
import { VaultFreezer } from "../VaultFreezer.sol";
import { Arbitration } from "../Arbitration.sol";
import { VaultDelegate } from "../common/VaultDelegate.sol";
import { PriceConsumer } from "../oracles/PriceConsumer.sol";
import { IRewardTimelockEvents } from "../events/IRewardTimelockEvents.sol";

/**
 * @title RewardTimelockBase
 * @author Immunefi
 * @notice Base contract for the RewardTimelock component
 * @dev Includes variable declaration and setter functions
 */
abstract contract RewardTimelockBase is OwnableUpgradeable, RewardTimelockOperationEncoder, IRewardTimelockEvents {
    uint8 public constant PRICE_DEVIATION_TOLERANCE_BPS = 100; // 1%

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
        uint40 dollarAmount; // 0 decimals
        TxState state;
        address to;
        uint32 cooldown;
        uint32 expiration;
    }

    struct TxStorageData {
        uint40 queueTimestamp;
        uint40 dollarAmount; // 0 decimals
        TxState state;
        address vault;
        address to;
        uint32 cooldown;
        uint32 expiration;
    }

    uint32 public txCooldown;
    uint32 public txExpiration;
    ImmunefiModule public immunefiModule;
    VaultFreezer public vaultFreezer;
    VaultDelegate public vaultDelegate;
    PriceConsumer public priceConsumer;
    Arbitration public arbitration;

    mapping(address => uint256) public vaultTxNonce;
    mapping(address => bytes32[]) public vaultTxHashes;
    mapping(bytes32 => TxStorageData) public txHashData;

    /**
     * @notice Sets the txCooldown
     * @param newTxCooldown New cooldown value
     */
    function setTxCooldown(uint32 newTxCooldown) external onlyOwner {
        _setTxCooldown(newTxCooldown);
        emit TxCooldownSet(newTxCooldown);
    }

    function _setTxCooldown(uint32 newTxCooldown) internal {
        require(newTxCooldown != 0, "RewardTimelock: cooldown cannot be 0");
        txCooldown = newTxCooldown;
    }

    /**
     * @notice Sets the txExpiration
     * @param newTxExpiration New expiration value
     */
    function setTxExpiration(uint32 newTxExpiration) external onlyOwner {
        _setTxExpiration(newTxExpiration);
        emit TxExpirationSet(newTxExpiration);
    }

    function _setTxExpiration(uint32 newTxExpiration) internal {
        require(
            newTxExpiration == 0 || newTxExpiration >= 60,
            "RewardTimelock: expiration must be 0 or at least 60 seconds"
        );
        txExpiration = newTxExpiration;
    }

    /**
     * @notice Sets the module contract
     * @param newModule Address of the new module contract
     */
    function setModule(address newModule) external onlyOwner {
        _setModule(newModule);
        emit ModuleSet(newModule);
    }

    function _setModule(address newModule) internal {
        require(newModule != address(0), "RewardTimelock: module cannot be 0x00");
        immunefiModule = ImmunefiModule(newModule);
    }

    /**
     * @notice Sets the vault freezer contract
     * @param newVaultFreezer Address of the new vault freezer contract
     */
    function setVaultFreezer(address newVaultFreezer) external onlyOwner {
        _setVaultFreezer(newVaultFreezer);
        emit VaultFreezerSet(newVaultFreezer);
    }

    function _setVaultFreezer(address newVaultFreezer) internal {
        require(newVaultFreezer != address(0), "RewardTimelock: vault freezer cannot be 0x00");
        vaultFreezer = VaultFreezer(newVaultFreezer);
    }

    /**
     * @notice Sets the vault delegate contract
     * @param newVaultDelegate Address of the new vault delegate contract
     */
    function setVaultDelegate(address newVaultDelegate) external onlyOwner {
        _setVaultDelegate(newVaultDelegate);
        emit VaultDelegateSet(newVaultDelegate);
    }

    function _setVaultDelegate(address newVaultDelegate) internal {
        require(newVaultDelegate != address(0), "RewardTimelock: vault delegate cannot be 0x00");
        vaultDelegate = VaultDelegate(newVaultDelegate);
    }

    /**
     * @notice Sets the price consumer contract
     * @param newPriceConsumer Address of the new price consumer contract
     */
    function setPriceConsumer(address newPriceConsumer) external onlyOwner {
        _setPriceConsumer(newPriceConsumer);
        emit PriceConsumerSet(newPriceConsumer);
    }

    function _setPriceConsumer(address newPriceConsumer) internal {
        require(newPriceConsumer != address(0), "RewardTimelock: price consumer cannot be 0x00");
        priceConsumer = PriceConsumer(newPriceConsumer);
    }

    /**
     * @notice Sets the arbitration contract
     * @param newArbitration Address of the new arbitration contract
     */
    function setArbitration(address newArbitration) external onlyOwner {
        _setArbitration(newArbitration);
        emit ArbitrationSet(newArbitration);
    }

    function _setArbitration(address newArbitration) internal {
        require(newArbitration != address(0), "RewardTimelock: arbitration cannot be 0x00");
        arbitration = Arbitration(newArbitration);
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
        require(start < txHashes.length, "RewardTimelock: start out of bounds");

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
                dollarAmount: txHashData[txHash].dollarAmount,
                state: txHashData[txHash].state,
                to: txHashData[txHash].to,
                cooldown: txHashData[txHash].cooldown,
                expiration: txHashData[txHash].expiration
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
                dollarAmount: txHashData[txHash].dollarAmount,
                state: txHashData[txHash].state,
                to: txHashData[txHash].to,
                cooldown: txHashData[txHash].cooldown,
                expiration: txHashData[txHash].expiration
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
}
