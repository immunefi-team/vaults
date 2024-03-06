// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../../src/Timelock.sol";
import "../../../src/proxy/ProxyAdminOwnable2Step.sol";

contract UpdateTimelockImplementation is BaseScript {
    function run() external broadcaster {
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address timelockAddress = vm.envAddress("TIMELOCK"); // proxy

        ProxyAdminOwnable2Step proxyAdmin = ProxyAdminOwnable2Step(proxyAdminAddress);

        address timelockImmunefiModule = address(Timelock(timelockAddress).immunefiModule());

        Timelock newTimelockImplementation = new Timelock{ salt: "immunefi" }();
        TransparentUpgradeableProxy timelockProxy = TransparentUpgradeableProxy(payable(timelockAddress));
        proxyAdmin.upgrade(timelockProxy, address(newTimelockImplementation));

        require(
            address(Timelock(timelockAddress).immunefiModule()) == timelockImmunefiModule,
            "Timelock immunefiModule should not be changed"
        );
    }
}
