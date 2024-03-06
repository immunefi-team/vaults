// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { IERC20 } from "openzeppelin-contracts/interfaces/IERC20.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {
    SignatureCheckerUpgradeable
} from "openzeppelin-contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

import { Rewards } from "./common/Rewards.sol";
import { ArbitrationBase } from "./base/ArbitrationBase.sol";

/**
 * @title Arbitration
 * @author Immunefi
 * @notice A component which handles arbitration requests
 */
contract Arbitration is ArbitrationBase {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _owner Default admin role for the contract.
     * @param _module Address of the ImmunefiModule.
     * @param _rewardSystem Address of the RewardSystem.
     * @param _vaultDelegate Address of the VaultDelegate.
     * @param _feeToken Address of the fee token.
     * @param _feeAmount Amount of the fee.
     * @param _feeRecipient Address of the fee recipient.
     */
    function setUp(
        address _owner,
        address _module,
        address _rewardSystem,
        address _vaultDelegate,
        address _feeToken,
        uint256 _feeAmount,
        address _feeRecipient
    ) public initializer {
        __AccessControl_init();

        require(_owner != address(0), "Arbitration: owner cannot be 0x00");

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _setModule(_module);
        _setRewardSystem(_rewardSystem);
        _setVaultDelegate(_vaultDelegate);
        _setFeeToken(_feeToken);
        _setFeeAmount(_feeAmount);
        _setFeeRecipient(_feeRecipient);

        emit ArbitrationSetup(msg.sender, _owner);
    }

    /**
     * @notice Requests arbitration by whitehat
     * @dev Function caller must have approved feeAmount of feeToken
     * @dev Caller does not need to be the whitehat
     * @param referenceId Reference ID of the request.
     * @param vault The vault address
     * @param whitehat The whitehat address
     * @param signature The signature of the whitehat
     */
    function requestArbWhitehat(
        uint96 referenceId,
        address vault,
        address whitehat,
        bytes calldata signature
    ) external {
        bytes32 arbitrationId = computeArbitrationId(referenceId, vault, whitehat);
        require(arbData[arbitrationId].status == ArbitrationStatus.None, "Arbitration: arbitrationId already exists");

        uint256 _feeAmount = feeAmount; // gas optimization

        arbData[arbitrationId] = ArbitrationData({
            requestTimestamp: uint40(block.timestamp),
            vault: vault,
            referenceId: referenceId,
            whitehat: whitehat,
            status: ArbitrationStatus.Open
        });
        _addArbitrationIdToVault(vault, arbitrationId);

        bytes32 inputHash = keccak256(encodeRequestArbFromWhitehatData(referenceId, vault));
        require(
            SignatureCheckerUpgradeable.isValidSignatureNow(whitehat, inputHash, signature),
            "Arbitration: invalid request arbitration by whitehat signature"
        );

        emit ArbitrationRequestedByWhitehat(referenceId, vault, whitehat);

        if (_feeAmount > 0) {
            feeToken.safeTransferFrom(msg.sender, feeRecipient, _feeAmount);
        }
    }

    /**
     * @notice Requests arbitration by Vault
     * @dev Caller SHOULD be the Vault
     * @param referenceId Reference ID of the request.
     * @param whitehat The whitehat address
     */
    function requestArbVault(uint96 referenceId, address whitehat) external {
        bytes32 arbitrationId = computeArbitrationId(referenceId, msg.sender, whitehat);
        require(arbData[arbitrationId].status == ArbitrationStatus.None, "Arbitration: arbitrationId already exists");

        uint256 _feeAmount = feeAmount; // gas optimization

        arbData[arbitrationId] = ArbitrationData({
            requestTimestamp: uint40(block.timestamp),
            vault: msg.sender,
            whitehat: whitehat,
            referenceId: referenceId,
            status: ArbitrationStatus.Open
        });
        _addArbitrationIdToVault(msg.sender, arbitrationId);

        emit ArbitrationRequestedByVault(referenceId, msg.sender, whitehat);

        if (_feeAmount > 0) {
            uint256 initialBalance = feeToken.balanceOf(feeRecipient);
            immunefiModule.execute(
                msg.sender,
                address(vaultDelegate),
                0,
                abi.encodeCall(vaultDelegate.sendTokens, (address(feeToken), feeRecipient, _feeAmount)),
                Enum.Operation.DelegateCall
            );
            // @dev make sure the fee was transferred
            require(
                feeToken.balanceOf(feeRecipient) >= initialBalance + _feeAmount,
                "Arbitration: fee transfer failed"
            );
        }
    }

    /**
     * @notice Enforces a reward to the whitehat, and potentially closes arbitration.
     * @param arbitrationId Arbitration id.
     * @param tokenAmounts Array of ERC20Reward structs.
     * @param nativeTokenAmount Amount of native token to send.
     * @param gasToTarget The gas limit getting forwarded to the recipient address.
     * @param closeArb Whether to close the arbitration.
     */
    function enforceSendRewardWhitehat(
        bytes32 arbitrationId,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount,
        uint256 gasToTarget,
        bool closeArb
    ) external onlyRole(ARBITER_ROLE) {
        require(arbData[arbitrationId].status == ArbitrationStatus.Open, "Arbitration: arbitrationId arb not open");

        if (closeArb) {
            arbData[arbitrationId].status = ArbitrationStatus.Closed;
            emit ArbitrationClosed(arbitrationId);
        }

        address vault = arbData[arbitrationId].vault;
        address whitehat = arbData[arbitrationId].whitehat;

        if (tokenAmounts.length > 0 || nativeTokenAmount > 0) {
            // enforce reward
            rewardSystem.enforceSendReward(
                arbData[arbitrationId].referenceId,
                whitehat,
                tokenAmounts,
                nativeTokenAmount,
                vault,
                gasToTarget
            );
        }

        if (closeArb) {
            // remove last for enforceSendReward to be executed
            _removeArbitrationIdFromVault(vault, arbitrationId);
        }
    }

    /**
     * @notice Enforces a single reward with no fees to an allowed address, and potentially closes arbitration.
     * @param arbitrationId Arbitration id.
     * @param to The address of the recipient.
     * @param tokenAmounts Array of ERC20Reward structs.
     * @param nativeTokenAmount Amount of native token to send.
     * @param gasToTarget The gas limit getting forwarded to the recipient address.
     * @param closeArb Whether to close the arbitration.
     */
    function enforceSendRewardNoFees(
        bytes32 arbitrationId,
        address to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount,
        uint256 gasToTarget,
        bool closeArb
    ) external onlyRole(ARBITER_ROLE) {
        require(arbData[arbitrationId].status == ArbitrationStatus.Open, "Arbitration: arbitrationId arb not open");
        require(isArbitrationAllowedRecipient(arbitrationId, to), "Arbitration: recipient not allowed");

        if (closeArb) {
            arbData[arbitrationId].status = ArbitrationStatus.Closed;
            emit ArbitrationClosed(arbitrationId);
        }

        address vault = arbData[arbitrationId].vault;

        if (tokenAmounts.length > 0 || nativeTokenAmount > 0) {
            // enforce reward
            rewardSystem.enforceSendRewardNoFees(
                arbData[arbitrationId].referenceId,
                to,
                tokenAmounts,
                nativeTokenAmount,
                vault,
                gasToTarget
            );
        }

        if (closeArb) {
            // remove last for enforceSendReward to be executed
            _removeArbitrationIdFromVault(vault, arbitrationId);
        }
    }

    function enforceMultipleRewards(
        bytes32 arbitrationId,
        MultipleEnforcementElement[] calldata rewards,
        bool closeArb
    ) external onlyRole(ARBITER_ROLE) {
        require(arbData[arbitrationId].status == ArbitrationStatus.Open, "Arbitration: arbitrationId arb not open");

        if (closeArb) {
            arbData[arbitrationId].status = ArbitrationStatus.Closed;
            emit ArbitrationClosed(arbitrationId);
        }

        address vault = arbData[arbitrationId].vault;
        uint96 referenceId = arbData[arbitrationId].referenceId;
        uint256 rewardsLength = rewards.length;

        // @dev loop through the different reward values
        for (uint256 i = 0; i < rewardsLength; i++) {
            require(
                isArbitrationAllowedRecipient(arbitrationId, rewards[i].recipient),
                "Arbitration: recipient not allowed"
            );
            if (rewards[i].tokenAmounts.length > 0 || rewards[i].nativeTokenAmount > 0) {
                // enforce reward
                if (rewards[i].withFees) {
                    rewardSystem.enforceSendReward(
                        referenceId,
                        rewards[i].recipient,
                        rewards[i].tokenAmounts,
                        rewards[i].nativeTokenAmount,
                        vault,
                        rewards[i].gasToTarget
                    );
                } else {
                    rewardSystem.enforceSendRewardNoFees(
                        referenceId,
                        rewards[i].recipient,
                        rewards[i].tokenAmounts,
                        rewards[i].nativeTokenAmount,
                        vault,
                        rewards[i].gasToTarget
                    );
                }
            }
        }

        if (closeArb) {
            // remove last for enforceSendReward to be executed
            _removeArbitrationIdFromVault(vault, arbitrationId);
        }
    }

    /**
     * @notice Closes arbitration.
     * @param arbitrationId Arbitration id.
     */
    function closeArbitration(bytes32 arbitrationId) external onlyRole(ARBITER_ROLE) {
        require(arbData[arbitrationId].status == ArbitrationStatus.Open, "Arbitration: arbitrationId arb not open");

        arbData[arbitrationId].status = ArbitrationStatus.Closed;
        emit ArbitrationClosed(arbitrationId);

        address vault = arbData[arbitrationId].vault;
        _removeArbitrationIdFromVault(vault, arbitrationId);
    }

    /**
     * @notice Adds an arbitration id to a vault.
     * @param vault Address of the vault.
     * @param arbitrationId Arbitration id.
     */
    function _addArbitrationIdToVault(address vault, bytes32 arbitrationId) internal {
        vaultsOngoingArbitrations[vault].add(arbitrationId);
        if (timeSinceOngoingArbitration[vault] == 0) {
            timeSinceOngoingArbitration[vault] = uint40(block.timestamp);
        }
    }

    /**
     * @notice Removes an arbitration id from a vault.
     * @param vault Address of the vault.
     * @param arbitrationId Arbitration id.
     */
    function _removeArbitrationIdFromVault(address vault, bytes32 arbitrationId) internal {
        vaultsOngoingArbitrations[vault].remove(arbitrationId);
        if (!vaultIsInArbitration(vault)) {
            timeSinceOngoingArbitration[vault] = 0;
        }
    }
}
