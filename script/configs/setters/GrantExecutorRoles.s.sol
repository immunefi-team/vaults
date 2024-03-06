// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/ImmunefiModule.sol";

contract GrantExecutorRoles is BaseScript {
    function run() public virtual broadcaster returns (address immunefiModuleAddress) {
        immunefiModuleAddress = vm.envAddress("IMMUNEFI_MODULE");
        address rewardSystemAddress = vm.envAddress("REWARD_SYSTEM");
        address timelockAddress = vm.envAddress("TIMELOCK");
        address arbitrationAddress = vm.envAddress("ARBITRATION");

        ImmunefiModule immunefiModule = ImmunefiModule(immunefiModuleAddress);
        bytes32 executorRole = immunefiModule.EXECUTOR_ROLE();

        immunefiModule.grantRole(executorRole, timelockAddress);
        immunefiModule.grantRole(executorRole, rewardSystemAddress);
        immunefiModule.grantRole(executorRole, arbitrationAddress);
    }
}
