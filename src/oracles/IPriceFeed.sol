// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

interface IPriceFeed {
    function getUsdPrice() external view returns (int256 price, uint256 updatedAt);

    function decimals() external view returns (uint8);
}
