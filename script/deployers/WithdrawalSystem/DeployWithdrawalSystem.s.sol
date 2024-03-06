// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/WithdrawalSystem.sol";
import "../utils/ProxyUtils.sol";

contract DeployWithdrawalSystem is BaseScript, ProxyUtils {
    function run() public virtual broadcaster returns (address withdrawalSystem) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN");
        address vaultDelegate = vm.envAddress("VAULT_DELEGATE");
        address timelock = vm.envAddress("TIMELOCK");
        uint256 txCooldown = vm.envUint("WITHDRAWAL_TX_COOLDOWN");
        uint256 txExpiration = vm.envUint("WITHDRAWAL_TX_EXPIRATION");

        withdrawalSystem = _deployTransparentProxy(
            address(new WithdrawalSystem{ salt: "immunefi" }()),
            proxyAdminAddress,
            abi.encodeCall(
                WithdrawalSystem.setUp,
                (protocolOwner, address(timelock), address(vaultDelegate), txCooldown, txExpiration)
            )
        );

        console.log("WithdrawalSystem deployed at: %s", withdrawalSystem);
    }
}
