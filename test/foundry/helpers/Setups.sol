// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

// solhint-disable no-console
import { Test } from "forge-std/Test.sol";
import { GnosisSafe, Enum } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import { ERC20PresetMinterPauser } from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

import { EmergencySystem } from "../../../src/EmergencySystem.sol";
import { ImmunefiModule } from "../../../src/ImmunefiModule.sol";
import { ImmunefiGuard } from "../../../src/guards/ImmunefiGuard.sol";
import { ScopeGuard } from "../../../src/guards/ScopeGuard.sol";
import { VaultFreezer } from "../../../src/VaultFreezer.sol";
import { Timelock } from "../../../src/Timelock.sol";
import { WithdrawalSystem } from "../../../src/WithdrawalSystem.sol";
import { RewardSystem } from "../../../src/RewardSystem.sol";
import { Arbitration } from "../../../src/Arbitration.sol";
import { RewardTimelock } from "../../../src/RewardTimelock.sol";
import { PriceConsumer } from "../../../src/oracles/PriceConsumer.sol";
import { VaultDelegate } from "../../../src/common/VaultDelegate.sol";
import { VaultFees } from "../../../src/common/VaultFees.sol";
import { ProxyAdminOwnable2Step } from "../../../src/proxy/ProxyAdminOwnable2Step.sol";
import { Deployers } from "./Deployers.sol";

