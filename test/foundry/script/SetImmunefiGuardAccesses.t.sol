// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { DeployProxyAdmin } from "../../../script/deployers/DeployProxyAdmin.s.sol";
import { DeployImmunefiGuard } from "../../../script/deployers/ImmunefiGuard/DeployImmunefiGuard.s.sol";
import { SetImmunefiGuardAccesses } from "../../../script/configs/setters/SetImmunefiGuardAccesses.s.sol";
import { ImmunefiGuard } from "../../../src/guards/ImmunefiGuard.sol";
import { WithdrawalSystem } from "../../../src/WithdrawalSystem.sol";
import { RewardSystem } from "../../../src/RewardSystem.sol";
import { Timelock } from "../../../src/Timelock.sol";
import { Arbitration } from "../../../src/Arbitration.sol";

contract SetImmunefiGuardAccessesTest is Test {
    // solhint-disable state-visibility
    address immunefiGuard;
    address timelock;
    address withdrawalSystem;
    address rewardSystem;
    address arbitration;

    function setUp() public {
        vm.setEnv("MNEMONIC", "test test test test test test test test test test test junk");
        (address deployer, ) = deriveRememberKey({ mnemonic: vm.envString("MNEMONIC"), index: 0 });
        vm.setEnv("PROTOCOL_OWNER", vm.toString(deployer));

        address proxyAdmin = new DeployProxyAdmin().run();
        vm.setEnv("PROXY_ADMIN", vm.toString(proxyAdmin));

        vm.setEnv("EMERGENCY_SYSTEM", vm.toString(makeAddr("EmergencySystem")));

        immunefiGuard = new DeployImmunefiGuard().run();
    }

    function testSetImmunefiGuardAccessesSucceeds() public {
        ImmunefiGuard guard = ImmunefiGuard(immunefiGuard);

        timelock = makeAddr("Timelock");
        vm.setEnv("TIMELOCK", vm.toString(timelock));

        withdrawalSystem = makeAddr("WithdrawalSystem");
        vm.setEnv("WITHDRAWAL_SYSTEM", vm.toString(withdrawalSystem));

        rewardSystem = makeAddr("RewardSystem");
        vm.setEnv("REWARD_SYSTEM", vm.toString(rewardSystem));

        arbitration = makeAddr("Arbitration");
        vm.setEnv("ARBITRATION", vm.toString(arbitration));

        assertFalse(guard.isAllowedTarget(withdrawalSystem));
        assertFalse(guard.isScoped(withdrawalSystem));
        assertFalse(guard.isAllowedFunction(withdrawalSystem, WithdrawalSystem.queueVaultWithdrawal.selector));

        assertFalse(guard.isAllowedTarget(rewardSystem));
        assertFalse(guard.isScoped(rewardSystem));
        assertFalse(guard.isAllowedFunction(rewardSystem, RewardSystem.sendRewardByVault.selector));

        assertFalse(guard.isAllowedTarget(timelock));
        assertFalse(guard.isScoped(timelock));
        assertFalse(guard.isAllowedFunction(timelock, Timelock.executeTransaction.selector));
        assertFalse(guard.isAllowedFunction(timelock, Timelock.cancelTransaction.selector));

        assertFalse(guard.isAllowedTarget(arbitration));
        assertFalse(guard.isScoped(arbitration));
        assertFalse(guard.isAllowedFunction(arbitration, Arbitration.requestArbVault.selector));

        // Run script
        vm.setEnv("IMMUNEFI_GUARD", vm.toString(immunefiGuard));
        new SetImmunefiGuardAccesses().run();

        assertTrue(guard.isAllowedTarget(withdrawalSystem));
        assertTrue(guard.isScoped(withdrawalSystem));
        assertTrue(guard.isAllowedFunction(withdrawalSystem, WithdrawalSystem.queueVaultWithdrawal.selector));

        assertTrue(guard.isAllowedTarget(rewardSystem));
        assertTrue(guard.isScoped(rewardSystem));
        assertTrue(guard.isAllowedFunction(rewardSystem, RewardSystem.sendRewardByVault.selector));

        assertTrue(guard.isAllowedTarget(timelock));
        assertTrue(guard.isScoped(timelock));
        assertTrue(guard.isAllowedFunction(timelock, Timelock.executeTransaction.selector));
        assertTrue(guard.isAllowedFunction(timelock, Timelock.cancelTransaction.selector));

        assertTrue(guard.isAllowedTarget(arbitration));
        assertTrue(guard.isScoped(arbitration));
        assertTrue(guard.isAllowedFunction(arbitration, Arbitration.requestArbVault.selector));
    }
}
