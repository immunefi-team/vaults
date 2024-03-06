// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { ERC20PresetMinterPauser } from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

import { IArbitrationEvents } from "../../src/events/IArbitrationEvents.sol";
import { ArbitrationBase } from "../../src/base/ArbitrationBase.sol";
import { Arbitration } from "../../src/Arbitration.sol";
import { Rewards } from "../../src/common/Rewards.sol";
import { Setups } from "./helpers/Setups.sol";

contract ArbitrationTest is Test, Setups, IArbitrationEvents {
    address internal arbiter = makeAddr("arbiter");

    function setUp() public {
        _protocolSetup();

        vm.startPrank(protocolOwner);
        arbitration.grantRole(arbitration.ARBITER_ROLE(), arbiter);
        vm.stopPrank();
    }

    function testSetupArbitrationReverts() public {
        vm.expectRevert("Initializable: contract is already initialized");
        arbitration.setUp(
            protocolOwner,
            address(immunefiModule),
            address(rewardSystem),
            address(vaultDelegate),
            address(testToken),
            1 ether,
            feeRecipient
        );
    }

    function testRequestArbWhitehatSucceeds() public {
        uint96 referenceId = 1;

        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(address(arbitration.feeToken()));

        vm.startPrank(protocolOwner);
        token.mint(whitehat, arbitration.feeAmount());
        vm.stopPrank();

        vm.startPrank(whitehat);
        token.approve(address(arbitration), arbitration.feeAmount());
        vm.stopPrank();

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendTokens.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        bytes memory signature = _signData(
            whitehatPk,
            arbitration.encodeRequestArbFromWhitehatData(referenceId, address(vault))
        );

        vm.startPrank(whitehat);
        vm.expectEmit(true, true, true, false);
        emit ArbitrationRequestedByWhitehat(referenceId, address(vault), whitehat);
        arbitration.requestArbWhitehat(referenceId, address(vault), whitehat, signature);
        vm.stopPrank();

        {
            bytes32 arbitrationId = arbitration.computeArbitrationId(referenceId, address(vault), whitehat);
            (
                uint40 requestTimestamp,
                ArbitrationBase.ArbitrationStatus status,
                address _vault,
                uint96 _referenceId,
                address _whitehat
            ) = arbitration.arbData(arbitrationId);

            assertEq(requestTimestamp, uint40(block.timestamp));
            assertEq(_vault, address(vault));
            assertEq(_referenceId, referenceId);
            assertEq(_whitehat, whitehat);
            assertEq(uint256(status), uint256(ArbitrationBase.ArbitrationStatus.Open));

            assertEq(token.balanceOf(address(arbitration.feeRecipient())), arbitration.feeAmount());
        }
    }

    function testRequestArbWhitehatSucceedsWithZeroFee() public {
        vm.prank(protocolOwner);
        arbitration.setFeeAmount(0);

        uint96 referenceId = 1;

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendTokens.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        bytes memory signature = _signData(
            whitehatPk,
            arbitration.encodeRequestArbFromWhitehatData(referenceId, address(vault))
        );

        vm.startPrank(whitehat);
        vm.expectEmit(true, true, true, false);
        emit ArbitrationRequestedByWhitehat(referenceId, address(vault), whitehat);
        arbitration.requestArbWhitehat(referenceId, address(vault), whitehat, signature);
        vm.stopPrank();

        {
            bytes32 arbitrationId = arbitration.computeArbitrationId(referenceId, address(vault), whitehat);
            (
                uint40 requestTimestamp,
                ArbitrationBase.ArbitrationStatus status,
                address _vault,
                uint96 _referenceId,
                address _whitehat
            ) = arbitration.arbData(arbitrationId);

            assertEq(requestTimestamp, uint40(block.timestamp));
            assertEq(_vault, address(vault));
            assertEq(_referenceId, referenceId);
            assertEq(_whitehat, whitehat);
            assertEq(uint256(status), uint256(ArbitrationBase.ArbitrationStatus.Open));
        }
    }

    function testRequestArbVaultSucceedsWithWhitehatOpening() public {
        uint96 referenceId = 1;

        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(address(arbitration.feeToken()));

        vm.startPrank(protocolOwner);
        token.mint(address(vault), arbitration.feeAmount());
        token.mint(whitehat, arbitration.feeAmount());
        vm.stopPrank();

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendTokens.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false);
        emit ArbitrationRequestedByVault(referenceId, address(vault), whitehat);
        _sendTxToVault(
            address(arbitration),
            0,
            abi.encodeCall(arbitration.requestArbVault, (referenceId, whitehat)),
            Enum.Operation.Call
        );

        {
            bytes32 arbitrationId = arbitration.computeArbitrationId(referenceId, address(vault), whitehat);
            (
                uint40 requestTimestamp,
                ArbitrationBase.ArbitrationStatus status,
                address _vault,
                uint96 _referenceId,
                address _whitehat
            ) = arbitration.arbData(arbitrationId);

            assertEq(requestTimestamp, uint40(block.timestamp));
            assertEq(_vault, address(vault));
            assertEq(_referenceId, referenceId);
            assertEq(_whitehat, whitehat);
            assertEq(uint256(status), uint256(ArbitrationBase.ArbitrationStatus.Open));

            assertEq(token.balanceOf(arbitration.feeRecipient()), arbitration.feeAmount());
        }
    }

    function testArbSendsRewardAndCloses() public {
        uint96 referenceId = 1;

        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(address(arbitration.feeToken()));

        vm.startPrank(protocolOwner);
        token.mint(whitehat, arbitration.feeAmount());
        vm.stopPrank();

        vm.startPrank(whitehat);
        token.approve(address(arbitration), arbitration.feeAmount());
        vm.stopPrank();

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendTokens.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);

        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        bytes memory signature = _signData(
            whitehatPk,
            arbitration.encodeRequestArbFromWhitehatData(referenceId, address(vault))
        );

        vm.prank(whitehat);
        arbitration.requestArbWhitehat(referenceId, address(vault), whitehat, signature);

        vm.deal(address(vault), 110 ether);
        bytes32 arbitrationId = arbitration.computeArbitrationId(referenceId, address(vault), whitehat);

        vm.startPrank(arbiter);
        vm.expectEmit(true, false, false, false);
        emit ArbitrationClosed(arbitrationId);
        arbitration.enforceSendRewardWhitehat(
            arbitrationId,
            new Rewards.ERC20Reward[](0),
            100 ether,
            vaultDelegate.UNTRUSTED_TARGET_GAS_CAP(),
            true
        );
        vm.stopPrank();

        {
            (, ArbitrationBase.ArbitrationStatus status, , , ) = arbitration.arbData(arbitrationId);

            address feeToken = address(arbitration.feeToken());

            assertEq(uint256(status), uint256(ArbitrationBase.ArbitrationStatus.Closed));
            assertEq(address(vault).balance, 0);
            assertEq(whitehat.balance, 100 ether);
            assertEq(feeRecipient.balance, 10 ether);
            assertEq(ERC20PresetMinterPauser(feeToken).balanceOf(address(vault)), 0);
            assertEq(ERC20PresetMinterPauser(feeToken).balanceOf(arbitration.feeRecipient()), arbitration.feeAmount());
        }
    }

    function testArbSendsRewardWithoutClosingAndThenClose() public {
        uint96 referenceId = 1;

        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(address(arbitration.feeToken()));

        vm.startPrank(protocolOwner);
        token.mint(whitehat, arbitration.feeAmount());
        vm.stopPrank();

        vm.startPrank(whitehat);
        token.approve(address(arbitration), arbitration.feeAmount());
        vm.stopPrank();

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendTokens.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);

        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        bytes memory signature = _signData(
            whitehatPk,
            arbitration.encodeRequestArbFromWhitehatData(referenceId, address(vault))
        );

        vm.prank(whitehat);
        arbitration.requestArbWhitehat(referenceId, address(vault), whitehat, signature);

        bytes32 arbitrationId = arbitration.computeArbitrationId(referenceId, address(vault), whitehat);
        vm.deal(address(vault), 110 ether);

        vm.startPrank(arbiter);
        arbitration.enforceSendRewardWhitehat(
            arbitrationId,
            new Rewards.ERC20Reward[](0),
            100 ether,
            vaultDelegate.UNTRUSTED_TARGET_GAS_CAP(),
            false
        );
        vm.stopPrank();

        {
            (, ArbitrationBase.ArbitrationStatus status, , , ) = arbitration.arbData(arbitrationId);

            address feeToken = address(arbitration.feeToken());

            assertEq(uint256(status), uint256(ArbitrationBase.ArbitrationStatus.Open));
            assertEq(address(vault).balance, 0);
            assertEq(whitehat.balance, 100 ether);
            assertEq(feeRecipient.balance, 10 ether);
            assertEq(ERC20PresetMinterPauser(feeToken).balanceOf(address(vault)), 0);
            assertEq(ERC20PresetMinterPauser(feeToken).balanceOf(arbitration.feeRecipient()), arbitration.feeAmount());
        }

        vm.startPrank(arbiter);
        vm.expectEmit(true, false, false, false);
        emit ArbitrationClosed(arbitrationId);
        arbitration.closeArbitration(arbitrationId);
        vm.stopPrank();

        {
            (, ArbitrationBase.ArbitrationStatus status, , , ) = arbitration.arbData(arbitrationId);
            assertEq(uint256(status), uint256(ArbitrationBase.ArbitrationStatus.Closed));
        }
    }

    function testArbSendsRewardNoFeesAndCloses() public {
        uint96 referenceId = 1;
        address newRecipient = makeAddr("newRecipient");
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(address(arbitration.feeToken()));

        vm.startPrank(protocolOwner);
        token.mint(whitehat, arbitration.feeAmount());
        vm.stopPrank();

        vm.startPrank(whitehat);
        token.approve(address(arbitration), arbitration.feeAmount());
        vm.stopPrank();

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendTokens.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);

        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        // set role on a new recipient
        vm.startPrank(protocolOwner);
        arbitration.grantRole(arbitration.ALLOWED_RECIPIENT_ROLE(), newRecipient);
        vm.stopPrank();

        bytes memory signature = _signData(
            whitehatPk,
            arbitration.encodeRequestArbFromWhitehatData(referenceId, address(vault))
        );

        vm.prank(whitehat);
        arbitration.requestArbWhitehat(referenceId, address(vault), whitehat, signature);

        bytes32 arbitrationId = arbitration.computeArbitrationId(referenceId, address(vault), whitehat);
        vm.deal(address(vault), 110 ether);

        vm.startPrank(arbiter);
        arbitration.enforceSendRewardNoFees(
            arbitrationId,
            newRecipient,
            new Rewards.ERC20Reward[](0),
            100 ether,
            vaultDelegate.UNTRUSTED_TARGET_GAS_CAP(),
            true
        );
        vm.stopPrank();

        {
            (, ArbitrationBase.ArbitrationStatus status, , , ) = arbitration.arbData(arbitrationId);

            address feeToken = address(arbitration.feeToken());

            assertEq(uint256(status), uint256(ArbitrationBase.ArbitrationStatus.Closed));
            assertEq(address(vault).balance, 10 ether);
            assertEq(newRecipient.balance, 100 ether);
            assertEq(feeRecipient.balance, 0);
            assertEq(ERC20PresetMinterPauser(feeToken).balanceOf(address(vault)), 0);
            assertEq(ERC20PresetMinterPauser(feeToken).balanceOf(arbitration.feeRecipient()), arbitration.feeAmount());
        }
    }

    function testArbSendsMultipleRewardsAndCloses() public {
        uint96 referenceId = 1;
        address newRecipient = makeAddr("newRecipient");
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(address(arbitration.feeToken()));

        vm.startPrank(protocolOwner);
        token.mint(whitehat, arbitration.feeAmount());
        vm.stopPrank();

        vm.startPrank(whitehat);
        token.approve(address(arbitration), arbitration.feeAmount());
        vm.stopPrank();

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendTokens.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);

        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        // set role on a new recipient
        vm.startPrank(protocolOwner);
        arbitration.grantRole(arbitration.ALLOWED_RECIPIENT_ROLE(), newRecipient);
        vm.stopPrank();

        bytes memory signature = _signData(
            whitehatPk,
            arbitration.encodeRequestArbFromWhitehatData(referenceId, address(vault))
        );

        vm.prank(whitehat);
        arbitration.requestArbWhitehat(referenceId, address(vault), whitehat, signature);

        vm.deal(address(vault), 110 ether);

        ArbitrationBase.MultipleEnforcementElement[] memory rewards = new ArbitrationBase.MultipleEnforcementElement[](
            2
        );
        rewards[0] = ArbitrationBase.MultipleEnforcementElement({
            withFees: true,
            recipient: whitehat,
            tokenAmounts: new Rewards.ERC20Reward[](0),
            nativeTokenAmount: 50 ether,
            gasToTarget: vaultDelegate.UNTRUSTED_TARGET_GAS_CAP()
        });
        rewards[1] = ArbitrationBase.MultipleEnforcementElement({
            withFees: false,
            recipient: newRecipient,
            tokenAmounts: new Rewards.ERC20Reward[](0),
            nativeTokenAmount: 50 ether,
            gasToTarget: vaultDelegate.UNTRUSTED_TARGET_GAS_CAP()
        });

        bytes32 arbitrationId = arbitration.computeArbitrationId(referenceId, address(vault), whitehat);

        vm.startPrank(arbiter);
        arbitration.enforceMultipleRewards(arbitrationId, rewards, true);
        vm.stopPrank();

        {
            (, ArbitrationBase.ArbitrationStatus status, , , ) = arbitration.arbData(arbitrationId);

            address feeToken = address(arbitration.feeToken());

            assertEq(uint256(status), uint256(ArbitrationBase.ArbitrationStatus.Closed));
            assertEq(address(vault).balance, 5 ether);
            assertEq(newRecipient.balance, 50 ether);
            assertEq(whitehat.balance, 50 ether);
            assertEq(feeRecipient.balance, 5 ether);
            assertEq(ERC20PresetMinterPauser(feeToken).balanceOf(address(vault)), 0);
            assertEq(ERC20PresetMinterPauser(feeToken).balanceOf(arbitration.feeRecipient()), arbitration.feeAmount());
        }
    }

    function testArbitrationSetupBranches() public {
        Arbitration newSystem = new Arbitration();

        bytes memory initData = abi.encodeCall(
            newSystem.setUp,
            (
                address(0),
                address(immunefiModule),
                address(rewardSystem),
                address(vaultDelegate),
                address(testToken),
                1 ether,
                feeRecipient
            )
        );
        vm.expectRevert("Arbitration: owner cannot be 0x00");
        address(_deployTransparentProxy(address(newSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newSystem.setUp,
            (
                protocolOwner,
                address(0),
                address(rewardSystem),
                address(vaultDelegate),
                address(testToken),
                1 ether,
                feeRecipient
            )
        );
        vm.expectRevert("ArbitrationBase: module cannot be 0x00");
        address(_deployTransparentProxy(address(newSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newSystem.setUp,
            (
                protocolOwner,
                address(immunefiModule),
                address(0),
                address(vaultDelegate),
                address(testToken),
                1 ether,
                feeRecipient
            )
        );
        vm.expectRevert("ArbitrationBase: rewardSystem cannot be 0x00");
        address(_deployTransparentProxy(address(newSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newSystem.setUp,
            (
                protocolOwner,
                address(immunefiModule),
                address(rewardSystem),
                address(0),
                address(testToken),
                1 ether,
                feeRecipient
            )
        );
        vm.expectRevert("ArbitrationBase: vaultDelegate cannot be 0x00");
        address(_deployTransparentProxy(address(newSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newSystem.setUp,
            (
                protocolOwner,
                address(immunefiModule),
                address(rewardSystem),
                address(vaultDelegate),
                address(0),
                1 ether,
                feeRecipient
            )
        );
        vm.expectRevert("ArbitrationBase: feeToken cannot be 0x00");
        address(_deployTransparentProxy(address(newSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newSystem.setUp,
            (
                protocolOwner,
                address(immunefiModule),
                address(rewardSystem),
                address(vaultDelegate),
                address(testToken),
                1 ether,
                address(0)
            )
        );
        vm.expectRevert("ArbitrationBase: feeRecipient cannot be 0x00");
        address(_deployTransparentProxy(address(newSystem), address(proxyAdmin), initData));
    }

    function testBaseArbitrationSetsByAdmin() public {
        vm.startPrank(protocolOwner);

        // setModule
        vm.expectEmit(false, false, false, true);
        emit ModuleSet(address(0xdead));
        arbitration.setModule(address(0xdead));
        assertEq(address(arbitration.immunefiModule()), address(0xdead));

        // setRewardSystem
        vm.expectEmit(false, false, false, true);
        emit RewardSystemSet(address(0xdead));
        arbitration.setRewardSystem(address(0xdead));
        assertEq(address(arbitration.rewardSystem()), address(0xdead));

        // setVaultDelegate
        vm.expectEmit(false, false, false, true);
        emit VaultDelegateSet(address(0xdead));
        arbitration.setVaultDelegate(address(0xdead));
        assertEq(address(arbitration.vaultDelegate()), address(0xdead));

        // setFeeToken
        vm.expectEmit(false, false, false, true);
        emit FeeTokenSet(address(0xdead));
        arbitration.setFeeToken(address(0xdead));
        assertEq(address(arbitration.feeToken()), address(0xdead));

        // setFeeAmount
        vm.expectEmit(false, false, false, true);
        emit FeeAmountSet(10 ether);
        arbitration.setFeeAmount(10 ether);
        assertEq(arbitration.feeAmount(), 10 ether);

        // setFeeRecipient
        vm.expectEmit(false, false, false, true);
        emit FeeRecipientSet(address(0xdead));
        arbitration.setFeeRecipient(address(0xdead));
        assertEq(arbitration.feeRecipient(), address(0xdead));

        vm.stopPrank();
    }
}
