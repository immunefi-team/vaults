// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { Strings } from "openzeppelin-contracts/utils/Strings.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { VaultFreezer } from "../../src/VaultFreezer.sol";
import { IVaultFreezerEvents } from "../../src/events/IVaultFreezerEvents.sol";
import { Setups } from "./helpers/Setups.sol";

contract VaultFreezerTest is Test, Setups, IVaultFreezerEvents {
    // solhint-disable state-visibility
    address freezer;
    address nonPrivilegedAddr;

    modifier wrapPrank(address _addr) {
        vm.startPrank(_addr);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        _protocolSetup();

        freezer = makeAddr("freezer");
        nonPrivilegedAddr = makeAddr("nonPriviligedAddr");

        vm.startPrank(protocolOwner);
        vaultFreezer.grantRole(vaultFreezer.FREEZER_ROLE(), freezer);
        vm.stopPrank();
    }

    function testFreezeUnfreezeVault() public wrapPrank(freezer) {
        // Freeze vault
        vm.expectEmit(true, false, false, false);
        emit VaultFreezed(address(vault));
        vaultFreezer.freezeVault(address(vault));
        assertTrue(vaultFreezer.isFrozen(address(vault)), "VaultFreezer: vault not frozen");

        // Unfreeze vault
        vm.expectEmit(true, false, false, false);
        emit VaultUnfreezed(address(vault));
        vaultFreezer.unfreezeVault(address(vault));
        assertFalse(vaultFreezer.isFrozen(address(vault)), "VaultFreezer: vault not unfrozen");
    }

    function testFreezeFrozenVaultReverts() public wrapPrank(freezer) {
        // Freeze vault
        vm.expectEmit(true, false, false, false);
        emit VaultFreezed(address(vault));
        vaultFreezer.freezeVault(address(vault));
        assertTrue(vaultFreezer.isFrozen(address(vault)), "VaultFreezer: vault not frozen");

        // Revert on second freeze
        vm.expectRevert("VaultFreezer: vault already frozen");
        vaultFreezer.freezeVault(address(vault));
    }

    function testUnfreezeUnfrozenVaultReverts() public wrapPrank(freezer) {
        vm.expectRevert("VaultFreezer: vault already unfrozen");
        vaultFreezer.unfreezeVault(address(vault));
    }

    function testFreezeByNonFreezerReverts() public wrapPrank(nonPrivilegedAddr) {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonPrivilegedAddr),
                " is missing role ",
                Strings.toHexString(uint256(vaultFreezer.FREEZER_ROLE()), 32)
            )
        );
        vaultFreezer.freezeVault(address(vault));
    }

    function testUnfreezeByNonFreezerReverts() public {
        vm.startPrank(freezer);
        // Freeze vault
        vm.expectEmit(true, false, false, false);
        emit VaultFreezed(address(vault));
        vaultFreezer.freezeVault(address(vault));
        assertTrue(vaultFreezer.isFrozen(address(vault)), "VaultFreezer: vault not frozen");
        vm.stopPrank();

        vm.startPrank(nonPrivilegedAddr);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonPrivilegedAddr),
                " is missing role ",
                Strings.toHexString(uint256(vaultFreezer.FREEZER_ROLE()), 32)
            )
        );
        vaultFreezer.unfreezeVault(address(vault));
        vm.stopPrank();
    }

    function testVaultFreezerSetupBranches() public {
        VaultFreezer newSystem = new VaultFreezer();

        bytes memory initData = abi.encodeCall(newSystem.setUp, (address(0)));
        vm.expectRevert("VaultFreezer: owner cannot be 0x00");
        new TransparentUpgradeableProxy(address(newSystem), protocolOwner, initData);
    }
}
