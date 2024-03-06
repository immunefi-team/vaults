// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

// solhint-disable no-global-import,no-console
import "forge-std/Test.sol";
import "forge-std/console.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { Strings } from "openzeppelin-contracts/utils/Strings.sol";

import { Rewards } from "../../src/common/Rewards.sol";
import { Denominations } from "../../src/oracles/chainlink/Denominations.sol";
import { IRewardTimelockEvents } from "../../src/events/IRewardTimelockEvents.sol";
import { RewardTimelock } from "../../src/RewardTimelock.sol";
import { Setups } from "./helpers/Setups.sol";

contract RewardTimelockTest is Test, Setups, IRewardTimelockEvents {
    // GnosisSafe event
    event ExecutionFailure(bytes32 txHash, uint256 payment);

    function setUp() public {
        _protocolSetup();
    }

    function testSetupRewardTimelockReverts() public {
        vm.expectRevert("Initializable: contract is already initialized");
        rewardTimelock.setUp(
            protocolOwner,
            address(immunefiModule),
            address(vaultFreezer),
            address(vaultDelegate),
            address(priceConsumer),
            address(arbitration),
            1 days,
            7 days
        );
    }

    function testQueuesAndExecutesRewardTx() public {
        uint256 value = 1.1 ether;
        uint256 dollarAmount = 2000;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        uint256 nonce = rewardTimelock.vaultTxNonce(address(vault));
        bytes32 txHash = rewardTimelock.getQueueTransactionHash(address(this), dollarAmount, address(vault), nonce);

        // Mock vaultIsInArbitration
        vm.mockCall(
            address(arbitration),
            abi.encodeCall(arbitration.vaultIsInArbitration, (address(vault))),
            abi.encode(true)
        );

        vm.expectEmit(true, true, true, true);
        emit TransactionQueued(txHash, address(this), address(vault), dollarAmount);
        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.queueRewardTransaction, (address(this), dollarAmount)),
            Enum.Operation.Call
        );

        assertEq(rewardTimelock.vaultTxNonce(address(vault)), nonce + 1);

        vm.warp(block.timestamp + 1 hours);
        assertFalse(rewardTimelock.canExecuteTransaction(txHash));

        vm.warp(block.timestamp + rewardTimelock.txCooldown() - 1 hours);
        assertTrue(rewardTimelock.canExecuteTransaction(txHash));

        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](0);

        // Mock priceConsumer
        vm.mockCall(
            address(priceConsumer),
            abi.encodeCall(priceConsumer.tryGetSaneUsdPrice18Decimals, (Denominations.ETH)),
            abi.encode(uint256(2000) * 10 ** 18)
        );

        vm.expectEmit(true, true, true, true);
        emit TransactionExecuted(txHash, address(this), address(vault), dollarAmount, erc20Rewards, 1 ether);
        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.executeRewardTransaction, (txHash, 0, erc20Rewards, 1 ether, 50_000)),
            Enum.Operation.Call
        );
        assertEq(rewardTimelock.vaultTxNonce(address(vault)), nonce + 1);
        assertEq(address(vault).balance, 0);
    }

    function testTransactionInCooldownRevertsExecution() public {
        uint256 value = 1 ether;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        uint256 nonce = rewardTimelock.vaultTxNonce(address(vault));
        bytes32 txHash = rewardTimelock.getQueueTransactionHash(address(this), 2000, address(vault), nonce);

        // Mock vaultIsInArbitration
        vm.mockCall(
            address(arbitration),
            abi.encodeCall(arbitration.vaultIsInArbitration, (address(vault))),
            abi.encode(true)
        );

        vm.expectEmit(true, true, true, true);
        emit TransactionQueued(txHash, address(this), address(vault), 2000);
        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.queueRewardTransaction, (address(this), 2000)),
            Enum.Operation.Call
        );

        assertEq(rewardTimelock.vaultTxNonce(address(vault)), nonce + 1);

        vm.warp(block.timestamp + 1 hours);
        assertFalse(rewardTimelock.canExecuteTransaction(txHash));

        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](0);

        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.executeRewardTransaction, (txHash, 0, erc20Rewards, 1 ether, 50_000)),
            Enum.Operation.Call,
            true
        );
    }

    function testTransactionExpiredRevertsExecution() public {
        uint256 value = 1 ether;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        uint256 nonce = rewardTimelock.vaultTxNonce(address(vault));
        bytes32 txHash = rewardTimelock.getQueueTransactionHash(address(this), 2000, address(vault), nonce);

        // Mock vaultIsInArbitration
        vm.mockCall(
            address(arbitration),
            abi.encodeCall(arbitration.vaultIsInArbitration, (address(vault))),
            abi.encode(true)
        );

        vm.expectEmit(true, true, true, true);
        emit TransactionQueued(txHash, address(this), address(vault), 2000);
        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.queueRewardTransaction, (address(this), 2000)),
            Enum.Operation.Call
        );

        assertEq(rewardTimelock.vaultTxNonce(address(vault)), nonce + 1);

        vm.warp(block.timestamp + rewardTimelock.txCooldown() + rewardTimelock.txExpiration());
        assertFalse(rewardTimelock.canExecuteTransaction(txHash));

        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](0);

        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.executeRewardTransaction, (txHash, 0, erc20Rewards, 1 ether, 50_000)),
            Enum.Operation.Call,
            true
        );
    }

    function testTransactionCanceledRevertsExecution() public {
        uint256 value = 1 ether;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        uint256 nonce = rewardTimelock.vaultTxNonce(address(vault));
        bytes32 txHash = rewardTimelock.getQueueTransactionHash(address(this), 2000, address(vault), nonce);

        // Mock vaultIsInArbitration
        vm.mockCall(
            address(arbitration),
            abi.encodeCall(arbitration.vaultIsInArbitration, (address(vault))),
            abi.encode(true)
        );

        vm.expectEmit(true, true, true, true);
        emit TransactionQueued(txHash, address(this), address(vault), 2000);
        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.queueRewardTransaction, (address(this), 2000)),
            Enum.Operation.Call
        );

        assertEq(rewardTimelock.vaultTxNonce(address(vault)), nonce + 1);

        vm.warp(block.timestamp + 1 hours);
        assertFalse(rewardTimelock.canExecuteTransaction(txHash));

        // Cancel transaction
        vm.expectEmit(true, true, true, true);
        emit TransactionCanceled(txHash, address(this), address(vault), 2000);
        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.cancelTransaction, (txHash)),
            Enum.Operation.Call
        );

        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](0);

        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.executeRewardTransaction, (txHash, 0, erc20Rewards, 1 ether, 50_000)),
            Enum.Operation.Call,
            true
        );
    }

    function testTransactionOperationsRevertWhenVaultFrozen() public {
        uint256 value = 1 ether;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        // freeze vault
        vm.startPrank(protocolOwner);
        vaultFreezer.grantRole(vaultFreezer.FREEZER_ROLE(), protocolOwner);
        vaultFreezer.freezeVault(address(vault));
        vm.stopPrank();

        uint256 nonce = rewardTimelock.vaultTxNonce(address(vault));
        bytes32 txHash = rewardTimelock.getQueueTransactionHash(address(this), 2000, address(vault), nonce);

        // Mock vaultIsInArbitration
        vm.mockCall(
            address(arbitration),
            abi.encodeCall(arbitration.vaultIsInArbitration, (address(vault))),
            abi.encode(true)
        );

        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.queueRewardTransaction, (address(this), 2000)),
            Enum.Operation.Call,
            true
        );

        // unfreeze vault to queue tx
        vm.prank(protocolOwner);
        vaultFreezer.unfreezeVault(address(vault));

        vm.expectEmit(true, true, true, true);
        emit TransactionQueued(txHash, address(this), address(vault), 2000);
        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.queueRewardTransaction, (address(this), 2000)),
            Enum.Operation.Call
        );

        assertEq(rewardTimelock.vaultTxNonce(address(vault)), nonce + 1);

        vm.warp(block.timestamp + rewardTimelock.txCooldown());
        assertTrue(rewardTimelock.canExecuteTransaction(txHash));

        // freeze vault to revert on next transaction operations
        vm.prank(protocolOwner);
        vaultFreezer.freezeVault(address(vault));

        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](0);

        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.executeRewardTransaction, (txHash, 0, erc20Rewards, 1 ether, 50_000)),
            Enum.Operation.Call,
            true
        );
    }

    function testTransactionOperationsRevertWhenVaultNotInArbitration() public {
        uint256 value = 1 ether;
        vm.deal(address(vault), value);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        uint256 nonce = rewardTimelock.vaultTxNonce(address(vault));
        bytes32 txHash = rewardTimelock.getQueueTransactionHash(address(this), 2000, address(vault), nonce);

        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.queueRewardTransaction, (address(this), 2000)),
            Enum.Operation.Call,
            true
        );

        // Mock vaultIsInArbitration
        vm.mockCall(
            address(arbitration),
            abi.encodeCall(arbitration.vaultIsInArbitration, (address(vault))),
            abi.encode(true)
        );

        vm.expectEmit(true, true, true, true);
        emit TransactionQueued(txHash, address(this), address(vault), 2000);
        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.queueRewardTransaction, (address(this), 2000)),
            Enum.Operation.Call
        );

        assertEq(rewardTimelock.vaultTxNonce(address(vault)), nonce + 1);

        vm.warp(block.timestamp + rewardTimelock.txCooldown());
        assertTrue(rewardTimelock.canExecuteTransaction(txHash));

        // Mock vaultIsInArbitration to false
        vm.mockCall(
            address(arbitration),
            abi.encodeCall(arbitration.vaultIsInArbitration, (address(vault))),
            abi.encode(false)
        );

        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](0);

        _sendTxToVault(
            address(rewardTimelock),
            0,
            abi.encodeCall(rewardTimelock.executeRewardTransaction, (txHash, 0, erc20Rewards, 1 ether, 50_000)),
            Enum.Operation.Call,
            true
        );
    }

    function testRewardTimelockSetupBranches() public {
        RewardTimelock newRewardTimelock = new RewardTimelock();

        bytes memory initData = abi.encodeCall(
            newRewardTimelock.setUp,
            (
                address(0),
                address(immunefiModule),
                address(vaultFreezer),
                address(vaultDelegate),
                address(priceConsumer),
                address(arbitration),
                1 days,
                7 days
            )
        );
        vm.expectRevert("RewardTimelock: owner cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardTimelock), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newRewardTimelock.setUp,
            (
                protocolOwner,
                address(0),
                address(vaultFreezer),
                address(vaultDelegate),
                address(priceConsumer),
                address(arbitration),
                1 days,
                7 days
            )
        );
        vm.expectRevert("RewardTimelock: module cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardTimelock), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newRewardTimelock.setUp,
            (
                protocolOwner,
                address(immunefiModule),
                address(0),
                address(vaultDelegate),
                address(priceConsumer),
                address(arbitration),
                1 days,
                7 days
            )
        );
        vm.expectRevert("RewardTimelock: vault freezer cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardTimelock), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newRewardTimelock.setUp,
            (
                protocolOwner,
                address(immunefiModule),
                address(vaultFreezer),
                address(0),
                address(priceConsumer),
                address(arbitration),
                1 days,
                7 days
            )
        );
        vm.expectRevert("RewardTimelock: vault delegate cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardTimelock), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newRewardTimelock.setUp,
            (
                protocolOwner,
                address(immunefiModule),
                address(vaultFreezer),
                address(vaultDelegate),
                address(0),
                address(arbitration),
                1 days,
                7 days
            )
        );
        vm.expectRevert("RewardTimelock: price consumer cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardTimelock), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newRewardTimelock.setUp,
            (
                protocolOwner,
                address(immunefiModule),
                address(vaultFreezer),
                address(vaultDelegate),
                address(priceConsumer),
                address(0),
                1 days,
                7 days
            )
        );
        vm.expectRevert("RewardTimelock: arbitration cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardTimelock), address(proxyAdmin), initData));
    }

    function testBaseRewardTimelockSetsByAdmin() public {
        vm.startPrank(protocolOwner);

        // setModule
        vm.expectEmit(true, false, false, false);
        emit ModuleSet(address(0xdead));
        rewardTimelock.setModule(address(0xdead));
        assertEq(address(rewardTimelock.immunefiModule()), address(0xdead));

        // setVaultFreezer
        vm.expectEmit(true, false, false, false);
        emit VaultFreezerSet(address(0xdead));
        rewardTimelock.setVaultFreezer(address(0xdead));
        assertEq(address(rewardTimelock.vaultFreezer()), address(0xdead));

        // setVaultDelegate
        vm.expectEmit(true, false, false, false);
        emit VaultDelegateSet(address(0xdead));
        rewardTimelock.setVaultDelegate(address(0xdead));
        assertEq(address(rewardTimelock.vaultDelegate()), address(0xdead));

        // setPriceConsumer
        vm.expectEmit(true, false, false, false);
        emit PriceConsumerSet(address(0xdead));
        rewardTimelock.setPriceConsumer(address(0xdead));
        assertEq(address(rewardTimelock.priceConsumer()), address(0xdead));

        vm.stopPrank();
    }

    receive() external payable {}
}
