// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

interface IPriceConsumerEvents {
    event CustomFeedSet(address indexed base, address indexed priceFeed);
    event CustomFeedTimeoutSet(address indexed base, uint256 timeout);
}
