// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../../Base.s.sol";
import "../../../src/RewardSystem.sol";

contract GrantEnforcerRoles is BaseScript {
    function run() public virtual broadcaster returns (address rewardSystemAddress) {
        rewardSystemAddress = vm.envAddress("REWARD_SYSTEM");
        address arbitrationAddress = vm.envAddress("ARBITRATION");
        RewardSystem rewardSystem = RewardSystem(rewardSystemAddress);

        rewardSystem.grantRole(rewardSystem.ENFORCER_ROLE(), arbitrationAddress);
    }
}
