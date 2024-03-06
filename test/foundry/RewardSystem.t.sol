// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { ERC20PresetMinterPauser } from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

import { Rewards } from "../../src/common/Rewards.sol";
import { IRewardSystemEvents } from "../../src/events/IRewardSystemEvents.sol";
import { RewardSystem } from "../../src/RewardSystem.sol";
import { Setups } from "./helpers/Setups.sol";

contract RewardSystemTest is Test, Setups, IRewardSystemEvents {
    address internal enforcer = makeAddr("enforcer");

    function setUp() public {
        _protocolSetup();
    }

    function testSetupRewardSystemReverts() public {
        vm.expectRevert("Initializable: contract is already initialized");
        rewardSystem.setUp(
            protocolOwner,
            address(immunefiModule),
            address(vaultDelegate),
            address(arbitration),
            address(vaultFreezer)
        );
    }

    function testRewardsTokensAndEtherSuccessfully() public {
        uint256 tokenInitialAmount = 10 ether;
        uint256 nativeInitialAmount = 10 ether;
        vm.deal(address(vault), nativeInitialAmount);
        ERC20PresetMinterPauser token = new ERC20PresetMinterPauser("Test", "TST");
        token.mint(address(vault), tokenInitialAmount);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        uint256 tokenAmount = 5 ether;
        uint256 nativeAmount = 5 ether;
        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](1);
        erc20Rewards[0] = Rewards.ERC20Reward({ token: address(token), amount: tokenAmount });

        _sendTxToVault(
            address(rewardSystem),
            0,
            abi.encodeCall(
                rewardSystem.sendRewardByVault,
                (0, whitehat, erc20Rewards, nativeAmount, vaultDelegate.UNTRUSTED_TARGET_GAS_CAP())
            ),
            Enum.Operation.Call
        );

        (uint16 fee, ) = vaultFees.getFee(address(vault));

        uint256 nativeFeeRecipientAmount = (nativeAmount * fee) / vaultFees.FEE_BASIS();
        uint256 tokenFeeRecipientAmount = (tokenAmount * fee) / vaultFees.FEE_BASIS();
        assertEq(address(feeRecipient).balance, nativeFeeRecipientAmount);
        assertEq(token.balanceOf(feeRecipient), tokenFeeRecipientAmount);
        assertEq(address(vault).balance, nativeInitialAmount - nativeAmount - nativeFeeRecipientAmount);
        assertEq(token.balanceOf(address(vault)), tokenInitialAmount - tokenAmount - tokenFeeRecipientAmount);
        assertEq(whitehat.balance, nativeAmount);
        assertEq(token.balanceOf(whitehat), tokenAmount);
    }

    function testSendRewardRevertsInArbitration() public {
        uint256 tokenInitialAmount = 10 ether;
        uint256 nativeInitialAmount = 10 ether;
        vm.deal(address(vault), nativeInitialAmount);
        ERC20PresetMinterPauser token = new ERC20PresetMinterPauser("Test", "TST");
        token.mint(address(vault), tokenInitialAmount);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        vm.stopPrank();

        uint256 tokenAmount = 5 ether;
        uint256 nativeAmount = 5 ether;
        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](1);
        erc20Rewards[0] = Rewards.ERC20Reward({ token: address(token), amount: tokenAmount });

        // Mock arbitration
        vm.mockCall(
            address(arbitration),
            abi.encodeWithSelector(arbitration.vaultIsInArbitration.selector, address(vault)),
            abi.encode(true)
        );

        uint256 gasToTarget = vaultDelegate.UNTRUSTED_TARGET_GAS_CAP();
        _sendTxToVault(
            address(rewardSystem),
            0,
            abi.encodeCall(rewardSystem.sendRewardByVault, (0, whitehat, erc20Rewards, nativeAmount, gasToTarget)),
            Enum.Operation.Call,
            true // expect revert
        );
    }

    function testEnforcesSendRewardsSuccessfully() public {
        uint256 tokenInitialAmount = 10 ether;
        uint256 nativeInitialAmount = 10 ether;
        vm.deal(address(vault), nativeInitialAmount);
        ERC20PresetMinterPauser token = new ERC20PresetMinterPauser("Test", "TST");
        token.mint(address(vault), tokenInitialAmount);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        rewardSystem.grantRole(rewardSystem.ENFORCER_ROLE(), enforcer);
        vm.stopPrank();

        uint256 tokenAmount = 5 ether;
        uint256 nativeAmount = 5 ether;
        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](1);
        erc20Rewards[0] = Rewards.ERC20Reward({ token: address(token), amount: tokenAmount });

        // Mock arbitration
        vm.mockCall(
            address(arbitration),
            abi.encodeWithSelector(arbitration.vaultIsInArbitration.selector, address(vault)),
            abi.encode(true)
        );

        vm.startPrank(enforcer);
        rewardSystem.enforceSendReward(
            0,
            whitehat,
            erc20Rewards,
            nativeAmount,
            address(vault),
            vaultDelegate.UNTRUSTED_TARGET_GAS_CAP()
        );
        vm.stopPrank();

        (uint16 fee, ) = vaultFees.getFee(address(vault));

        uint256 nativeFeeRecipientAmount = (nativeAmount * fee) / vaultFees.FEE_BASIS();
        uint256 tokenFeeRecipientAmount = (tokenAmount * fee) / vaultFees.FEE_BASIS();
        assertEq(address(feeRecipient).balance, nativeFeeRecipientAmount);
        assertEq(token.balanceOf(feeRecipient), tokenFeeRecipientAmount);
        assertEq(address(vault).balance, nativeInitialAmount - nativeAmount - nativeFeeRecipientAmount);
        assertEq(token.balanceOf(address(vault)), tokenInitialAmount - tokenAmount - tokenFeeRecipientAmount);
        assertEq(whitehat.balance, nativeAmount);
        assertEq(token.balanceOf(whitehat), tokenAmount);
    }

    function testEnforceSendRewardsRevertsOutOfArbitration() public {
        uint256 tokenInitialAmount = 10 ether;
        uint256 nativeInitialAmount = 10 ether;
        vm.deal(address(vault), nativeInitialAmount);
        ERC20PresetMinterPauser token = new ERC20PresetMinterPauser("Test", "TST");
        token.mint(address(vault), tokenInitialAmount);

        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        rewardSystem.grantRole(rewardSystem.ENFORCER_ROLE(), enforcer);
        vm.stopPrank();

        uint256 tokenAmount = 5 ether;
        uint256 nativeAmount = 5 ether;
        Rewards.ERC20Reward[] memory erc20Rewards = new Rewards.ERC20Reward[](1);
        erc20Rewards[0] = Rewards.ERC20Reward({ token: address(token), amount: tokenAmount });

        vm.startPrank(enforcer);
        uint256 gasToTarget = vaultDelegate.UNTRUSTED_TARGET_GAS_CAP();
        vm.expectRevert("RewardSystem: vault is not in arbitration");
        rewardSystem.enforceSendReward(0, whitehat, erc20Rewards, nativeAmount, address(vault), gasToTarget);
        vm.stopPrank();
    }

    function testRewardSystemSetupBranches() public {
        RewardSystem newRewardSystem = new RewardSystem();

        bytes memory initData = abi.encodeCall(
            newRewardSystem.setUp,
            (address(0), address(immunefiModule), address(vaultDelegate), address(arbitration), address(vaultFreezer))
        );
        vm.expectRevert("RewardSystem: owner cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newRewardSystem.setUp,
            (protocolOwner, address(0), address(vaultDelegate), address(arbitration), address(vaultFreezer))
        );
        vm.expectRevert("RewardSystem: module cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newRewardSystem.setUp,
            (protocolOwner, address(immunefiModule), address(0), address(arbitration), address(vaultFreezer))
        );
        vm.expectRevert("RewardSystem: vaultDelegate cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newRewardSystem.setUp,
            (protocolOwner, address(immunefiModule), address(vaultDelegate), address(0), address(vaultFreezer))
        );
        vm.expectRevert("RewardSystem: arbitration cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardSystem), address(proxyAdmin), initData));

        initData = abi.encodeCall(
            newRewardSystem.setUp,
            (protocolOwner, address(immunefiModule), address(vaultDelegate), address(arbitration), address(0))
        );
        vm.expectRevert("RewardSystem: vaultFreezer cannot be 0x00");
        address(_deployTransparentProxy(address(newRewardSystem), address(proxyAdmin), initData));
    }

    function testBaseRewardSystemSetsByAdmin() public {
        vm.startPrank(protocolOwner);

        // setModule
        vm.expectEmit(true, false, false, false);
        emit ModuleSet(address(0xdead));
        rewardSystem.setModule(address(0xdead));
        assertEq(address(rewardSystem.immunefiModule()), address(0xdead));

        // setVaultDelegate
        vm.expectEmit(false, false, false, true);
        emit VaultDelegateSet(address(0xdead));
        rewardSystem.setVaultDelegate(address(0xdead));
        assertEq(address(rewardSystem.vaultDelegate()), address(0xdead));

        vm.stopPrank();
    }
}
