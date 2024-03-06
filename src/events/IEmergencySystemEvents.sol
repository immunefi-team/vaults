// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

interface IEmergencySystemEvents {
    event EmergencyShutdownActivated(address indexed activator);
    event EmergencyShutdownDeactivated(address indexed deactivator);
}
