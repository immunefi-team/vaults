// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

// solhint-disable no-global-import,no-console
import "forge-std/Test.sol";
import "forge-std/console.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { Strings } from "openzeppelin-contracts/utils/Strings.sol";

import { ITimelockEvents } from "../../src/events/ITimelockEvents.sol";
import { Timelock } from "../../src/Timelock.sol";
import { Setups } from "./helpers/Setups.sol";

contract TimelockTest is Test, Setups, ITimelockEvents {
    bool internal vaultRecipientFunctionCalled;
    address internal queuer = makeAddr("queuer");

    // GnosisSafe event
    event ExecutionFailure(bytes32 txHash, uint256 payment);

    function setUp() public {
        _protocolSetup();

        vm.startPrank(protocolOwner);
        timelock.grantRole(timelock.QUEUER_ROLE(), queuer);
        vm.stopPrank();
    }

    function vaultRecipientFunction() external payable {
        vaultRecipientFunctionCalled = true;
    }

    function testSetupTimelockReverts() public {
        vm.expectRevert("Initializable: contract is already initialized");
        timelock.setUp(protocolOwner, address(immunefiModule), address(vaultFreezer));
    }

    function testQueuesAndExecutesTx() public {
        uint256 value = 1 ether;
        uint256 cooldown = 7 days;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(this), true);
        moduleGuard.setAllowedFunction(address(this), this.vaultRecipientFunction.selector, true);
        moduleGuard.setValueAllowedOnTarget(address(this), true);
        vm.stopPrank();

        // get timelock queue tx hash
        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 nonce = timelock.vaultTxNonce(address(vault));
        bytes memory txData = timelock.encodeQueueTransactionData(
            address(this),
            value,
            data,
            Enum.Operation.Call,
            address(vault),
            nonce
        );
        bytes32 txHash = keccak256(txData);

        assertEq(
            txHash,
            timelock.getQueueTransactionHash(address(this), value, data, Enum.Operation.Call, address(vault), nonce)
        );

        vm.expectEmit(true, true, true, true);
        emit TransactionQueued(txHash, address(this), address(vault), value, data, Enum.Operation.Call);
        vm.prank(queuer);
        timelock.queueTransaction(address(this), value, data, Enum.Operation.Call, address(vault), cooldown, 0);

        assertEq(timelock.vaultTxNonce(address(vault)), nonce + 1);

        vm.warp(block.timestamp + 1 hours);
        assertFalse(timelock.canExecuteTransaction(txHash));

        vm.warp(block.timestamp + cooldown - 1 hours);
        assertTrue(timelock.canExecuteTransaction(txHash));

        vm.expectEmit(true, true, true, true);
        emit TransactionExecuted(txHash, address(this), address(vault), value, data, Enum.Operation.Call);
        _sendTxToVault(
            address(timelock),
            0,
            abi.encodeCall(timelock.executeTransaction, (txHash)),
            Enum.Operation.Call
        );
        assertEq(timelock.vaultTxNonce(address(vault)), nonce + 1);
        assertEq(address(vault).balance, 0);
    }

    function testWrongSignerFailsInQueueAndExecute() public {
        uint256 value = 1 ether;
        uint256 cooldown = 7 days;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(this), true);
        moduleGuard.setAllowedFunction(address(this), this.vaultRecipientFunction.selector, true);
        moduleGuard.setValueAllowedOnTarget(address(this), true);
        vm.stopPrank();

        // get timelock queue tx hash, just to advance NONCE
        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 nonce = timelock.vaultTxNonce(address(vault));
        bytes memory txData = timelock.encodeQueueTransactionData(
            address(this),
            value,
            data,
            Enum.Operation.Call,
            address(vault),
            nonce
        );

        bytes32 txHash = keccak256(txData);

        vm.prank(queuer);
        timelock.queueTransaction(address(this), value, data, Enum.Operation.Call, address(vault), cooldown, 0);

        vm.warp(block.timestamp + cooldown);

        vm.expectRevert("Timelock: only vault can execute transaction");
        timelock.executeTransaction(txHash);
    }

    function testTransactionInCooldownRevertsExecution() public {
        uint256 value = 1 ether;
        uint256 cooldown = 7 days;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(this), true);
        moduleGuard.setAllowedFunction(address(this), this.vaultRecipientFunction.selector, true);
        moduleGuard.setValueAllowedOnTarget(address(this), true);
        vm.stopPrank();

        // get timelock queue tx hash
        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 nonce = timelock.vaultTxNonce(address(vault));
        bytes memory txData = timelock.encodeQueueTransactionData(
            address(this),
            value,
            data,
            Enum.Operation.Call,
            address(vault),
            nonce
        );

        bytes32 txHash = keccak256(txData);

        vm.prank(queuer);
        timelock.queueTransaction(address(this), value, data, Enum.Operation.Call, address(vault), cooldown, 0);

        vm.warp(block.timestamp + cooldown - 1 hours);
        assertFalse(timelock.canExecuteTransaction(txHash));

        {
            bytes memory dataVault = abi.encodeCall(timelock.executeTransaction, (txHash));
            bytes memory txHashData = vault.encodeTransactionData({
                to: address(timelock),
                value: 0,
                data: dataVault,
                operation: Enum.Operation.Call,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: address(0),
                refundReceiver: address(0),
                _nonce: vault.nonce()
            });

            bytes memory signature = _signData(vaultSignerPk, txHashData);

            vm.expectRevert("GS013");
            vault.execTransaction(
                address(timelock),
                0,
                dataVault,
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(0),
                signature
            );
        }
    }

    function testTransactionExpiredRevertsExecution() public {
        uint256 value = 1 ether;
        uint256 cooldown = 7 days;
        uint256 expiration = 3600;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(this), true);
        moduleGuard.setAllowedFunction(address(this), this.vaultRecipientFunction.selector, true);
        moduleGuard.setValueAllowedOnTarget(address(this), true);
        vm.stopPrank();

        // get timelock queue tx hash
        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 nonce = timelock.vaultTxNonce(address(vault));
        bytes memory txData = timelock.encodeQueueTransactionData(
            address(this),
            value,
            data,
            Enum.Operation.Call,
            address(vault),
            nonce
        );
        bytes32 txHash = keccak256(txData);

        vm.prank(queuer);
        timelock.queueTransaction(
            address(this),
            value,
            data,
            Enum.Operation.Call,
            address(vault),
            cooldown,
            expiration
        );

        vm.warp(block.timestamp + cooldown + expiration);

        {
            bytes memory dataVault = abi.encodeCall(timelock.executeTransaction, (txHash));
            bytes memory txHashData = vault.encodeTransactionData({
                to: address(timelock),
                value: 0,
                data: dataVault,
                operation: Enum.Operation.Call,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: address(0),
                refundReceiver: address(0),
                _nonce: vault.nonce()
            });

            bytes memory signature = _signData(vaultSignerPk, txHashData);

            vm.expectRevert("GS013");
            vault.execTransaction(
                address(timelock),
                0,
                dataVault,
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(0),
                signature
            );
        }
    }

    function testTransactionCanceledRevertsExecution() public {
        uint256 value = 1 ether;
        uint256 cooldown = 7 days;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(this), true);
        moduleGuard.setAllowedFunction(address(this), this.vaultRecipientFunction.selector, true);
        moduleGuard.setValueAllowedOnTarget(address(this), true);
        vm.stopPrank();

        // get timelock queue tx hash
        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 nonce = timelock.vaultTxNonce(address(vault));
        bytes memory txData = timelock.encodeQueueTransactionData(
            address(this),
            value,
            data,
            Enum.Operation.Call,
            address(vault),
            nonce
        );
        bytes32 txHash = keccak256(txData);

        vm.prank(queuer);
        timelock.queueTransaction(address(this), value, data, Enum.Operation.Call, address(vault), cooldown, 0);

        vm.warp(block.timestamp + cooldown - 1 hours);

        vm.expectEmit(true, true, true, true);
        emit TransactionCanceled(txHash, address(this), address(vault), value, data, Enum.Operation.Call);
        _sendTxToVault(address(timelock), 0, abi.encodeCall(timelock.cancelTransaction, (txHash)), Enum.Operation.Call);

        bytes memory dataVault = abi.encodeCall(timelock.executeTransaction, (txHash));
        bytes memory txHashData = vault.encodeTransactionData({
            to: address(timelock),
            value: 0,
            data: dataVault,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        bytes memory signature = _signData(vaultSignerPk, txHashData);

        vm.expectRevert("GS013");
        vault.execTransaction(
            address(timelock),
            0,
            dataVault,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );
    }

    function testTransactionOperationsRevertWhenVaultFrozen() public {
        uint256 value = 1 ether;
        uint256 cooldown = 7 days;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(this), true);
        moduleGuard.setAllowedFunction(address(this), this.vaultRecipientFunction.selector, true);
        moduleGuard.setValueAllowedOnTarget(address(this), true);
        vm.stopPrank();

        // get timelock queue tx hash
        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 nonce = timelock.vaultTxNonce(address(vault));
        bytes memory txData = timelock.encodeQueueTransactionData(
            address(this),
            value,
            data,
            Enum.Operation.Call,
            address(vault),
            nonce
        );
        bytes32 txHash = keccak256(txData);

        // freeze vault
        vm.startPrank(protocolOwner);
        vaultFreezer.grantRole(vaultFreezer.FREEZER_ROLE(), protocolOwner);
        vaultFreezer.freezeVault(address(vault));
        vm.stopPrank();

        vm.startPrank(queuer);
        vm.expectRevert("Timelock: vault is frozen");
        timelock.queueTransaction(address(this), value, data, Enum.Operation.Call, address(vault), cooldown, 0);
        vm.stopPrank();

        // unfreeze vault to queue tx
        vm.prank(protocolOwner);
        vaultFreezer.unfreezeVault(address(vault));

        vm.prank(queuer);
        timelock.queueTransaction(address(this), value, data, Enum.Operation.Call, address(vault), cooldown, 0);

        // advance to execution time
        vm.warp(block.timestamp + cooldown);

        // freeze vault to revert on next transaction operations
        vm.prank(protocolOwner);
        vaultFreezer.freezeVault(address(vault));

        {
            bytes memory dataVault = abi.encodeCall(timelock.executeTransaction, (txHash));
            bytes memory txHashData = vault.encodeTransactionData({
                to: address(timelock),
                value: 0,
                data: dataVault,
                operation: Enum.Operation.Call,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: address(0),
                refundReceiver: address(0),
                _nonce: vault.nonce()
            });

            bytes memory signature = _signData(vaultSignerPk, txHashData);

            vm.expectRevert("GS013");
            vault.execTransaction(
                address(timelock),
                0,
                dataVault,
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(0),
                signature
            );
        }

        {
            bytes memory dataVault = abi.encodeCall(timelock.cancelTransaction, (txHash));
            bytes memory txHashData = vault.encodeTransactionData({
                to: address(timelock),
                value: 0,
                data: dataVault,
                operation: Enum.Operation.Call,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: address(0),
                refundReceiver: address(0),
                _nonce: vault.nonce()
            });

            bytes memory signature = _signData(vaultSignerPk, txHashData);

            vm.expectRevert("GS013");
            vault.execTransaction(
                address(timelock),
                0,
                dataVault,
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(0),
                signature
            );
        }
    }

    function testTimelockSetupBranches() public {
        Timelock newTimelock = new Timelock();

        bytes memory initData = abi.encodeCall(
            newTimelock.setUp,
            (address(0), address(immunefiModule), address(vaultFreezer))
        );
        vm.expectRevert("Timelock: owner cannot be 0x00");
        address(_deployTransparentProxy(address(newTimelock), address(proxyAdmin), initData));

        initData = abi.encodeCall(newTimelock.setUp, (protocolOwner, address(0), address(vaultFreezer)));
        vm.expectRevert("Timelock: module cannot be 0x00");
        address(_deployTransparentProxy(address(newTimelock), address(proxyAdmin), initData));

        initData = abi.encodeCall(newTimelock.setUp, (protocolOwner, address(immunefiModule), address(0)));
        vm.expectRevert("Timelock: vault freezer cannot be 0x00");
        address(_deployTransparentProxy(address(newTimelock), address(proxyAdmin), initData));
    }

    function testBaseTimelockSetsByAdmin() public {
        vm.startPrank(protocolOwner);

        // setModule
        vm.expectEmit(true, false, false, false);
        emit ModuleSet(address(0xdead));
        timelock.setModule(address(0xdead));
        assertEq(address(timelock.immunefiModule()), address(0xdead));

        // setVaultFreezer
        vm.expectEmit(true, false, false, false);
        emit VaultFreezerSet(address(0xdead));
        timelock.setVaultFreezer(address(0xdead));
        assertEq(address(timelock.vaultFreezer()), address(0xdead));

        vm.stopPrank();
    }

    function testExpirationZeroMakesRequestsNeverExpire() public {
        uint256 value = 1 ether;
        uint256 cooldown = 7 days;
        uint256 expiration = 0;
        vm.deal(address(vault), value);

        vm.startPrank(protocolOwner);
        // set right permissions on moduleGuard
        moduleGuard.setTargetAllowed(address(this), true);
        moduleGuard.setAllowedFunction(address(this), this.vaultRecipientFunction.selector, true);
        moduleGuard.setValueAllowedOnTarget(address(this), true);
        vm.stopPrank();

        // get timelock queue tx hash
        bytes memory data = abi.encodeCall(this.vaultRecipientFunction, ());
        uint256 nonce = timelock.vaultTxNonce(address(vault));
        bytes memory txData = timelock.encodeQueueTransactionData(
            address(this),
            value,
            data,
            Enum.Operation.Call,
            address(vault),
            nonce
        );
        bytes32 txHash = keccak256(txData);

        vm.prank(queuer);
        timelock.queueTransaction(
            address(this),
            value,
            data,
            Enum.Operation.Call,
            address(vault),
            cooldown,
            expiration
        );

        vm.warp(block.timestamp + cooldown + expiration + 10_000 days);

        vm.expectEmit(true, true, true, true);
        emit TransactionExecuted(txHash, address(this), address(vault), value, data, Enum.Operation.Call);
        _sendTxToVault(
            address(timelock),
            0,
            abi.encodeCall(timelock.executeTransaction, (txHash)),
            Enum.Operation.Call
        );
        assertEq(timelock.vaultTxNonce(address(vault)), nonce + 1);
        assertEq(address(vault).balance, 0);
    }

    function testGetsTxHashesFilteredBySighash() public {
        bytes memory firstData = abi.encodeWithSignature("firstFunction(uint256)", 1);
        bytes4 firstSighash = bytes4(keccak256("firstFunction(uint256)"));
        uint256 firstFrequency = 25;

        bytes memory secondData = abi.encodeWithSignature("secondFunction(uint256)", 1);
        // bytes4 secondSighash = bytes4(keccak256("secondFunction(uint256)"));
        uint256 secondFrequency = 50;

        bytes memory thirdData = abi.encodeWithSignature("thirdFunction()", "");
        bytes4 thirdSighash = bytes4(keccak256("thirdFunction()"));
        uint256 thirdFrequency = 3;

        for (uint i; i < firstFrequency; i++) {
            _queueVaultDummyTx(firstData);
            _queueVaultDummyTx(secondData);
        }
        for (uint i; i < thirdFrequency; i++) {
            _queueVaultDummyTx(thirdData);
        }
        for (uint i; i < secondFrequency - firstFrequency; i++) {
            _queueVaultDummyTx(secondData);
        }

        uint256 totalLength = firstFrequency + secondFrequency + thirdFrequency;

        Timelock.TxDetails[] memory txDetails = timelock.getVaultTxsPaginated(address(vault), 1, 10, false);
        assertEq(txDetails.length, 10);
        assertEq(txDetails[0].index, 1);
        assertEq(txDetails[9].index, 10);

        txDetails = timelock.getVaultTxsPaginated(address(vault), totalLength - 1 - 2, 10, true);
        assertEq(txDetails.length, 3);
        assertEq(txDetails[0].index, 2);
        assertEq(txDetails[1].index, 1);
        assertEq(txDetails[2].index, 0);

        txDetails = timelock.getVaultTxsPaginatedBySighash(address(vault), 0, 10, firstSighash, false);
        assertEq(txDetails.length, 10);
        assertEq(txDetails[0].index, 0);
        assertEq(txDetails[1].index, 2);
        assertEq(txDetails[2].index, 4);

        txDetails = timelock.getVaultTxsPaginatedBySighash(address(vault), 1, 100, firstSighash, false);
        assertEq(txDetails.length, firstFrequency - 1);
        assertEq(txDetails[0].index, 2);
        assertEq(txDetails[1].index, 4);

        txDetails = timelock.getVaultTxsPaginatedBySighash(
            address(vault),
            totalLength - 1 - 10,
            100,
            firstSighash,
            true
        );
        assertEq(txDetails.length, 6);
        assertEq(txDetails[0].index, 10);
        assertEq(txDetails[1].index, 8);
        assertEq(txDetails[5].index, 0);

        txDetails = timelock.getVaultTxsPaginatedBySighash(address(vault), 30, 5, thirdSighash, false);
        assertEq(txDetails.length, thirdFrequency);
        assertEq(txDetails[0].index, 50);
        assertEq(txDetails[1].index, 51);

        txDetails = timelock.getVaultTxsPaginatedBySighash(address(vault), totalLength - 1 - 51, 5, thirdSighash, true);
        assertEq(txDetails.length, 2);
        assertEq(txDetails[0].index, 51);
        assertEq(txDetails[1].index, 50);
    }

    function _queueVaultDummyTx(bytes memory data) private {
        vm.prank(queuer);
        timelock.queueTransaction(address(this), 0, data, Enum.Operation.Call, address(vault), 60, 3600);
    }
}
