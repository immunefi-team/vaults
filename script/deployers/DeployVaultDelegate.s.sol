// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../Base.s.sol";
import "../../src/common/VaultDelegate.sol";

contract DeployVaultDelegate is BaseScript {
    function run() public virtual broadcaster returns (address vaultDelegate) {
        address vaultFees = vm.envAddress("VAULT_FEES");

        vaultDelegate = address(new VaultDelegate{ salt: "immunefi" }(vaultFees));

        console.log("VaultDelegate deployed at: %s", vaultDelegate);
    }
}
