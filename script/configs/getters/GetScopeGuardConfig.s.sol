// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/guards/ScopeGuard.sol";
import "../../../src/common/VaultDelegate.sol";

contract GetScopeGuardConfig is BaseScript {
    function run() external view {
        address vaultDelegateAddress = vm.envAddress("VAULT_DELEGATE");
        address scopeGuardAddress = vm.envAddress("SCOPE_GUARD");

        ScopeGuard scopeGuard = ScopeGuard(scopeGuardAddress);

        console.log("vaultDelegate allowed: %s", scopeGuard.isAllowedTarget(vaultDelegateAddress));
        console.log(
            "vaultDelegate.withdrawFunds allowed: %s",
            scopeGuard.isAllowedFunction(vaultDelegateAddress, VaultDelegate.withdrawFunds.selector)
        );
        console.log(
            "vaultDelegate.sendReward allowed: %s",
            scopeGuard.isAllowedFunction(vaultDelegateAddress, VaultDelegate.sendReward.selector)
        );
        console.log(
            "vaultDelegate.sendTokens allowed: %s",
            scopeGuard.isAllowedFunction(vaultDelegateAddress, VaultDelegate.sendTokens.selector)
        );
        console.log("vaultDelegate scoped: %s", scopeGuard.isScoped(vaultDelegateAddress));
        console.log("vaultDelegate delegatecall allowed: %s", scopeGuard.isAllowedToDelegateCall(vaultDelegateAddress));
    }
}
