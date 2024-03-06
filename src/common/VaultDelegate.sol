// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { SecuredTokenTransfer } from "@gnosis.pm/safe-contracts/contracts/common/SecuredTokenTransfer.sol";
import { Rewards } from "./Rewards.sol";
import { VaultFees } from "./VaultFees.sol";

/**
 * @title VaultDelegate
 * @author Immunefi
 * @dev This contract provides functionality for vaults to delegate to.
 * @dev This contract has no storage variables.
 * @dev Any dust falling into the contract for some reason can be withdrawn by anyone.
 */
contract VaultDelegate is SecuredTokenTransfer {
    uint256 public constant UNTRUSTED_TARGET_GAS_CAP = 50_000;
    VaultFees public immutable vaultFees;

    event RewardSent(
        address indexed vault,
        uint96 indexed referenceId,
        address indexed to,
        Rewards.ERC20Reward[] tokenAmounts,
        uint256 nativeTokenAmount,
        address feeRecipient,
        uint256 fee
    );

    event RewardSentNoFees(
        address indexed vault,
        uint96 indexed referenceId,
        address indexed to,
        Rewards.ERC20Reward[] tokenAmounts,
        uint256 nativeTokenAmount
    );

    event TokensSent(address indexed vault, address indexed to, address indexed token, uint256 amount);

    event Withdrawal(
        address indexed vault,
        address indexed to,
        Rewards.ERC20Reward[] tokenAmounts,
        uint256 nativeTokenAmount
    );

    constructor(address _vaultFees) {
        require(_vaultFees != address(0), "VaultDelegate: vaultFees cannot be 0x00");
        vaultFees = VaultFees(_vaultFees);
    }

    /**
     * @notice Sends tokens from the vault
     * @dev This function is to be called by the vault with delegatecall
     */
    function sendTokens(address token, address to, uint256 amount) external {
        emit TokensSent(address(this), to, token, amount);
        require(transferToken(token, to, amount), "Arbitration: token transfer failed");
    }

    /**
     * @notice Sends reward. Fees get applied.
     * @dev This function is to be called by the vault with delegatecall
     */
    function sendReward(
        uint96 referenceId,
        address to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount,
        uint256 gasToTarget
    ) external {
        require(gasToTarget <= UNTRUSTED_TARGET_GAS_CAP, "VaultDelegate: gasToTarget greater than max allowed");
        (uint16 feeBps, address feeRecipient) = vaultFees.getFee(address(this));
        uint256 feeBasis = vaultFees.FEE_BASIS();

        // checks on inputs were done when building tx
        emit RewardSent(address(this), referenceId, to, tokenAmounts, nativeTokenAmount, feeRecipient, feeBps);

        uint256 length = tokenAmounts.length;
        for (uint256 i = 0; i < length; i++) {
            if (tokenAmounts[i].amount == 0) {
                continue;
            }
            uint256 tokenFee = (tokenAmounts[i].amount * feeBps) / feeBasis;
            if (tokenFee > 0) {
                require(
                    transferToken(tokenAmounts[i].token, feeRecipient, tokenFee),
                    "VaultDelegate: token transfer to fee recipient failed"
                );
            }
            require(
                transferToken(tokenAmounts[i].token, to, tokenAmounts[i].amount),
                "VaultDelegate: token transfer failed"
            );
        }

        if (nativeTokenAmount == 0) {
            return;
        }

        uint256 nativeTokenFee = (nativeTokenAmount * feeBps) / feeBasis;
        if (nativeTokenFee > 0) {
            // feeRecipient is trusted, we can skip this check
            // slither-disable-next-line arbitrary-send-eth,low-level-calls
            (bool successFee, ) = feeRecipient.call{ value: nativeTokenFee }("");
            require(successFee, "VaultDelegate: Failed to send ether to fee receiver");
        }

        // slither-disable-next-line arbitrary-send-eth,low-level-calls
        (bool success, ) = to.call{ value: nativeTokenAmount, gas: gasToTarget }("");
        require(success, "VaultDelegate: Failed to send native token");
    }

    /**
     * @notice Sends reward. Fees DON'T get applied.
     * @dev This function is to be called by the vault with delegatecall
     */
    function sendRewardNoFees(
        uint96 referenceId,
        address to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount,
        uint256 gasToTarget
    ) external {
        require(gasToTarget <= UNTRUSTED_TARGET_GAS_CAP, "VaultDelegate: gasToTarget greater than max allowed");

        // checks on inputs were done when building tx
        emit RewardSentNoFees(address(this), referenceId, to, tokenAmounts, nativeTokenAmount);

        uint256 length = tokenAmounts.length;
        for (uint256 i = 0; i < length; i++) {
            if (tokenAmounts[i].amount == 0) {
                continue;
            }
            require(
                transferToken(tokenAmounts[i].token, to, tokenAmounts[i].amount),
                "VaultDelegate: token transfer failed"
            );
        }

        if (nativeTokenAmount == 0) {
            return;
        }
        // slither-disable-next-line arbitrary-send-eth,low-level-calls
        (bool success, ) = to.call{ value: nativeTokenAmount, gas: gasToTarget }("");
        require(success, "VaultDelegate: Failed to send native token");
    }

    /**
     * @notice Withdraws funds from the vault
     * @dev This function is to be called by the vault with delegatecall
     */
    function withdrawFunds(
        address to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount
    ) external {
        require(to != address(0), "WithdrawalSystem: to cannot be 0x00");

        emit Withdrawal(address(this), to, tokenAmounts, nativeTokenAmount);

        uint256 length = tokenAmounts.length;
        for (uint256 i = 0; i < length; i++) {
            if (tokenAmounts[i].amount == 0) {
                continue;
            }
            require(
                transferToken(tokenAmounts[i].token, to, tokenAmounts[i].amount),
                "WithdrawalSystem: token transfer failed"
            );
        }

        if (nativeTokenAmount == 0) {
            return;
        }

        // slither-disable-next-line arbitrary-send-eth,low-level-calls
        (bool success, ) = to.call{ value: nativeTokenAmount }("");
        require(success, "WithdrawalSystem: Failed to send native token");
    }
}
