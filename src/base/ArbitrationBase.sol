// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { IERC20 } from "openzeppelin-contracts/interfaces/IERC20.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ArbitrationOperationEncoder } from "../encoders/ArbitrationOperationEncoder.sol";
import { IArbitrationEvents } from "../events/IArbitrationEvents.sol";
import { ImmunefiModule } from "../ImmunefiModule.sol";
import { RewardSystem } from "../RewardSystem.sol";
import { VaultDelegate } from "../common/VaultDelegate.sol";
import { Rewards } from "../common/Rewards.sol";

/**
 * @title ArbitrationBase
 * @author Immunefi
 * @notice Base contract for the Arbitration component
 * @dev Includes variable declaration and setter functions
 */
abstract contract ArbitrationBase is AccessControlUpgradeable, ArbitrationOperationEncoder, IArbitrationEvents {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public constant ARBITER_ROLE = keccak256("arbitration.arbiter.role");
    bytes32 public constant ALLOWED_RECIPIENT_ROLE = keccak256("arbitration.allowed.recipient.role");

    enum ArbitrationStatus {
        None,
        Open,
        Closed
    }

    struct ArbitrationData {
        uint40 requestTimestamp;
        ArbitrationStatus status;
        address vault;
        uint96 referenceId;
        address whitehat;
    }

    struct MultipleEnforcementElement {
        bool withFees;
        address recipient;
        Rewards.ERC20Reward[] tokenAmounts;
        uint256 nativeTokenAmount;
        uint256 gasToTarget;
    }

    ImmunefiModule public immunefiModule;
    RewardSystem public rewardSystem;
    VaultDelegate public vaultDelegate;
    IERC20 public feeToken;
    uint256 public feeAmount;
    address public feeRecipient;

    mapping(bytes32 => ArbitrationData) public arbData;
    mapping(address => EnumerableSet.Bytes32Set) internal vaultsOngoingArbitrations;
    // @dev time since a vault is in arbitration. Resets to 0 when no longer in arbitration.
    mapping(address => uint40) public timeSinceOngoingArbitration;

    /**
     * @notice Sets the module contract
     * @param newModule Address of the new module contract
     */
    function setModule(address newModule) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setModule(newModule);
        emit ModuleSet(newModule);
    }

    function _setModule(address newModule) internal {
        require(newModule != address(0), "ArbitrationBase: module cannot be 0x00");
        immunefiModule = ImmunefiModule(newModule);
    }

    /**
     * @notice Sets the RewardSystem contract
     * @param newRewardSystem Address of the new RewardSystem contract
     */
    function setRewardSystem(address newRewardSystem) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRewardSystem(newRewardSystem);
        emit RewardSystemSet(newRewardSystem);
    }

    function _setRewardSystem(address newRewardSystem) internal {
        require(newRewardSystem != address(0), "ArbitrationBase: rewardSystem cannot be 0x00");
        rewardSystem = RewardSystem(newRewardSystem);
    }

    /**
     * @notice Sets vault delegate
     * @param newVaultDelegate Address of the new vault delegate
     */
    function setVaultDelegate(address newVaultDelegate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setVaultDelegate(newVaultDelegate);
        emit VaultDelegateSet(newVaultDelegate);
    }

    function _setVaultDelegate(address newVaultDelegate) internal {
        require(newVaultDelegate != address(0), "ArbitrationBase: vaultDelegate cannot be 0x00");
        vaultDelegate = VaultDelegate(newVaultDelegate);
    }

    /**
     * @notice Sets the token address to be used for fees
     * @param newFeeToken Address of the new fee token
     */
    function setFeeToken(address newFeeToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFeeToken(newFeeToken);
        emit FeeTokenSet(newFeeToken);
    }

    function _setFeeToken(address newFeeToken) internal {
        require(newFeeToken != address(0), "ArbitrationBase: feeToken cannot be 0x00");
        feeToken = IERC20(newFeeToken);
    }

    /**
     * @notice Sets the fee amount
     * @param newFeeAmount Amount of the new fee
     */
    function setFeeAmount(uint256 newFeeAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFeeAmount(newFeeAmount);
        emit FeeAmountSet(newFeeAmount);
    }

    function _setFeeAmount(uint256 newFeeAmount) internal {
        feeAmount = newFeeAmount;
    }

    /**
     * @notice Sets the fee recipient
     * @param newFeeRecipient Address of the new fee recipient
     */
    function setFeeRecipient(address newFeeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit FeeRecipientSet(newFeeRecipient);
        _setFeeRecipient(newFeeRecipient);
    }

    function _setFeeRecipient(address newFeeRecipient) internal {
        require(newFeeRecipient != address(0), "ArbitrationBase: feeRecipient cannot be 0x00");
        feeRecipient = newFeeRecipient;
    }

    function vaultOngoingArbitrations(address vault) external view returns (bytes32[] memory) {
        return vaultsOngoingArbitrations[vault].values();
    }

    function vaultIsInArbitration(address vault) public view returns (bool) {
        return vaultsOngoingArbitrations[vault].length() != 0;
    }

    function isGloballyAllowedRecipient(address recipient) external view returns (bool) {
        return recipient == feeRecipient || hasRole(ALLOWED_RECIPIENT_ROLE, recipient);
    }

    function isArbitrationAllowedRecipient(bytes32 arbitrationId, address recipient) public view returns (bool) {
        return
            recipient == feeRecipient ||
            hasRole(ALLOWED_RECIPIENT_ROLE, recipient) ||
            (recipient != address(0) && arbData[arbitrationId].whitehat == recipient);
    }
}
