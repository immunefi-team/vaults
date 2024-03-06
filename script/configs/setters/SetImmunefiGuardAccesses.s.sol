// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/guards/ImmunefiGuard.sol";
import "../../../src/RewardSystem.sol";
import "../../../src/Timelock.sol";
import "../../../src/WithdrawalSystem.sol";
import "../../../src/Arbitration.sol";

contract SetImmunefiGuardAccesses is BaseScript {
    function run() public virtual broadcaster returns (address immunefiGuardAddress) {
        immunefiGuardAddress = vm.envAddress("IMMUNEFI_GUARD");
        address withdrawalSystemAddress = vm.envAddress("WITHDRAWAL_SYSTEM");
        address rewardSystemAddress = vm.envAddress("REWARD_SYSTEM");
        address timelockAddress = vm.envAddress("TIMELOCK");
        address arbitrationAddress = vm.envAddress("ARBITRATION");

        ImmunefiGuard immunefiGuard = ImmunefiGuard(immunefiGuardAddress);

        // set withdrawalSystem scope in guard
        immunefiGuard.setTargetAllowed(withdrawalSystemAddress, true);
        immunefiGuard.setScoped(withdrawalSystemAddress, true);
        immunefiGuard.setAllowedFunction(withdrawalSystemAddress, WithdrawalSystem.queueVaultWithdrawal.selector, true);

        // set rewardSystem scope in guard
        immunefiGuard.setTargetAllowed(rewardSystemAddress, true);
        immunefiGuard.setScoped(rewardSystemAddress, true);
        immunefiGuard.setAllowedFunction(rewardSystemAddress, RewardSystem.sendRewardByVault.selector, true);

        // set timelock scope in guard
        immunefiGuard.setTargetAllowed(timelockAddress, true);
        immunefiGuard.setScoped(timelockAddress, true);
        immunefiGuard.setAllowedFunction(timelockAddress, Timelock.executeTransaction.selector, true);
        immunefiGuard.setAllowedFunction(timelockAddress, Timelock.cancelTransaction.selector, true);

        // set arbitration scope in guard
        immunefiGuard.setTargetAllowed(arbitrationAddress, true);
        immunefiGuard.setScoped(arbitrationAddress, true);
        immunefiGuard.setAllowedFunction(arbitrationAddress, Arbitration.requestArbVault.selector, true);
    }
}
