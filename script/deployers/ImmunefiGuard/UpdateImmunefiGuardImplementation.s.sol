// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../../src/guards/ImmunefiGuard.sol";
import "../../../src/proxy/ProxyAdminOwnable2Step.sol";

contract UpdateImmunefiGuardImplementation is BaseScript {
    function run() external broadcaster {
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address guardAddress = vm.envAddress("IMMUNEFI_GUARD"); // proxy
        address emergencySystem = vm.envAddress("EMERGENCY_SYSTEM");

        ProxyAdminOwnable2Step proxyAdmin = ProxyAdminOwnable2Step(proxyAdminAddress);

        address guardPrevOwner = ImmunefiGuard(guardAddress).owner();

        ImmunefiGuard newGuardImplementation = new ImmunefiGuard{ salt: "immunefi" }(emergencySystem);
        TransparentUpgradeableProxy guardProxy = TransparentUpgradeableProxy(payable(guardAddress));
        proxyAdmin.upgrade(guardProxy, address(newGuardImplementation));

        require(ImmunefiGuard(guardAddress).owner() == guardPrevOwner, "ImmunefiGuard owner should not be changed");
    }
}
