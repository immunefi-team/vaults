// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/guards/ScopeGuard.sol";
import "../../../src/ImmunefiModule.sol";

contract SetImmunefiModuleGuard is BaseScript {
    function run() public virtual broadcaster returns (address immunefiModuleAddress) {
        address scopeGuardAddress = vm.envAddress("SCOPE_GUARD");
        immunefiModuleAddress = vm.envAddress("IMMUNEFI_MODULE");
        ImmunefiModule immunefiModule = ImmunefiModule(immunefiModuleAddress);

        immunefiModule.setGuard(address(scopeGuardAddress));
    }
}
