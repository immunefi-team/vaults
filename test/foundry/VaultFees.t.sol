// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { Strings } from "openzeppelin-contracts/utils/Strings.sol";
import { VaultFees } from "../../src/common/VaultFees.sol";
import { Setups } from "./helpers/Setups.sol";

contract VaultFeesTest is Test, Setups {
    // solhint-disable state-visibility
    address feeSetter;
    address nonPrivilegedAddr;

    event FeeSet(address indexed vault, address indexed feeRecipient, uint16 feeBps);
    event DefaultFeeSet(address indexed defaultFeeRecipient, uint16 feeBps);

    modifier wrapPrank(address _addr) {
        vm.startPrank(_addr);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        _protocolSetup();

        feeSetter = makeAddr("feeSetter");
        nonPrivilegedAddr = makeAddr("nonPriviligedAddr");

        vm.startPrank(protocolOwner);
        vaultFees.grantRole(vaultFees.SETTER_ROLE(), feeSetter);
        vm.stopPrank();
    }

    function testSetCustomAndDefaultVaultFeeSucceeds() public wrapPrank(feeSetter) {
        // Set vault fee
        address newFeeRecipient = makeAddr("newFeeRecipient");
        vm.expectEmit(true, true, false, true);
        emit FeeSet(address(vault), newFeeRecipient, 1000);
        vaultFees.setVaultFee(address(vault), 1000, newFeeRecipient);

        (uint16 feeBps, address recipient) = vaultFees.getFee(address(vault));
        assertEq(feeBps, 1000);
        assertEq(recipient, newFeeRecipient);

        // Set default fee
        address newCustomFeeRecipient = makeAddr("newCustomFeeRecipient");
        vm.expectEmit(true, false, false, true);
        emit DefaultFeeSet(newCustomFeeRecipient, 300);
        vaultFees.setDefaultFee(300, newCustomFeeRecipient);

        (uint16 defaultFeeBps, address defaultFeeRecipient) = vaultFees.getFee(makeAddr("someRandomVault"));
        assertEq(defaultFeeBps, 300);
        assertEq(defaultFeeRecipient, newCustomFeeRecipient);
    }

    function testSetCustomAndDefaultVaultFeeReverts() public wrapPrank(feeSetter) {
        vm.expectRevert("VaultFees: feeBps must be below FEE_BASIS");
        vaultFees.setDefaultFee(200_00, makeAddr("newCustomFeeRecipient"));

        vm.expectRevert("VaultFees: defaultFeeRecipient cannot be 0x00");
        vaultFees.setDefaultFee(100, address(0));

        vm.expectRevert("VaultFees: feeBps must be below FEE_BASIS");
        vaultFees.setVaultFee(address(vault), 200_00, makeAddr("newFeeRecipient"));
    }

    function testFreezeByNonFreezerReverts() public wrapPrank(nonPrivilegedAddr) {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonPrivilegedAddr),
                " is missing role ",
                Strings.toHexString(uint256(vaultFees.SETTER_ROLE()), 32)
            )
        );
        vaultFees.setDefaultFee(100, makeAddr("newFeeRecipient"));

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonPrivilegedAddr),
                " is missing role ",
                Strings.toHexString(uint256(vaultFees.SETTER_ROLE()), 32)
            )
        );
        vaultFees.setVaultFee(address(vault), 100, makeAddr("newFeeRecipient"));
    }
}
