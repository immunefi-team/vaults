// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { BaseGuard } from "@gnosis.pm/zodiac/contracts/guard/BaseGuard.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { IScopeGuardEvents } from "../events/IScopeGuardEvents.sol";

/**
 * @title ScopeGuard
 * @author Immunefi
 * @notice Scope Guard from Zodiac with some modifications
 * @dev https://github.com/gnosis/zodiac-guard-scope/blob/main/contracts/ScopeGuard.sol
 */
contract ScopeGuard is OwnableUpgradeable, BaseGuard, IScopeGuardEvents {
    struct Target {
        bool allowed;
        bool scoped;
        bool delegateCallAllowed;
        bool fallbackAllowed;
        bool valueAllowed;
        mapping(bytes4 => bool) allowedFunctions;
    }

    mapping(address => Target) public allowedTargets;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _owner Owner of the contract
     */
    function setUp(address _owner) public initializer {
        __Ownable_init();

        require(_owner != address(0), "ScopeGuard: owner is the zero address");
        _transferOwnership(_owner);

        emit ScopeGuardSetup(msg.sender, _owner);
    }

    /**
     * @notice Sets whether or not calls can be made to an address.
     * @param target Address to be allowed/disallowed.
     * @param allow Bool to allow (true) or disallow (false) calls to target.
     */
    function setTargetAllowed(address target, bool allow) public onlyOwner {
        allowedTargets[target].allowed = allow;
        emit SetTargetAllowed(target, allow);
    }

    /**
     * @notice Sets whether or not delegate calls can be made to a target.
     * @param target Address to which delegate calls should be allowed/disallowed.
     * @param allow Bool to allow (true) or disallow (false) delegate calls to target.
     */
    function setDelegateCallAllowedOnTarget(address target, bool allow) public onlyOwner {
        allowedTargets[target].delegateCallAllowed = allow;
        emit SetDelegateCallAllowedOnTarget(target, allow);
    }

    /**
     * @notice Sets whether or not calls to an address should be scoped to specific function signatures.
     * @param target Address to be scoped/unscoped.
     * @param scoped Bool to scope (true) or unscope (false) function calls on target.
     */
    function setScoped(address target, bool scoped) public onlyOwner {
        allowedTargets[target].scoped = scoped;
        emit SetTargetScoped(target, scoped);
    }

    /**
     * @notice Sets whether or not a target can be sent to (includes fallback/receive functions).
     * @param target Address to be allow/disallow sends to.
     * @param allow Bool to allow (true) or disallow (false) sends on target.
     */
    function setFallbackAllowedOnTarget(address target, bool allow) public onlyOwner {
        allowedTargets[target].fallbackAllowed = allow;
        emit SetFallbackAllowedOnTarget(target, allow);
    }

    /**
     * @notice Sets whether or not ETH can be sent to a target.
     * @param target Address to be allow/disallow sends to.
     * @param allow Bool to allow (true) or disallow (false) sends on target.
     */
    function setValueAllowedOnTarget(address target, bool allow) public onlyOwner {
        allowedTargets[target].valueAllowed = allow;
        emit SetValueAllowedOnTarget(target, allow);
    }

    /**
     * @notice Sets whether or not a specific function signature should be allowed on a scoped target.
     * @param target Scoped address on which a function signature should be allowed/disallowed.
     * @param functionSig Function signature to be allowed/disallowed.
     * @param allow Bool to allow (true) or disallow (false) calls a function signature on target.
     */
    function setAllowedFunction(address target, bytes4 functionSig, bool allow) public onlyOwner {
        allowedTargets[target].allowedFunctions[functionSig] = allow;
        emit SetFunctionAllowedOnTarget(target, functionSig, allow);
    }

    function isAllowedTarget(address target) public view returns (bool) {
        return (allowedTargets[target].allowed);
    }

    function isScoped(address target) public view returns (bool) {
        return (allowedTargets[target].scoped);
    }

    function isfallbackAllowed(address target) public view returns (bool) {
        return (allowedTargets[target].fallbackAllowed);
    }

    function isValueAllowed(address target) public view returns (bool) {
        return (allowedTargets[target].valueAllowed);
    }

    function isAllowedFunction(address target, bytes4 functionSig) public view returns (bool) {
        return (allowedTargets[target].allowedFunctions[functionSig]);
    }

    function isAllowedToDelegateCall(address target) public view returns (bool) {
        return (allowedTargets[target].delegateCallAllowed);
    }

    // solhint-disable-next-line payable-fallback
    fallback() external {
        // We don't revert on fallback to avoid issues in case of a Safe upgrade
        // E.g. The expected check method might change and then the Safe would be locked.
    }

    /**
     * @notice Checks a transaction before execution.
     * @param to Destination address of vault transaction.
     * @param value Ether value of vault transaction.
     * @param data Data payload of vault transaction.
     * @param operation Operation type for avatar execution.
     */
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        // solhint-disable-next-line no-unused-vars
        address payable,
        bytes memory,
        address
    ) public view virtual override {
        require(
            operation != Enum.Operation.DelegateCall || allowedTargets[to].delegateCallAllowed,
            "Delegate call not allowed to this address"
        );
        require(allowedTargets[to].allowed, "Target address is not allowed");
        if (value > 0) {
            require(allowedTargets[to].valueAllowed, "Cannot send ETH to this target");
        }
        if (data.length >= 4) {
            require(
                !allowedTargets[to].scoped || allowedTargets[to].allowedFunctions[bytes4(data)],
                "Target function is not allowed"
            );
        } else {
            require(data.length == 0, "Function signature too short");
            require(
                !allowedTargets[to].scoped || allowedTargets[to].fallbackAllowed,
                "Fallback not allowed for this address"
            );
        }
    }

    /**
     * @notice Checks a transaction after execution.
     */
    function checkAfterExecution(bytes32, bool) external view virtual override {}
}
