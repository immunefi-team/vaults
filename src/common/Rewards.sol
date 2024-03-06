// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

/**
 * @title Rewards
 * @author Immunefi
 * @notice Reward-related structs for various components
 */
contract Rewards {
    struct ERC20Reward {
        address token;
        uint256 amount;
    }
}
