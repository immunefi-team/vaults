// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

// solhint-disable no-global-import,no-console
import "forge-std/Test.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import { GnosisSafeProxyFactory } from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

import { ScopeGuard } from "../../src/guards/ScopeGuard.sol";
import { IImmunefiGuardEvents } from "../../src/events/IImmunefiGuardEvents.sol";
import { Setups } from "./helpers/Setups.sol";

contract ImmunefiGuardTest is Test, Setups, IImmunefiGuardEvents {
    bool internal vaultRecipientFunctionCalled;

    function setUp() public {
        _protocolSetup();
    }

    function vaultRecipientFunction() external payable {
        vaultRecipientFunctionCalled = true;
    }

    function testSetupGuardReverts() public {
        vm.startPrank(vaultSigner);

        vm.expectRevert("Initializable: contract is already initialized");
        immunefiGuard.setUp(vaultSigner);

        vm.stopPrank();
    }

    function testGuardBlocksTxs() public {
        bytes memory txHashData = vault.encodeTransactionData({
            to: address(vault),
            value: 0,
            data: abi.encodeCall(vault.enableModule, (address(immunefiGuard))),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        bytes memory signature = _signData(vaultSignerPk, txHashData);

        vm.expectRevert("Target address is not allowed");
        vault.execTransaction(
            address(vault),
            0,
            abi.encodeCall(vault.enableModule, (address(immunefiGuard))),
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );
    }

    function testAllowsEverythingOnShutdown() public {
        vm.prank(protocolOwner);
        emergencySystem.activateEmergencyShutdown();

        bytes memory txHashData = vault.encodeTransactionData({
            to: address(vault),
            value: 0,
            data: abi.encodeCall(vault.enableModule, (address(immunefiGuard))),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        bytes memory signature = _signData(vaultSignerPk, txHashData);

        vault.execTransaction(
            address(vault),
            0,
            abi.encodeCall(vault.enableModule, (address(immunefiGuard))),
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );
    }

    function testAllowsRecipientFunctionExecution() public {
        // reverts call of not protocolOwner
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        immunefiGuard.setTargetAllowed(address(this), true);
        vm.stopPrank();

        vm.startPrank(protocolOwner);
        immunefiGuard.setTargetAllowed(address(this), true);
        immunefiGuard.setAllowedFunction(address(this), this.vaultRecipientFunction.selector, true);
        immunefiGuard.setValueAllowedOnTarget(address(this), true);
        immunefiGuard.setScoped(address(this), true);
        vm.stopPrank();

        assertTrue(immunefiGuard.isAllowedTarget(address(this)));
        assertTrue(immunefiGuard.isAllowedFunction(address(this), this.vaultRecipientFunction.selector));
        assertTrue(immunefiGuard.isValueAllowed(address(this)));
        assertTrue(immunefiGuard.isScoped(address(this)));
        assertFalse(immunefiGuard.isfallbackAllowed(address(this)));
        assertFalse(immunefiGuard.isAllowedToDelegateCall(address(this)));

        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 valueToSend = 1.1 ether;
        vm.deal(address(vault), valueToSend);
        bytes memory txHashData = vault.encodeTransactionData({
            to: address(this),
            value: valueToSend,
            data: data,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        bytes memory signature = _signData(vaultSignerPk, txHashData);

        vault.execTransaction(
            address(this),
            valueToSend,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );
    }

    function testCallerBypassesWithGuardBypasser() public {
        // reverts call of not protocolOwner
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        immunefiGuard.setGuardBypasser(unprivilegedAddress, true);
        vm.stopPrank();

        vm.startPrank(protocolOwner);
        immunefiGuard.setGuardBypasser(unprivilegedAddress, true);
        vm.stopPrank();

        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 valueToSend = 1.1 ether;
        vm.deal(address(vault), valueToSend);
        bytes memory txHashData = vault.encodeTransactionData({
            to: address(this),
            value: valueToSend,
            data: data,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        bytes memory signature = _signData(vaultSignerPk, txHashData);

        vm.startPrank(unprivilegedAddress);
        vault.execTransaction(
            address(this),
            valueToSend,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );
        vm.stopPrank();
        assertEq(vaultRecipientFunctionCalled, true);
    }

    function testAllowsFallbackExecution() public {
        // reverts call of not protocolOwner
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        immunefiGuard.setFallbackAllowedOnTarget(address(this), true);
        vm.stopPrank();

        vm.startPrank(protocolOwner);
        immunefiGuard.setTargetAllowed(address(this), true);
        immunefiGuard.setFallbackAllowedOnTarget(address(this), true);
        immunefiGuard.setValueAllowedOnTarget(address(this), true);
        immunefiGuard.setScoped(address(this), true);
        vm.stopPrank();

        assertTrue(immunefiGuard.isAllowedTarget(address(this)));
        assertTrue(immunefiGuard.isfallbackAllowed(address(this)));
        assertTrue(immunefiGuard.isValueAllowed(address(this)));
        assertTrue(immunefiGuard.isScoped(address(this)));
        assertFalse(immunefiGuard.isAllowedToDelegateCall(address(this)));

        bytes memory data = "";
        uint256 valueToSend = 1.1 ether;
        vm.deal(address(vault), valueToSend);
        bytes memory txHashData = vault.encodeTransactionData({
            to: address(this),
            value: valueToSend,
            data: data,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        bytes memory signature = _signData(vaultSignerPk, txHashData);

        vault.execTransaction(
            address(this),
            valueToSend,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );
    }

    function testScopeGuardCheckTransactionBranches() public {
        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 valueToSend = 1.1 ether;
        vm.deal(address(vault), valueToSend);
        bytes memory txHashData = vault.encodeTransactionData({
            to: address(this),
            value: valueToSend,
            data: data,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        bytes memory signature = _signData(vaultSignerPk, txHashData);

        vm.prank(protocolOwner);
        immunefiGuard.setTargetAllowed(address(this), true);

        vm.expectRevert("Cannot send ETH to this target");
        vault.execTransaction(
            address(this),
            valueToSend,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );

        vm.prank(protocolOwner);
        immunefiGuard.setValueAllowedOnTarget(address(this), true);

        vault.execTransaction(
            address(this),
            valueToSend,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );

        // rework hash and sig due to nonce change
        txHashData = vault.encodeTransactionData({
            to: address(this),
            value: valueToSend,
            data: data,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        signature = _signData(vaultSignerPk, txHashData);

        vm.prank(protocolOwner);
        immunefiGuard.setScoped(address(this), true);

        vm.expectRevert("Target function is not allowed");
        vault.execTransaction(
            address(this),
            valueToSend,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );

        // rework hash and sig to change data
        data = abi.encodePacked(bytes2(0x1234)); // make it less than 4bytes
        txHashData = vault.encodeTransactionData({
            to: address(this),
            value: valueToSend,
            data: data,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        signature = _signData(vaultSignerPk, txHashData);

        vm.expectRevert("Function signature too short");
        vault.execTransaction(
            address(this),
            valueToSend,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );
    }

    function testScopeGuardSetupBranches() public {
        ScopeGuard scopeGuard = new ScopeGuard();

        bytes memory initData = abi.encodeCall(scopeGuard.setUp, (address(0)));
        vm.expectRevert("ScopeGuard: owner is the zero address");
        address(_deployTransparentProxy(address(scopeGuard), address(proxyAdmin), initData));
    }

    receive() external payable {}
}
