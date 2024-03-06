// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import { Rewards } from "./common/Rewards.sol";
import { RewardSystemBase } from "./base/RewardSystemBase.sol";

/**
 * @title RewardSystem
 * @author Immunefi
 * @notice A component to enable sending rewards
 */
contract RewardSystem is RewardSystemBase {
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _owner Default admin role recipient
     * @param _module Address of the ImmunefiModule
     * @param _vaultDelegate Address of the VaultDelegate
     * @param _arbitration Address of the Arbitration
     * @param _vaultFreezer Address of the VaultFreezer
     */
    function setUp(
        address _owner,
        address _module,
        address _vaultDelegate,
        address _arbitration,
        address _vaultFreezer
    ) public initializer {
        __AccessControl_init();

        require(_owner != address(0), "RewardSystem: owner cannot be 0x00");

        _setModule(_module);
        _setVaultDelegate(_vaultDelegate);
        _setArbitration(_arbitration);
        _setVaultFreezer(_vaultFreezer);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        emit RewardSystemSetup(msg.sender, _owner);
    }

    /**
     * @notice Enforces sendReward on a vault.
     * @param referenceId The reference id of the report.
     * @param to The address of the recipient.
     * @param tokenAmounts The amounts of tokens to send.
     * @param nativeTokenAmount The amount of native tokens to send.
     * @param vault The address of the vault.
     * @param gasToTarget The gas limit getting forwarded to the `to` address.
     */
    function enforceSendReward(
        uint96 referenceId,
        address to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount,
        address vault,
        uint256 gasToTarget
    ) external onlyRole(ENFORCER_ROLE) {
        require(to != address(0), "RewardSystem: to cannot be 0x00");
        require(arbitration.vaultIsInArbitration(vault), "RewardSystem: vault is not in arbitration");

        bytes memory data = abi.encodeCall(
            vaultDelegate.sendReward,
            (referenceId, to, tokenAmounts, nativeTokenAmount, gasToTarget)
        );

        immunefiModule.execute(vault, address(vaultDelegate), 0, data, Enum.Operation.DelegateCall);
    }

    /**
     * @notice Enforces sendRewardNoFees on a vault.
     * @param referenceId The reference id of the report.
     * @param to The address of the recipient.
     * @param tokenAmounts The amounts of tokens to send.
     * @param nativeTokenAmount The amount of native tokens to send.
     * @param vault The address of the vault.
     * @param gasToTarget The gas limit getting forwarded to the `to` address.
     */
    function enforceSendRewardNoFees(
        uint96 referenceId,
        address to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount,
        address vault,
        uint256 gasToTarget
    ) external onlyRole(ENFORCER_ROLE) {
        require(to != address(0), "RewardSystem: to cannot be 0x00");
        require(arbitration.vaultIsInArbitration(vault), "RewardSystem: vault is not in arbitration");

        bytes memory data = abi.encodeCall(
            vaultDelegate.sendRewardNoFees,
            (referenceId, to, tokenAmounts, nativeTokenAmount, gasToTarget)
        );

        immunefiModule.execute(vault, address(vaultDelegate), 0, data, Enum.Operation.DelegateCall);
    }

    /**
     * @notice Sends reward. Callable by the vault itself.
     * @param referenceId The reference id of the report.
     * @param to The address of the recipient.
     * @param tokenAmounts The amounts of tokens to send.
     * @param nativeTokenAmount The amount of native tokens to send.
     * @param gasToTarget The gas limit getting forwarded to the `to` address.
     */
    function sendRewardByVault(
        uint96 referenceId,
        address to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount,
        uint256 gasToTarget
    ) external {
        require(to != address(0), "RewardSystem: to cannot be 0x00");
        require(!vaultFreezer.isFrozen(msg.sender), "RewardSystem: vault is frozen");
        require(!arbitration.vaultIsInArbitration(msg.sender), "RewardSystem: vault is in arbitration");

        bytes memory data = abi.encodeCall(
            vaultDelegate.sendReward,
            (referenceId, to, tokenAmounts, nativeTokenAmount, gasToTarget)
        );

        immunefiModule.execute(msg.sender, address(vaultDelegate), 0, data, Enum.Operation.DelegateCall);
    }
}
