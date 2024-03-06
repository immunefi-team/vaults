// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/guards/ScopeGuard.sol";
import "../utils/ProxyUtils.sol";

contract DeployScopeGuard is BaseScript, ProxyUtils {
    function run() public virtual broadcaster returns (address scopeGuard) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");

        scopeGuard = _deployTransparentProxy(
            address(new ScopeGuard{ salt: "immunefi" }()),
            proxyAdminAddress,
            abi.encodeCall(ScopeGuard.setUp, (protocolOwner))
        );

        console.log("ScopeGuard deployed at: %s", scopeGuard);
    }
}
