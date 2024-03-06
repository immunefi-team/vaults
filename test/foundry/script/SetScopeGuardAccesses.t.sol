// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { DeployProxyAdmin } from "../../../script/deployers/DeployProxyAdmin.s.sol";
import { DeployScopeGuard } from "../../../script/deployers/ScopeGuard/DeployScopeGuard.s.sol";
import { SetScopeGuardAccesses } from "../../../script/configs/setters/SetScopeGuardAccesses.s.sol";
import { ScopeGuard } from "../../../src/guards/ScopeGuard.sol";
import { VaultDelegate } from "../../../src/common/VaultDelegate.sol";

contract SetScopeGuardAccessesTest is Test {
    // solhint-disable state-visibility
    address scopeGuard;
    address vaultDelegate;

    function setUp() public {
        vm.setEnv("MNEMONIC", "test test test test test test test test test test test junk");
        (address deployer, ) = deriveRememberKey({ mnemonic: vm.envString("MNEMONIC"), index: 0 });
        vm.setEnv("PROTOCOL_OWNER", vm.toString(deployer));

        address proxyAdmin = new DeployProxyAdmin().run();
        vm.setEnv("PROXY_ADMIN", vm.toString(proxyAdmin));

        vm.setEnv("EMERGENCY_SYSTEM", vm.toString(makeAddr("EmergencySystem")));

        vaultDelegate = makeAddr("VaultDelegate");
        vm.setEnv("VAULT_DELEGATE", vm.toString(vaultDelegate));

        scopeGuard = new DeployScopeGuard().run();
    }

    function testSetScopeGuardAccessesSucceeds() public {
        ScopeGuard guard = ScopeGuard(scopeGuard);

        /***
         * scopeGuard.setTargetAllowed(vaultDelegateAddress, true);
        scopeGuard.setAllowedFunction(vaultDelegateAddress, VaultDelegate.withdrawFunds.selector, true);
        scopeGuard.setAllowedFunction(vaultDelegateAddress, VaultDelegate.sendReward.selector, true);
        scopeGuard.setAllowedFunction(vaultDelegateAddress, VaultDelegate.sendTokens.selector, true);
        scopeGuard.setDelegateCallAllowedOnTarget(vaultDelegateAddress, true);
        scopeGuard.setScoped(vaultDelegateAddress, true);
         */

        assertFalse(guard.isAllowedTarget(vaultDelegate));
        assertFalse(guard.isScoped(vaultDelegate));
        assertFalse(guard.isAllowedFunction(vaultDelegate, VaultDelegate.withdrawFunds.selector));
        assertFalse(guard.isAllowedFunction(vaultDelegate, VaultDelegate.sendReward.selector));
        assertFalse(guard.isAllowedFunction(vaultDelegate, VaultDelegate.sendTokens.selector));
        assertFalse(guard.isAllowedToDelegateCall(vaultDelegate));

        // Run script
        vm.setEnv("SCOPE_GUARD", vm.toString(scopeGuard));
        new SetScopeGuardAccesses().run();

        assertTrue(guard.isAllowedTarget(vaultDelegate));
        assertTrue(guard.isScoped(vaultDelegate));
        assertTrue(guard.isAllowedFunction(vaultDelegate, VaultDelegate.withdrawFunds.selector));
        assertTrue(guard.isAllowedFunction(vaultDelegate, VaultDelegate.sendReward.selector));
        assertTrue(guard.isAllowedFunction(vaultDelegate, VaultDelegate.sendTokens.selector));
        assertTrue(guard.isAllowedToDelegateCall(vaultDelegate));
    }
}
