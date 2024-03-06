// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../Base.s.sol";
import "../../src/handlers/VaultSetup.sol";

contract DeployVaultSetup is BaseScript {
    function run() public virtual broadcaster returns (address vaultSetup) {
        vaultSetup = address(new VaultSetup{ salt: "immunefi" }());

        console.log("VaultSetup deployed at: %s", vaultSetup);
    }
}
