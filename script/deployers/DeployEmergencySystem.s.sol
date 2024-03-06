// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../Base.s.sol";
import "../../src/EmergencySystem.sol";

contract DeployEmergencySystem is BaseScript {
    function run() public virtual broadcaster returns (address emergencySystem) {
        address protocolOwner = vm.envAddress("PROTOCOL_OWNER");

        emergencySystem = address(new EmergencySystem{ salt: "immunefi" }(protocolOwner));

        console.log("EmergencySystem deployed at: %s", emergencySystem);
    }
}
