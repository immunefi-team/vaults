// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { IScopeGuardEvents } from "./IScopeGuardEvents.sol";

interface IImmunefiGuardEvents is IScopeGuardEvents {
    event SetGuardBypasser(address caller, bool allowed);
}
