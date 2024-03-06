// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/VaultFreezer.sol";
import "../utils/ProxyUtils.sol";

contract DeployVaultFreezer is BaseScript, ProxyUtils {
    function run() public virtual broadcaster returns (address vaultFreezer) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");

        vaultFreezer = _deployTransparentProxy(
            address(new VaultFreezer{ salt: "immunefi" }()),
            proxyAdminAddress,
            abi.encodeCall(VaultFreezer.setUp, (protocolOwner))
        );

        console.log("VaultFreezer deployed at: %s", vaultFreezer);
    }
}
