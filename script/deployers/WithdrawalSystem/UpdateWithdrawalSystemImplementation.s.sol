// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../../src/WithdrawalSystem.sol";
import "../../../src/proxy/ProxyAdminOwnable2Step.sol";

contract UpdateWithdrawalSystemImplementation is BaseScript {
    function run() external broadcaster {
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address withdrawalSystemAddress = vm.envAddress("WITHDRAWAL_SYSTEM"); // proxy

        address withdrawalSystemPrevOwner = WithdrawalSystem(withdrawalSystemAddress).owner();

        ProxyAdminOwnable2Step proxyAdmin = ProxyAdminOwnable2Step(proxyAdminAddress);

        WithdrawalSystem newImplementation = new WithdrawalSystem{ salt: "immunefi" }();
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(withdrawalSystemAddress));
        proxyAdmin.upgrade(proxy, address(newImplementation));

        require(
            WithdrawalSystem(withdrawalSystemAddress).owner() == withdrawalSystemPrevOwner,
            "WithdrawalSystem owner should not be changed"
        );
    }
}
