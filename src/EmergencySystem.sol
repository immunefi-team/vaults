// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Ownable2Step } from "openzeppelin-contracts/access/Ownable2Step.sol";
import { IEmergencySystemEvents } from "./events/IEmergencySystemEvents.sol";

/**
 * @title EmergencySystem
 * @author Immunefi
 * @dev This contract is used to flag a protocol shutdown, to decouple logic from vaults.
 */
contract EmergencySystem is Ownable2Step, IEmergencySystemEvents {
    bool public emergencyShutdownActive;

    constructor(address _owner) {
        // bypasses 2-step ownership transfer
        _transferOwnership(_owner);
    }

    function activateEmergencyShutdown() external onlyOwner {
        emergencyShutdownActive = true;
        emit EmergencyShutdownActivated(msg.sender);
    }

    function deactivateEmergencyShutdown() external onlyOwner {
        emergencyShutdownActive = false;
        emit EmergencyShutdownDeactivated(msg.sender);
    }
}
