// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/guards/ScopeGuard.sol";
import "../../../src/common/VaultDelegate.sol";

contract SetScopeGuardAccesses is BaseScript {
    function run() public virtual broadcaster returns (address scopeGuardAddress) {
        address vaultDelegateAddress = vm.envAddress("VAULT_DELEGATE");
        scopeGuardAddress = vm.envAddress("SCOPE_GUARD");
        ScopeGuard scopeGuard = ScopeGuard(scopeGuardAddress);

        scopeGuard.setTargetAllowed(vaultDelegateAddress, true);
        scopeGuard.setAllowedFunction(vaultDelegateAddress, VaultDelegate.withdrawFunds.selector, true);
        scopeGuard.setAllowedFunction(vaultDelegateAddress, VaultDelegate.sendReward.selector, true);
        scopeGuard.setAllowedFunction(vaultDelegateAddress, VaultDelegate.sendTokens.selector, true);
        scopeGuard.setDelegateCallAllowedOnTarget(vaultDelegateAddress, true);
        scopeGuard.setScoped(vaultDelegateAddress, true);
    }
}
