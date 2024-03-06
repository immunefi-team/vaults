// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../../src/Arbitration.sol";
import "../../../src/proxy/ProxyAdminOwnable2Step.sol";

contract UpdateArbitrationImplementation is BaseScript {
    function run() external broadcaster {
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address arbitrationAddress = vm.envAddress("ARBITRATION"); // proxy

        address feeRecipient = Arbitration(arbitrationAddress).feeRecipient();

        ProxyAdminOwnable2Step proxyAdmin = ProxyAdminOwnable2Step(proxyAdminAddress);

        Arbitration newArbitrationImplementation = new Arbitration{ salt: "immunefi" }();
        TransparentUpgradeableProxy rewardSystemProxy = TransparentUpgradeableProxy(payable(arbitrationAddress));
        proxyAdmin.upgrade(rewardSystemProxy, address(newArbitrationImplementation));

        require(
            Arbitration(arbitrationAddress).feeRecipient() == feeRecipient,
            "Arbitration feeRecipient should not be changed"
        );
    }
}
