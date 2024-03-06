// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/Timelock.sol";
import "../utils/ProxyUtils.sol";

contract DeployTimelock is BaseScript, ProxyUtils {
    function run() public virtual broadcaster returns (address timelock) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address immunefiModule = vm.envAddress("IMMUNEFI_MODULE");
        address vaultFreezer = vm.envAddress("VAULT_FREEZER");

        timelock = _deployTransparentProxy(
            address(new Timelock{ salt: "immunefi" }()),
            proxyAdminAddress,
            abi.encodeCall(Timelock.setUp, (protocolOwner, address(immunefiModule), address(vaultFreezer)))
        );

        console.log("Timelock deployed at: %s", timelock);
    }
}
