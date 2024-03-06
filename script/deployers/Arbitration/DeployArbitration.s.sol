// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/Arbitration.sol";
import "../utils/ProxyUtils.sol";

contract DeployArbitration is BaseScript, ProxyUtils {
    function run() public virtual broadcaster returns (address arbitration) {
        bytes memory callData;
        {
            address protocolOwner = vm.envAddress("PROTOCOL_OWNER");
            address immunefiModule = vm.envAddress("IMMUNEFI_MODULE");
            address rewardSystem = vm.envAddress("REWARD_SYSTEM");
            address vaultDelegate = vm.envAddress("VAULT_DELEGATE");

            uint256 arbitrationFee = vm.envUint("ARBITRATION_FEE");
            address tokenFee = vm.envAddress("ARBITRATION_TOKEN_FEE");
            callData = abi.encodeCall(
                Arbitration.setUp,
                (protocolOwner, immunefiModule, rewardSystem, vaultDelegate, tokenFee, arbitrationFee, protocolOwner)
            );
        }

        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address arbitrationImplementation = address(new Arbitration{ salt: "immunefi" }());

        {
            arbitration = _deployTransparentProxy(arbitrationImplementation, proxyAdminAddress, callData);
        }

        console.log("Arbitration deployed at: %s", arbitration);
    }
}
