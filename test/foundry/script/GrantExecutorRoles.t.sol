// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { DeployProxyAdmin } from "../../../script/deployers/DeployProxyAdmin.s.sol";
import { DeployEmergencySystem } from "../../../script/deployers/DeployEmergencySystem.s.sol";
import { DeployImmunefiModule } from "../../../script/deployers/ImmunefiModule/DeployImmunefiModule.s.sol";
import { GrantExecutorRoles } from "../../../script/configs/setters/GrantExecutorRoles.s.sol";
import { ImmunefiModule } from "../../../src/ImmunefiModule.sol";

contract GrantExecutorRolesTest is Test {
    // solhint-disable state-visibility
    address immunefiModule;
    address rewardSystem;
    address timelock;
    address arbitration;

    function setUp() public {
        vm.setEnv("MNEMONIC", "test test test test test test test test test test test junk");
        (address deployer, ) = deriveRememberKey({ mnemonic: vm.envString("MNEMONIC"), index: 0 });
        vm.setEnv("PROTOCOL_OWNER", vm.toString(deployer));

        address proxyAdmin = new DeployProxyAdmin().run();
        address emergencySystem = new DeployEmergencySystem().run();

        vm.setEnv("PROXY_ADMIN", vm.toString(proxyAdmin));
        vm.setEnv("EMERGENCY_SYSTEM", vm.toString(emergencySystem));

        immunefiModule = new DeployImmunefiModule().run();

        rewardSystem = makeAddr("RewardSystem");
        timelock = makeAddr("Timelock");
        arbitration = makeAddr("Arbitration");
    }

    function testGrantExecutorRolesSucceeds() public {
        ImmunefiModule module = ImmunefiModule(immunefiModule);

        assertFalse(module.hasRole(module.EXECUTOR_ROLE(), rewardSystem));
        assertFalse(module.hasRole(module.EXECUTOR_ROLE(), timelock));
        assertFalse(module.hasRole(module.EXECUTOR_ROLE(), arbitration));

        vm.setEnv("IMMUNEFI_MODULE", vm.toString(immunefiModule));
        vm.setEnv("REWARD_SYSTEM", vm.toString(rewardSystem));
        vm.setEnv("TIMELOCK", vm.toString(timelock));
        vm.setEnv("ARBITRATION", vm.toString(arbitration));
        new GrantExecutorRoles().run();

        assertTrue(module.hasRole(module.EXECUTOR_ROLE(), rewardSystem));
        assertTrue(module.hasRole(module.EXECUTOR_ROLE(), timelock));
        assertTrue(module.hasRole(module.EXECUTOR_ROLE(), arbitration));
    }
}
