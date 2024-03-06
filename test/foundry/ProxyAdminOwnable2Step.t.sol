// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { ProxyAdminOwnable2Step } from "../../src/proxy/ProxyAdminOwnable2Step.sol";

contract ProxyAdminOwnable2StepTest is Test {
    // solhint-disable state-visibility
    address owner;
    ProxyAdminOwnable2Step proxyAdminOwnable2Step;

    function setUp() public {
        owner = makeAddr("owner");
        proxyAdminOwnable2Step = new ProxyAdminOwnable2Step(owner);

        assertEq(proxyAdminOwnable2Step.owner(), owner);
    }

    function testChangesOwner() public {
        address newOwner = makeAddr("newOwner");

        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdminOwnable2Step.transferOwnership(newOwner);

        vm.prank(owner);
        proxyAdminOwnable2Step.transferOwnership(newOwner);
        // owner is not yet transferred
        assertEq(proxyAdminOwnable2Step.owner(), owner);

        vm.expectRevert("Ownable2Step: caller is not the new owner");
        proxyAdminOwnable2Step.acceptOwnership();

        vm.prank(newOwner);
        proxyAdminOwnable2Step.acceptOwnership();
        assertEq(proxyAdminOwnable2Step.owner(), newOwner);
    }
}
