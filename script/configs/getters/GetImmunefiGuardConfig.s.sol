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

contract GetImmunefiGuardConfig is BaseScript {
    function run() external view {
        address immunefiGuardAddress = vm.envAddress("IMMUNEFI_GUARD");
        address withdrawalSystemAddress = vm.envAddress("WITHDRAWAL_SYSTEM");
        address rewardSystemAddress = vm.envAddress("REWARD_SYSTEM");
        address timelockAddress = vm.envAddress("TIMELOCK");
        address arbitrationAddress = vm.envAddress("ARBITRATION");

        ImmunefiGuard immunefiGuard = ImmunefiGuard(immunefiGuardAddress);

        console.log("withdrawalSystem allowed: %s", immunefiGuard.isAllowedTarget(withdrawalSystemAddress));
        console.log(
            "withdrawalSystem.queueVaultWithdrawal allowed: %s",
            immunefiGuard.isAllowedFunction(withdrawalSystemAddress, WithdrawalSystem.queueVaultWithdrawal.selector)
        );
        console.log("withdrawalSystem scoped: %s", immunefiGuard.isScoped(withdrawalSystemAddress));

        console.log("rewardSystem allowed: %s", immunefiGuard.isAllowedTarget(rewardSystemAddress));
        console.log(
            "rewardSystem.sendRewardByVault allowed: %s",
            immunefiGuard.isAllowedFunction(rewardSystemAddress, RewardSystem.sendRewardByVault.selector)
        );
        console.log("rewardSystem scoped: %s", immunefiGuard.isScoped(rewardSystemAddress));

        console.log("timelock allowed: %s", immunefiGuard.isAllowedTarget(timelockAddress));
        console.log(
            "timelock.executeTransaction allowed: %s",
            immunefiGuard.isAllowedFunction(timelockAddress, Timelock.executeTransaction.selector)
        );
        console.log(
            "timelock.cancelTransaction allowed: %s",
            immunefiGuard.isAllowedFunction(timelockAddress, Timelock.cancelTransaction.selector)
        );
        console.log("timelock scoped: %s", immunefiGuard.isScoped(timelockAddress));

        console.log("arbitration allowed: %s", immunefiGuard.isAllowedTarget(arbitrationAddress));
        console.log("arbitration scoped: %s", immunefiGuard.isScoped(arbitrationAddress));
        console.log(
            "arbitration.requestArbVault allowed %s",
            immunefiGuard.isAllowedFunction(arbitrationAddress, Arbitration.requestArbVault.selector)
        );
    }
}
