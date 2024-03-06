// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../RewardSystem/DeployRewardSystem.s.sol";
import "../DeployProxyAdmin.s.sol";
import "../DeployEmergencySystem.s.sol";
import "../ImmunefiGuard/DeployImmunefiGuard.s.sol";
import "../ImmunefiModule/DeployImmunefiModule.s.sol";
import "../ScopeGuard/DeployScopeGuard.s.sol";
import "../DeployVaultDelegate.s.sol";
import "../DeployVaultSetup.s.sol";
import "../VaultFreezer/DeployVaultFreezer.s.sol";
import "../Timelock/DeployTimelock.s.sol";
import "../WithdrawalSystem/DeployWithdrawalSystem.s.sol";
import "../Arbitration/DeployArbitration.s.sol";

import "../../configs/setters/SetImmunefiGuardAccesses.s.sol";
import "../../configs/setters/SetScopeGuardAccesses.s.sol";
import "../../configs/setters/SetImmunefiModuleGuard.s.sol";
import "../../configs/setters/GrantEnforcerRoles.s.sol";
import "../../configs/setters/GrantExecutorRoles.s.sol";
import "../../configs/setters/GrantQueuerRoles.s.sol";

contract DeployProtocol is
    DeployRewardSystem,
    DeployProxyAdmin,
    DeployEmergencySystem,
    DeployImmunefiGuard,
    DeployImmunefiModule,
    DeployScopeGuard,
    DeployVaultDelegate,
    DeployVaultSetup,
    DeployVaultFreezer,
    DeployTimelock,
    DeployWithdrawalSystem,
    DeployArbitration,
    SetImmunefiGuardAccesses,
    SetScopeGuardAccesses,
    SetImmunefiModuleGuard,
    GrantEnforcerRoles,
    GrantExecutorRoles,
    GrantQueuerRoles
{
    function run()
        public
        virtual
        override(
            DeployRewardSystem,
            DeployProxyAdmin,
            DeployEmergencySystem,
            DeployImmunefiGuard,
            DeployImmunefiModule,
            DeployScopeGuard,
            DeployVaultDelegate,
            DeployVaultSetup,
            DeployVaultFreezer,
            DeployTimelock,
            DeployWithdrawalSystem,
            DeployArbitration,
            SetImmunefiGuardAccesses,
            SetScopeGuardAccesses,
            SetImmunefiModuleGuard,
            GrantEnforcerRoles,
            GrantExecutorRoles,
            GrantQueuerRoles
        )
        returns (address)
    {
        /**
         * Deploy Protocol
         */

        {
            address proxyAdmin = DeployProxyAdmin.run();
            vm.setEnv("PROXY_ADMIN", vm.toString(proxyAdmin));
        }

        {
            address emergencySystem = DeployEmergencySystem.run();
            vm.setEnv("EMERGENCY_SYSTEM", vm.toString(emergencySystem));
        }

        {
            address immunefiGuard = DeployImmunefiGuard.run();
            vm.setEnv("IMMUNEFI_GUARD", vm.toString(immunefiGuard));
        }

        {
            address module = DeployImmunefiModule.run();
            vm.setEnv("IMMUNEFI_MODULE", vm.toString(module));
        }

        {
            address scopeGuard = DeployScopeGuard.run();
            vm.setEnv("SCOPE_GUARD", vm.toString(scopeGuard));
        }

        {
            address vaultDelegate = DeployVaultDelegate.run();
            vm.setEnv("VAULT_DELEGATE", vm.toString(vaultDelegate));
        }

        {
            address rewardSystem = DeployRewardSystem.run();
            vm.setEnv("REWARD_SYSTEM", vm.toString(rewardSystem));
        }

        DeployVaultSetup.run();

        {
            address vaultFreezer = DeployVaultFreezer.run();
            vm.setEnv("VAULT_FREEZER", vm.toString(vaultFreezer));
        }

        {
            address timelock = DeployTimelock.run();
            vm.setEnv("TIMELOCK", vm.toString(timelock));
        }

        {
            address withdrawalSystem = DeployWithdrawalSystem.run();
            vm.setEnv("WITHDRAWAL_SYSTEM", vm.toString(withdrawalSystem));
        }

        {
            address arbitration = DeployArbitration.run();
            vm.setEnv("ARBITRATION", vm.toString(arbitration));
        }

        /**
         * Configure Protocol
         */

        // set immunefiGuard accesses
        SetImmunefiGuardAccesses.run();

        // set scopeGuard accesses
        SetScopeGuardAccesses.run();

        // set immunefiModule guard
        SetImmunefiModuleGuard.run();

        // grant arbitration enforcer roles
        GrantEnforcerRoles.run();

        // grant module executor roles
        GrantExecutorRoles.run();

        // grant timelock queuer roles
        GrantQueuerRoles.run();

        return vm.envAddress("ARBITRATION");
    }
}
