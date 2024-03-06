// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/RewardSystem.sol";
import "../utils/ProxyUtils.sol";

contract DeployRewardSystem is BaseScript, ProxyUtils {
    function run() public virtual broadcaster returns (address rewardSystem) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");

        bytes memory encodedCall;
        {
            address immunefiModule = vm.envAddress("IMMUNEFI_MODULE");
            address vaultDelegate = vm.envAddress("VAULT_DELEGATE");
            address arbitration = vm.envAddress("ARBITRATION");
            address vaultFreezer = vm.envAddress("VAULT_FREEZER");

            encodedCall = abi.encodeCall(
                RewardSystem.setUp,
                (protocolOwner, immunefiModule, vaultDelegate, arbitration, vaultFreezer)
            );
        }

        rewardSystem = _deployTransparentProxy(
            address(new RewardSystem{ salt: "immunefi" }()),
            proxyAdminAddress,
            encodedCall
        );

        console.log("RewardSystem deployed at: %s", rewardSystem);
    }
}
