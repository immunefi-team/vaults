// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { EmergencySystem } from "../../src/EmergencySystem.sol";
import { IEmergencySystemEvents } from "../../src/events/IEmergencySystemEvents.sol";

contract EmergencySystemTest is Test, IEmergencySystemEvents {
    // solhint-disable state-visibility
    address owner;
    EmergencySystem emergencySystem;

    function setUp() public {
        owner = vm.addr(1);
        emergencySystem = new EmergencySystem(owner);
    }

    function testEmergencySystem() public {
        vm.startPrank(owner);

        // activateEmergencyShutdown
        vm.expectEmit(true, false, false, false);
        emit EmergencyShutdownActivated(owner);
        emergencySystem.activateEmergencyShutdown();

        // deactivateEmergencyShutdown
        vm.expectEmit(true, false, false, false);
        emit EmergencyShutdownDeactivated(owner);
        emergencySystem.deactivateEmergencyShutdown();

        vm.stopPrank();
    }

    function testShutdownByNonOwnerReverts() public {
        vm.expectRevert("Ownable: caller is not the owner");
        emergencySystem.activateEmergencyShutdown();
    }

    function testShutdownDeactivationByNonOwnerReverts() public {
        vm.startPrank(owner);

        // activateEmergencyShutdown
        vm.expectEmit(true, false, false, false);
        emit EmergencyShutdownActivated(owner);
        emergencySystem.activateEmergencyShutdown();

        vm.stopPrank();

        // deactivateEmergencyShutdown reverts
        vm.expectRevert("Ownable: caller is not the owner");
        emergencySystem.deactivateEmergencyShutdown();
    }
}
