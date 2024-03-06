// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { SecuredTokenTransfer } from "@gnosis.pm/safe-contracts/contracts/common/SecuredTokenTransfer.sol";
import { Rewards } from "./common/Rewards.sol";
import { WithdrawalSystemBase } from "./base/WithdrawalSystemBase.sol";

/**
 * @title WithdrawalSystem
 * @author Immunefi
 * @notice A component to help craft withdrawal operations for the Timelock
 */
contract WithdrawalSystem is WithdrawalSystemBase, SecuredTokenTransfer {
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _owner Owner of the contract
     * @param _timelock Address of the Timelock
     * @param _vaultDelegate Address of the VaultDelegate
     * @param _txCooldown The cooldown period for withdrawals
     * @param _txExpiration The expiration period for timelocked withdrawals
     */
    function setUp(
        address _owner,
        address _timelock,
        address _vaultDelegate,
        uint256 _txCooldown,
        uint256 _txExpiration
    ) public initializer {
        __Ownable_init();

        _setTimelock(_timelock);
        _setVaultDelegate(_vaultDelegate);
        _setTxCooldown(uint32(_txCooldown));
        _setTxExpiration(_txExpiration);
        transferOwnership(_owner);

        emit WithdrawalSystemSetup(msg.sender, _owner);
    }

    /**
     * @notice Returns the hash of a withdrawal operation.
     * @param to The address of the recipient.
     * @param tokenAmounts The amounts of tokens to send.
     * @param nativeTokenAmount The amount of native tokens to send.
     * @param vault The address of the vault.
     * @param nonce The nonce to be used for the hash.
     */
    function getWithdrawalHash(
        address payable to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount,
        address vault,
        uint256 nonce
    ) external view returns (bytes32) {
        bytes memory data = abi.encodeCall(vaultDelegate.withdrawFunds, (to, tokenAmounts, nativeTokenAmount));
        return
            timelock.getQueueTransactionHash(
                address(vaultDelegate),
                0,
                data,
                Enum.Operation.DelegateCall,
                vault,
                nonce
            );
    }

    /**
     * @notice Queues a withdrawal operation to be executed by the timelock.
     * @param to The address of the recipient.
     * @param tokenAmounts The amounts of tokens to send.
     * @param nativeTokenAmount The amount of native tokens to send.
     */
    function queueVaultWithdrawal(
        address payable to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount
    ) external {
        bytes memory data = abi.encodeCall(vaultDelegate.withdrawFunds, (to, tokenAmounts, nativeTokenAmount));
        timelock.queueTransaction(
            address(vaultDelegate),
            0,
            data,
            Enum.Operation.DelegateCall,
            msg.sender,
            txCooldown,
            txExpiration
        );
    }
}
