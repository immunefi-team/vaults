// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { VaultRewardHandler } from "./handlers/VaultRewardHandler.sol";
import { Rewards } from "../../../src/common/Rewards.sol";

contract VaultRewardInvariantTest is Test {
    address public immutable WHITEHAT = makeAddr("whitehat");
    VaultRewardHandler public handler;

    function setUp() public {
        handler = new VaultRewardHandler();
        vm.deal(address(handler.vault()), 1_000_000 ether);

        // we specify selectors and target contract to be fuzzed
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.sendRewardNativeToken.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        targetContract(address(handler));
    }

    function invariant_checkSendRewardsWorks() public {
        assertEq(
            address(handler.vault()).balance + handler.FEE_RECIPIENT().balance + WHITEHAT.balance,
            1_000_000 ether
        );
    }
}
