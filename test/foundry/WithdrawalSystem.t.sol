// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { ERC20PresetMinterPauser } from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

import { Rewards } from "../../src/common/Rewards.sol";
import { IWithdrawalSystemEvents } from "../../src/events/IWithdrawalSystemEvents.sol";
import { WithdrawalSystem } from "../../src/WithdrawalSystem.sol";
import { Setups } from "./helpers/Setups.sol";

contract WithdrawalSystemTest is Test, Setups, IWithdrawalSystemEvents {
    function setUp() public {
        _protocolSetup();
    }

    function testSetupWithdrawalSystemReverts() public {
        vm.expectRevert("Initializable: contract is already initialized");
        withdrawalSystem.setUp(protocolOwner, address(timelock), address(vaultDelegate), 1 days, 30 days);
    }

    function testWithdrawlsTokensAndEtherSuccessfully() public {
        uint256 tokenInitialAmount = 10 ether;
        uint256 nativeInitialAmount = 10 ether;
        vm.deal(address(vault), nativeInitialAmount);
        ERC20PresetMinterPauser token = new ERC20PresetMinterPauser("Test", "TST");
        token.mint(address(vault), tokenInitialAmount);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.withdrawFunds.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        uint256 tokenAmount = 5 ether;
        uint256 nativeAmount = 5 ether;
        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](1);
        erc20Rewards[0] = Rewards.ERC20Reward({ token: address(token), amount: tokenAmount });

        bytes32 txHash = withdrawalSystem.getWithdrawalHash(
            withdrawalReceiver,
            erc20Rewards,
            nativeAmount,
            address(vault),
            timelock.vaultTxNonce(address(vault))
        );

        _sendTxToVault(
            address(withdrawalSystem),
            0,
            abi.encodeCall(withdrawalSystem.queueVaultWithdrawal, (withdrawalReceiver, erc20Rewards, nativeAmount)),
            Enum.Operation.Call
        );

        vm.warp(block.timestamp + withdrawalSystem.txCooldown());

        _sendTxToVault(
            address(timelock),
            0,
            abi.encodeCall(timelock.executeTransaction, (txHash)),
            Enum.Operation.Call
        );

        assertEq(address(vault).balance, nativeInitialAmount - nativeAmount);
        assertEq(token.balanceOf(address(vault)), tokenInitialAmount - tokenAmount);
        assertEq(withdrawalReceiver.balance, nativeAmount);
        assertEq(token.balanceOf(withdrawalReceiver), tokenAmount);
    }

    function testWithdrawalSystemSetupBranches() public {
        uint256 cooldown = 7 days;
        uint256 expiration = 30 days;

        WithdrawalSystem newSystem = new WithdrawalSystem();

        bytes memory initData = abi.encodeCall(
            newSystem.setUp,
            (address(0), address(timelock), address(vaultDelegate), cooldown, expiration)
        );
        vm.expectRevert("Ownable: new owner is the zero address");
        address(_deployTransparentProxy(address(newSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newSystem.setUp,
            (protocolOwner, address(0), address(vaultDelegate), cooldown, expiration)
        );
        vm.expectRevert("WithdrawalSystem: timelock cannot be 0x00");
        address(_deployTransparentProxy(address(newSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newSystem.setUp,
            (protocolOwner, address(timelock), address(0), cooldown, expiration)
        );
        vm.expectRevert("WithdrawalSystem: vaultDelegate cannot be 0x00");
        address(_deployTransparentProxy(address(newSystem), address(proxyAdmin), initData));
    }

    function testBaseWithdrawalSystemSetsByAdmin() public {
        vm.startPrank(protocolOwner);

        // setTimelock
        vm.expectEmit(true, false, false, false);
        emit TimelockSet(address(0xdead));
        withdrawalSystem.setTimelock(address(0xdead));
        assertEq(address(withdrawalSystem.timelock()), address(0xdead));

        // setVaultDelegate
        vm.expectEmit(true, false, false, false);
        emit VaultDelegateSet(address(0xbeef));
        withdrawalSystem.setVaultDelegate(address(0xbeef));
        assertEq(address(withdrawalSystem.vaultDelegate()), address(0xbeef));

        vm.stopPrank();
    }
}
