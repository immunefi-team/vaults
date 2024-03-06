// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../Base.s.sol";
import "../../src/proxy/ProxyAdminOwnable2Step.sol";

contract DeployProxyAdmin is BaseScript {
    function run() public virtual broadcaster returns (address proxyAdmin) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");

        proxyAdmin = address(new ProxyAdminOwnable2Step{ salt: "immunefi" }(protocolOwner));

        console.log("ProxyAdmin deployed at: %s", proxyAdmin);
    }
}
