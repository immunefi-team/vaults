// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Rewards } from "./common/Rewards.sol";
import { Denominations } from "./oracles/chainlink/Denominations.sol";
import { RewardTimelockBase } from "./base/RewardTimelockBase.sol";

/**
 * @title RewardTimelock
 * @author Immunefi
 * @notice A component which implements timelocked reward sending with slippage protection,
 * to forward to the ImmunefiModule
 */
contract RewardTimelock is RewardTimelockBase {
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _owner Default admin role recipient
     * @param _module Address of the ImmunefiModule
     * @param _vaultFreezer Address of the VaultFreezer
     * @param _vaultDelegate Address of the VaultDelegate
     * @param _priceConsumer Address of the PriceConsumer
     * @param _arbitration Address of the Arbitration
     * @param _txCooldown The cooldown period for transactions
     * @param _txExpiration The expiration period for transactions
     */
    function setUp(
        address _owner,
        address _module,
        address _vaultFreezer,
        address _vaultDelegate,
        address _priceConsumer,
        address _arbitration,
        uint32 _txCooldown,
        uint32 _txExpiration
    ) public initializer {
        __Ownable_init();

        require(_owner != address(0), "RewardTimelock: owner cannot be 0x00");

        _setModule(_module);
        _setVaultFreezer(_vaultFreezer);
        _setVaultDelegate(_vaultDelegate);
        _setPriceConsumer(_priceConsumer);
        _setArbitration(_arbitration);
        _setTxCooldown(_txCooldown);
        _setTxExpiration(_txExpiration);

        _transferOwnership(_owner);

        emit RewardTimelockSetup(msg.sender, _owner);
    }

    /**
     * @notice Queues a transaction to be executed after the cooldown period.
     * @dev This function is should be called by the vault.
     * @param to Destination address of module transaction.
     * @param dollarAmount Dollar amount to be rewarded. 0 decimals.
     */
    function queueRewardTransaction(address to, uint256 dollarAmount) external {
        address vault = msg.sender;
        require(!vaultFreezer.isFrozen(vault), "RewardTimelock: vault is frozen");
        require(arbitration.vaultIsInArbitration(vault), "RewardTimelock: vault is not in arbitration");

        uint256 nonce = vaultTxNonce[vault];

        bytes memory encodedData = encodeQueueRewardData(to, dollarAmount, vault, nonce);
        bytes32 txHash = _getTxHashFromData(encodedData);
        vaultTxHashes[vault].push(txHash);

        txHashData[txHash].queueTimestamp = uint40(block.timestamp);
        txHashData[txHash].dollarAmount = uint40(dollarAmount);
        txHashData[txHash].state = TxState.Queued;
        txHashData[txHash].to = to;
        txHashData[txHash].vault = vault;
        txHashData[txHash].cooldown = txCooldown;
        txHashData[txHash].expiration = txExpiration;

        vaultTxNonce[vault] = nonce + 1;

        emit TransactionQueued(txHash, to, vault, dollarAmount);
    }

    /**
     * @notice Executes a reward transaction that has passed cooldown. Callable by the vault itself.
     * @param txHash Transaction hash.
     * @param referenceId The reference id of the report.
     * @param tokenAmounts The amounts of tokens to send.
     * @param nativeTokenAmount The amount of native tokens to send.
     * @param gasToTarget The gas limit getting forwarded to the recipient address.
     */
    function executeRewardTransaction(
        bytes32 txHash,
        uint96 referenceId,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount,
        uint256 gasToTarget
    ) external {
        TxStorageData memory txData = txHashData[txHash];
        require(txData.state == TxState.Queued, "Timelock: transaction is not queued");
        require(
            txData.queueTimestamp + txData.cooldown <= block.timestamp,
            "RewardTimelock: transaction is not yet executable"
        );
        require(
            txData.expiration == 0 || txData.queueTimestamp + txData.cooldown + txData.expiration > block.timestamp,
            "RewardTimelock: transaction is expired"
        );

        require(msg.sender == txData.vault, "RewardTimelock: only vault can execute transaction");
        require(!vaultFreezer.isFrozen(msg.sender), "RewardTimelock: vault is frozen");
        require(arbitration.vaultIsInArbitration(msg.sender), "RewardTimelock: vault is not in arbitration");

        require(
            block.timestamp - arbitration.timeSinceOngoingArbitration(txData.vault) >= txData.cooldown,
            "RewardTimelock: not enough time passed since in arbitration"
        );

        txHashData[txHash].state = TxState.Executed;

        emit TransactionExecuted(txHash, txData.to, msg.sender, txData.dollarAmount, tokenAmounts, nativeTokenAmount);

        bytes memory data = abi.encodeCall(
            vaultDelegate.sendReward,
            (referenceId, payable(txData.to), tokenAmounts, nativeTokenAmount, gasToTarget)
        );

        _checkRewardDollarValue(uint256(txData.dollarAmount) * 10 ** 18, tokenAmounts, nativeTokenAmount);

        immunefiModule.execute(msg.sender, address(vaultDelegate), 0, data, Enum.Operation.DelegateCall);
    }

    /**
     * @notice Cancels a transaction that has not yet been executed.
     * @param txHash Transaction hash.
     */
    function cancelTransaction(bytes32 txHash) external {
        TxStorageData memory txData = txHashData[txHash];
        require(txData.state == TxState.Queued, "RewardTimelock: transaction is not queued");
        require(msg.sender == txData.vault, "RewardTimelock: only vault can cancel transaction");
        require(!vaultFreezer.isFrozen(msg.sender), "RewardTimelock: vault is frozen");

        txHashData[txHash].state = TxState.Canceled;

        emit TransactionCanceled(txHash, txData.to, msg.sender, txData.dollarAmount);
    }

    /**
     * @notice Gets the transaction hash for a queued transaction, to be signed.
     * @param to Destination address of vault transaction.
     * @param dollarAmount Dollar amount to be rewarded. 0 decimals.
     * @param vault Address of the vault.
     * @param nonce Transaction nonce.
     */
    function getQueueTransactionHash(
        address to,
        uint256 dollarAmount,
        address vault,
        uint256 nonce
    ) public view returns (bytes32) {
        return _getTxHashFromData(encodeQueueRewardData(to, dollarAmount, vault, nonce));
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

        if (vaultFreezer.isFrozen(txData.vault)) return false;
        if (!arbitration.vaultIsInArbitration(txData.vault)) return false;
        // @dev Time shouldn't be 0 if vault is in arbitration.
        // @dev At least txCooldown time should have passed since the vault entered into an arbitration.
        if (block.timestamp - arbitration.timeSinceOngoingArbitration(txData.vault) < txData.cooldown) return false;

        return
            txData.state == TxState.Queued &&
            txData.queueTimestamp + txData.cooldown <= block.timestamp &&
            (txData.expiration == 0 || txData.queueTimestamp + txData.cooldown + txData.expiration > block.timestamp);
    }

    /**
     * @notice Checks if the dollar value of the reward is within the bounds of the queued reward.
     * @param dollarAmount The dollar amount of the reward that was queued. 18 decimals.
     * @param tokenAmounts The amounts of tokens to send.
     * @param nativeTokenAmount The amount of native tokens to send.
     */
    function _checkRewardDollarValue(
        uint256 dollarAmount,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount
    ) internal view {
        uint256 nativeDollarAmount;
        uint256 tokenSumDollarAmount;

        if (nativeTokenAmount != 0) {
            uint256 nativePrice = priceConsumer.tryGetSaneUsdPrice18Decimals(Denominations.ETH);
            nativeDollarAmount = (nativeTokenAmount * nativePrice) / 10 ** 18; // nativeTokenAmount has 18 decimals
        }

        uint256 tokenAmountsLength = tokenAmounts.length;
        if (tokenAmountsLength == 1) {
            // @dev one single token provided
            uint256 tokenPrice = priceConsumer.tryGetSaneUsdPrice18Decimals(tokenAmounts[0].token);
            tokenSumDollarAmount =
                (tokenAmounts[0].amount * tokenPrice) /
                10 ** (IERC20Metadata(tokenAmounts[0].token).decimals());
        } else if (tokenAmountsLength > 1) {
            // @dev multiple tokens provided, batch price requests as a single external call
            address[] memory tokenAddresses = new address[](tokenAmountsLength);
            for (uint256 i = 0; i < tokenAmountsLength; i++) {
                tokenAddresses[i] = tokenAmounts[i].token;
            }
            uint256[] memory tokenPrices = priceConsumer.tryGetSaneUsdPrice18DecimalsBatch(tokenAddresses);
            for (uint256 i = 0; i < tokenAmountsLength; i++) {
                tokenSumDollarAmount +=
                    (tokenAmounts[i].amount * tokenPrices[i]) /
                    10 ** (IERC20Metadata(tokenAmounts[i].token).decimals());
            }
        }

        uint256 totalDollarInputAmount = nativeDollarAmount + tokenSumDollarAmount;

        uint256 lowerBound = (dollarAmount * (10000 - PRICE_DEVIATION_TOLERANCE_BPS)) / 10000;
        uint256 upperBound = (dollarAmount * (10000 + PRICE_DEVIATION_TOLERANCE_BPS)) / 10000;
        require(totalDollarInputAmount >= lowerBound, "RewardTimelock: reward dollar value too low");
        require(totalDollarInputAmount <= upperBound, "RewardTimelock: reward dollar value too high");
    }
}
