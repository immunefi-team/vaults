// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../../src/VaultFreezer.sol";
import "../../../src/proxy/ProxyAdminOwnable2Step.sol";

contract UpdateVaultFreezerImplementation is BaseScript {
    function run() external broadcaster {
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address guardAddress = vm.envAddress("VAULT_FREEZER"); // proxy

        ProxyAdminOwnable2Step proxyAdmin = ProxyAdminOwnable2Step(proxyAdminAddress);

        VaultFreezer newVaultFreezerImplementation = new VaultFreezer{ salt: "immunefi" }();
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(guardAddress));
        proxyAdmin.upgrade(proxy, address(newVaultFreezerImplementation));
    }
}
