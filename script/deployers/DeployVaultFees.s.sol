// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../Base.s.sol";
import "../../src/common/VaultFees.sol";

contract DeployVaultFees is BaseScript {
    function run() public virtual broadcaster returns (address vaultFees) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        uint16 feeBps = uint16(vm.envUint("FEE_BPS"));

        vaultFees = address(new VaultFees{ salt: "immunefi" }(protocolOwner, feeRecipient, feeBps));

        console.log("VaultFees deployed at: %s", vaultFees);
    }
}
