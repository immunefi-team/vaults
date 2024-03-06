// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/WithdrawalSystem.sol";

contract SetWithdrawalSystemConfigs is BaseScript {
    function run() public virtual broadcaster returns (address withdrawalSystemAddress) {
        withdrawalSystemAddress = vm.envAddress("WITHDRAWAL_SYSTEM");

        WithdrawalSystem withdrawalSystem = WithdrawalSystem(withdrawalSystemAddress);
        withdrawalSystem.setTxCooldown(uint32(vm.envUint("WITHDRAWAL_TX_COOLDOWN")));
        withdrawalSystem.setTxExpiration(vm.envUint("WITHDRAWAL_TX_EXPIRATION"));
    }
}