// solhint-disable max-states-count
abstract contract Setups is Test, Deployers {
    // solhint-disable state-visibility
    uint256 vaultSignerPk = 1;
    address vaultSigner = vm.addr(vaultSignerPk);
    address protocolOwner = makeAddr("protocolOwner");
    address moduleExecutor = makeAddr("moduleExecutor");
    address unprivilegedAddress = makeAddr("unprivilegedAddress");
    address feedRegistry = makeAddr("feedRegistry");
    address payable feeRecipient = payable(makeAddr("feeRecipient"));
    uint256 whitehatPk = 102;
    address payable whitehat = payable(vm.addr(whitehatPk));
    address payable withdrawalReceiver = payable(makeAddr("withdrawalReceiver"));

    ERC20PresetMinterPauser testToken;

    PriceConsumer priceConsumer;
    VaultFreezer vaultFreezer;
    WithdrawalSystem withdrawalSystem;
    RewardSystem rewardSystem;
    Timelock timelock;
    RewardTimelock rewardTimelock;
    EmergencySystem emergencySystem;
    Arbitration arbitration;
    ImmunefiModule immunefiModule;
    ImmunefiGuard immunefiGuard;
    ScopeGuard moduleGuard;
    GnosisSafe vault;

    VaultFees vaultFees;
    VaultDelegate vaultDelegate;
    ProxyAdminOwnable2Step proxyAdmin;

    function _protocolSetup() internal {
        // Deploy test token
        testToken = _deployTestERC20PresetMinterPauser(protocolOwner);

        // Deploy Vault
        vault = _deployGnosisSafeSingleOwner(vaultSigner);

        // Deploy non-proxy components
        proxyAdmin = _deployProxyAdmin(protocolOwner);
        vaultFees = _deployVaultFees(protocolOwner, feeRecipient, 10_00);
        vaultDelegate = _deployVaultDelegate(address(vaultFees));
        emergencySystem = _deployEmergencySystem(protocolOwner);
        priceConsumer = _deployPriceConsumer(protocolOwner, feedRegistry);

        // Deploy Zodiac components
        immunefiGuard = _deployImmunefiGuardProxy(address(proxyAdmin), protocolOwner, address(emergencySystem));
        immunefiModule = _deployImmunefiModuleProxy(address(proxyAdmin), protocolOwner, address(emergencySystem));
        moduleGuard = _deployScopeGuardProxy(address(proxyAdmin), protocolOwner);

        // Deploy proxy components
        vaultFreezer = _deployVaultFreezerProxy(address(proxyAdmin), protocolOwner);
        timelock = _deployTimelockProxy(
            address(proxyAdmin),
            protocolOwner,
            address(immunefiModule),
            address(vaultFreezer)
        );
        withdrawalSystem = _deployWithdrawalSystemProxy(
            address(proxyAdmin),
            protocolOwner,
            address(timelock),
            address(vaultDelegate),
            1 days,
            10 days
        );
        rewardSystem = _deployRewardSystemProxy(
            address(proxyAdmin),
            protocolOwner,
            address(immunefiModule),
            address(vaultDelegate),
            address(0xdead),
            address(vaultFreezer)
        );
        arbitration = _deployArbitrationProxy(
            address(proxyAdmin),
            protocolOwner,
            address(immunefiModule),
            address(rewardSystem),
            address(vaultDelegate),
            address(testToken),
            1 ether,
            feeRecipient
        );
        rewardTimelock = _deployRewardTimelockProxy(
            address(proxyAdmin),
            protocolOwner,
            address(immunefiModule),
            address(vaultFreezer),
            address(vaultDelegate),
            address(priceConsumer),
            address(arbitration),
            1 days,
            10 days
        );

        //
        // Set Admin configurations
        //
        vm.startPrank(protocolOwner);

        // set arbitration in rewardSystem
        rewardSystem.setArbitration(address(arbitration));

        // set ImmunefiModule's guard
        immunefiModule.setGuard(address(moduleGuard));

        // set access control roles
        timelock.grantRole(timelock.QUEUER_ROLE(), address(withdrawalSystem));
        immunefiModule.grantRole(immunefiModule.EXECUTOR_ROLE(), moduleExecutor);
        immunefiModule.grantRole(immunefiModule.EXECUTOR_ROLE(), address(timelock));
        immunefiModule.grantRole(immunefiModule.EXECUTOR_ROLE(), address(rewardSystem));
        immunefiModule.grantRole(immunefiModule.EXECUTOR_ROLE(), address(rewardTimelock));
        immunefiModule.grantRole(immunefiModule.EXECUTOR_ROLE(), address(arbitration));
        rewardSystem.grantRole(rewardSystem.ENFORCER_ROLE(), address(arbitration));

        // set withdrawalSystem scope in guard
        immunefiGuard.setTargetAllowed(address(withdrawalSystem), true);
        immunefiGuard.setScoped(address(withdrawalSystem), true);
        immunefiGuard.setAllowedFunction(
            address(withdrawalSystem),
            WithdrawalSystem.queueVaultWithdrawal.selector,
            true
        );

        // set rewardSystem scope in guard
        immunefiGuard.setTargetAllowed(address(rewardSystem), true);
        immunefiGuard.setScoped(address(rewardSystem), true);
        immunefiGuard.setAllowedFunction(address(rewardSystem), RewardSystem.sendRewardByVault.selector, true);

        // set timelock scope in guard
        immunefiGuard.setTargetAllowed(address(timelock), true);
        immunefiGuard.setScoped(address(timelock), true);
        immunefiGuard.setAllowedFunction(address(timelock), Timelock.executeTransaction.selector, true);
        immunefiGuard.setAllowedFunction(address(timelock), Timelock.cancelTransaction.selector, true);

        // set rewardTimelock scope in guard
        immunefiGuard.setTargetAllowed(address(rewardTimelock), true);
        immunefiGuard.setScoped(address(rewardTimelock), true);
        immunefiGuard.setAllowedFunction(address(rewardTimelock), RewardTimelock.queueRewardTransaction.selector, true);
        immunefiGuard.setAllowedFunction(
            address(rewardTimelock),
            RewardTimelock.executeRewardTransaction.selector,
            true
        );
        immunefiGuard.setAllowedFunction(address(rewardTimelock), RewardTimelock.cancelTransaction.selector, true);

        // set arbitration scope in guard
        immunefiGuard.setTargetAllowed(address(arbitration), true);
        immunefiGuard.setScoped(address(arbitration), true);
        immunefiGuard.setAllowedFunction(address(arbitration), Arbitration.requestArbVault.selector, true);
        vm.stopPrank();

        _setModule(vault, address(immunefiModule), vaultSignerPk);
        // set guard last so that setting the module doesn't fail
        _setGuard();
    }

    function _setModule(GnosisSafe _safe, address _module, uint256 _signerPk) internal {
        bytes memory enableModuleCalldata = abi.encodeCall(_safe.enableModule, (_module));
        bytes memory txHashData = _safe.encodeTransactionData({
            to: address(_safe),
            value: 0,
            data: enableModuleCalldata,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: _safe.nonce()
        });
        bytes memory signature = _signData(_signerPk, txHashData);
        _safe.execTransaction(
            address(_safe),
            0,
            enableModuleCalldata,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );
    }

    function _setGuard() internal {
        _sendTxToVault(
            address(vault),
            0,
            abi.encodeCall(vault.setGuard, (address(immunefiGuard))),
            Enum.Operation.Call
        );
    }

    function _sendTxToVault(address target, uint256 value, bytes memory data, Enum.Operation operation) internal {
        _sendTxToVault(target, value, data, operation, false);
    }

    function _sendTxToVault(
        address target,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        bool expectRevert
    ) internal {
        bytes memory txHashData = vault.encodeTransactionData({
            to: target,
            value: value,
            data: data,
            operation: operation,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: vault.nonce()
        });

        bytes memory signature = _signData(vaultSignerPk, txHashData);

        if (expectRevert) {
            vm.expectRevert();
        }
        vault.execTransaction(target, value, data, operation, 0, 0, 0, address(0), payable(0), signature);
    }

    function _signData(uint256 privKey, bytes memory data) internal pure returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, keccak256(data));
        signature = abi.encodePacked(r, s, v);
    }

    // for coverage to ignore this file
    function test() public {}
}
