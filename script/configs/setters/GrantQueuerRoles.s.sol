// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/Timelock.sol";

contract GrantQueuerRoles is BaseScript {
    function run() public virtual broadcaster returns (address timelockAddress) {
        timelockAddress = vm.envAddress("TIMELOCK");
        address withdrawalSystemAddress = vm.envAddress("WITHDRAWAL_SYSTEM");
        Timelock timelock = Timelock(timelockAddress);

        timelock.grantRole(timelock.QUEUER_ROLE(), withdrawalSystemAddress);
    }
}
