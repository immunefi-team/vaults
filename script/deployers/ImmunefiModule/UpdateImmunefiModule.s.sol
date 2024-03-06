// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../../src/ImmunefiModule.sol";
import "../../../src/proxy/ProxyAdminOwnable2Step.sol";

contract UpdateImmunefiModuleImplementation is BaseScript {
    function run() external broadcaster {
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address moduleAddress = vm.envAddress("IMMUNEFI_MODULE"); // proxy
        address emergencySystem = vm.envAddress("EMERGENCY_SYSTEM");

        ProxyAdminOwnable2Step proxyAdmin = ProxyAdminOwnable2Step(proxyAdminAddress);

        ImmunefiModule newModuleImplementation = new ImmunefiModule{ salt: "immunefi" }(emergencySystem);
        TransparentUpgradeableProxy moduleProxy = TransparentUpgradeableProxy(payable(moduleAddress));
        proxyAdmin.upgrade(moduleProxy, address(newModuleImplementation));
    }
}
