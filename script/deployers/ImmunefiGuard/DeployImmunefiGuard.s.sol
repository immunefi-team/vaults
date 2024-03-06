// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/guards/ImmunefiGuard.sol";
import "../../../src/guards/ScopeGuard.sol";
import "../utils/ProxyUtils.sol";

contract DeployImmunefiGuard is BaseScript, ProxyUtils {
    function run() public virtual broadcaster returns (address immunefiGuard) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address emergencySystem = vm.envAddress("EMERGENCY_SYSTEM");

        immunefiGuard = _deployTransparentProxy(
            address(new ImmunefiGuard{ salt: "immunefi" }(emergencySystem)),
            proxyAdminAddress,
            abi.encodeCall(ScopeGuard.setUp, (protocolOwner)) // inherits from it
        );

        console.log("ImmunefiGuard deployed at: %s", immunefiGuard);
    }
}
