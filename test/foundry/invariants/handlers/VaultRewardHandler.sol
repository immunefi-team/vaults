// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { GnosisSafe, Enum } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import { GnosisSafeProxyFactory } from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ProxyAdminOwnable2Step } from "../../../../src/proxy/ProxyAdminOwnable2Step.sol";
import { VaultDelegate } from "../../../../src/common/VaultDelegate.sol";
import { VaultFees } from "../../../../src/common/VaultFees.sol";
import { EmergencySystem } from "../../../../src/EmergencySystem.sol";
import { ImmunefiGuard } from "../../../../src/guards/ImmunefiGuard.sol";
import { ImmunefiModule } from "../../../../src/ImmunefiModule.sol";
import { ScopeGuard } from "../../../../src/guards/ScopeGuard.sol";
import { RewardSystem } from "../../../../src/RewardSystem.sol";
import { Arbitration } from "../../../../src/Arbitration.sol";
import { VaultFreezer } from "../../../../src/VaultFreezer.sol";
import { VaultSetup } from "../../../../src/handlers/VaultSetup.sol";
import { Deployers } from "../../helpers/Deployers.sol";
import { Rewards } from "../../../../src/common/Rewards.sol";

contract VaultRewardHandler is Test, Deployers {
    address public immutable PROTOCOL_OWNER = makeAddr("protocolOwner");
    address public immutable FEE_RECIPIENT = makeAddr("feeRecipient");
    address public immutable ENFORCER = makeAddr("enforcer");
    address public immutable WHITEHAT = makeAddr("whitehat");
    address public immutable VAULT_OWNER;
    uint256 internal immutable VAULT_OWNER_PK;

    ProxyAdminOwnable2Step public proxyAdmin;
    VaultDelegate public vaultDelegate;
    VaultFees public vaultFees;
    VaultFreezer public vaultFreezer;
    EmergencySystem public emergencySystem;
    ImmunefiGuard public immunefiGuard;
    ImmunefiModule public immunefiModule;
    ScopeGuard public moduleGuard;
    RewardSystem public rewardSystem;
    Arbitration public arbitration;
    GnosisSafe public vault;

    uint96 internal nextReferenceId;

    constructor() {
        (VAULT_OWNER, VAULT_OWNER_PK) = makeAddrAndKey("vaultOwner");
        _protocolSetup();
    }

    function _protocolSetup() internal {
        // Deploy non-proxy components
        proxyAdmin = _deployProxyAdmin(PROTOCOL_OWNER);

        vaultFees = _deployVaultFees(PROTOCOL_OWNER, FEE_RECIPIENT, 10_00);
        vaultDelegate = _deployVaultDelegate(address(vaultFees));
        emergencySystem = _deployEmergencySystem(PROTOCOL_OWNER);

        // Deploy Zodiac components
        immunefiGuard = _deployImmunefiGuardProxy(address(proxyAdmin), PROTOCOL_OWNER, address(emergencySystem));
        immunefiModule = _deployImmunefiModuleProxy(address(proxyAdmin), PROTOCOL_OWNER, address(emergencySystem));
        moduleGuard = _deployScopeGuardProxy(address(proxyAdmin), PROTOCOL_OWNER);

        // Deploy VaultFreezer
        vaultFreezer = _deployVaultFreezerProxy(address(proxyAdmin), PROTOCOL_OWNER);

        // Deploy RewardSystem
        rewardSystem = _deployRewardSystemProxy(
            address(proxyAdmin),
            PROTOCOL_OWNER,
            address(immunefiModule),
            address(vaultDelegate),
            address(0xdead),
            address(vaultFreezer)
        );

        // Deploy Arbitration
        arbitration = _deployArbitrationProxy(
            address(proxyAdmin),
            PROTOCOL_OWNER,
            address(immunefiModule),
            address(rewardSystem),
            address(vaultDelegate),
            address(0xdead),
            1 ether,
            FEE_RECIPIENT
        );

        vault = _deployVaultWithSetup(VAULT_OWNER, address(immunefiModule), address(immunefiGuard));

        //
        // Admin configurations
        //
        vm.startPrank(PROTOCOL_OWNER);

        // set arbitration
        rewardSystem.setArbitration(address(arbitration));

        immunefiModule.setGuard(address(moduleGuard));

        immunefiModule.grantRole(immunefiModule.EXECUTOR_ROLE(), address(rewardSystem));

        // set rewardSystem scope in guard
        immunefiGuard.setTargetAllowed(address(rewardSystem), true);
        immunefiGuard.setScoped(address(rewardSystem), true);
        immunefiGuard.setAllowedFunction(address(rewardSystem), RewardSystem.sendRewardByVault.selector, true);

        moduleGuard.setTargetAllowed(address(vaultDelegate), true);
        moduleGuard.setAllowedFunction(address(vaultDelegate), vaultDelegate.sendReward.selector, true);
        moduleGuard.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
        rewardSystem.grantRole(rewardSystem.ENFORCER_ROLE(), ENFORCER);
        vm.stopPrank();
    }

    function sendTxToVault(address target, uint256 value, bytes memory data, Enum.Operation operation) external {
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

        bytes memory signature = _signData(VAULT_OWNER_PK, txHashData);

        vault.execTransaction(target, value, data, operation, 0, 0, 0, address(0), payable(0), signature);
    }

    function _signData(uint256 privKey, bytes memory data) internal pure returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, keccak256(data));
        signature = abi.encodePacked(r, s, v);
    }

    function enforceReward(
        address payable to,
        Rewards.ERC20Reward[] calldata tokenAmounts,
        uint256 nativeTokenAmount
    ) external {
        vm.startPrank(ENFORCER);
        rewardSystem.enforceSendReward(nextReferenceId, to, tokenAmounts, nativeTokenAmount, address(vault), 500_000);
        vm.stopPrank();

        nextReferenceId++;
    }

    function sendRewardNativeToken(uint256 amountToSend) external {
        amountToSend = bound(amountToSend, 0, 1 ether);

        Rewards.ERC20Reward[] memory tokenAmounts = new Rewards.ERC20Reward[](0);

        this.sendTxToVault(
            address(rewardSystem),
            0,
            abi.encodeCall(rewardSystem.sendRewardByVault, (0, payable(WHITEHAT), tokenAmounts, amountToSend, 50_000)),
            Enum.Operation.Call
        );
    }
}
