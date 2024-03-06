// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract ProxyUtils {
    function _deployTransparentProxy(
        address logic,
        address proxyAdmin,
        bytes memory initData
    ) internal returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: "immunefi-test-transparent.proxy" }(
            address(logic),
            proxyAdmin,
            initData
        );
        return address(proxy);
    }
}
