// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/ImmunefiModule.sol";
import "../utils/ProxyUtils.sol";

contract DeployImmunefiModule is BaseScript, ProxyUtils {
    function run() public virtual broadcaster returns (address immunefiModule) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address emergencySystem = vm.envAddress("EMERGENCY_SYSTEM");

        immunefiModule = _deployTransparentProxy(
            address(new ImmunefiModule{ salt: "immunefi" }(address(emergencySystem))),
            proxyAdminAddress,
            abi.encodeCall(ImmunefiModule.setUp, (protocolOwner))
        );

        console.log("ImmunefiModule deployed at: %s", immunefiModule);
    }
}
