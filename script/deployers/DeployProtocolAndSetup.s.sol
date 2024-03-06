// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "../Base.s.sol";
import "./utils/ProxyUtils.sol";

import { EmergencySystem } from "../../src/EmergencySystem.sol";
import { ImmunefiModule } from "../../src/ImmunefiModule.sol";
import { ImmunefiGuard } from "../../src/guards/ImmunefiGuard.sol";
import { ScopeGuard } from "../../src/guards/ScopeGuard.sol";
import { VaultFreezer } from "../../src/VaultFreezer.sol";
import { Timelock } from "../../src/Timelock.sol";
import { WithdrawalSystem } from "../../src/WithdrawalSystem.sol";
import { RewardSystem } from "../../src/RewardSystem.sol";
import { Arbitration } from "../../src/Arbitration.sol";
import { VaultDelegate } from "../../src/common/VaultDelegate.sol";
import { VaultFees } from "../../src/common/VaultFees.sol";
import { ProxyAdminOwnable2Step } from "../../src/proxy/ProxyAdminOwnable2Step.sol";
import { VaultSetup } from "../../src/handlers/VaultSetup.sol";
import { RewardTimelock } from "../../src/RewardTimelock.sol";
import { PriceConsumer } from "../../src/oracles/PriceConsumer.sol";

contract DeployProtocolAndSetup is BaseScript, ProxyUtils {
    address immutable protocolOwner;
    address constant CHAINLINK_FEED_REGISTRY = address(0xdead); // no sepolia feed registry
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8; // sepolia deploy by AAVE

    // addresses
    address proxyAdmin;
    address vaultFees;
    address vaultDelegate;
    address emergencySystem;
    address priceConsumer;

    constructor() {
        protocolOwner = vm.envAddress("PROTOCOL_OWNER");
    }

    function run() public virtual broadcaster returns (address) {
        ///////////////////////
        /// DEPLOYS
        ///////////////////////

        // Deploy non-proxy components
        _deployNonProxyContracts();

        // Deploy Zodiac components
        address immunefiGuard = _deployImmunefiGuardProxy(address(proxyAdmin), deployer, address(emergencySystem));
        address immunefiModule = _deployImmunefiModuleProxy(address(proxyAdmin), deployer, address(emergencySystem));
        address moduleGuard = _deployScopeGuardProxy(address(proxyAdmin), deployer);

        // Deploy proxy components
        address vaultFreezer = _deployVaultFreezerProxy(address(proxyAdmin), deployer);
        address timelock = _deployTimelockProxy(proxyAdmin, deployer, immunefiModule, vaultFreezer);
        address withdrawalSystem = _deployWithdrawalSystemProxy(
            proxyAdmin,
            protocolOwner,
            timelock,
            vaultDelegate,
            1 days,
            10 days
        );
        address rewardSystem = _deployRewardSystemProxy(
            proxyAdmin,
            deployer,
            immunefiModule,
            vaultDelegate,
            address(0xdead),
            vaultFreezer
        );
        address arbitration = _deployArbitrationProxy(
            address(proxyAdmin),
            protocolOwner,
            immunefiModule,
            rewardSystem,
            vaultDelegate,
            USDC,
            10_000_000_000,
            protocolOwner
        );
        address rewardTimelock = _deployRewardTimelockProxy(
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

        ///////////////////////
        /// SETUP
        ///////////////////////

        {
            RewardSystem rs = RewardSystem(rewardSystem);
            ImmunefiModule im = ImmunefiModule(immunefiModule);
            Timelock tl = Timelock(timelock);
            ImmunefiGuard ig = ImmunefiGuard(immunefiGuard);
            ScopeGuard mg = ScopeGuard(moduleGuard);

            // set arbitration in rewardSystem
            rs.setArbitration(address(arbitration));

            // set ImmunefiModule's guard
            im.setGuard(address(moduleGuard));

            // set access control roles
            tl.grantRole(tl.QUEUER_ROLE(), address(withdrawalSystem));
            im.grantRole(im.EXECUTOR_ROLE(), address(timelock));
            im.grantRole(im.EXECUTOR_ROLE(), address(rewardSystem));
            im.grantRole(im.EXECUTOR_ROLE(), address(rewardTimelock));
            im.grantRole(im.EXECUTOR_ROLE(), address(arbitration));
            rs.grantRole(rs.ENFORCER_ROLE(), address(arbitration));

            // set withdrawalSystem scope in guard
            ig.setTargetAllowed(address(withdrawalSystem), true);
            ig.setScoped(address(withdrawalSystem), true);
            ig.setAllowedFunction(address(withdrawalSystem), WithdrawalSystem.queueVaultWithdrawal.selector, true);

            // set rewardSystem scope in guard
            ig.setTargetAllowed(address(rewardSystem), true);
            ig.setScoped(address(rewardSystem), true);
            ig.setAllowedFunction(address(rewardSystem), RewardSystem.sendRewardByVault.selector, true);

            // set timelock scope in guard
            ig.setTargetAllowed(address(timelock), true);
            ig.setScoped(address(timelock), true);
            ig.setAllowedFunction(address(timelock), Timelock.executeTransaction.selector, true);
            ig.setAllowedFunction(address(timelock), Timelock.cancelTransaction.selector, true);

            // set rewardTimelock scope in guard
            ig.setTargetAllowed(address(rewardTimelock), true);
            ig.setScoped(address(rewardTimelock), true);
            ig.setAllowedFunction(address(rewardTimelock), RewardTimelock.queueRewardTransaction.selector, true);
            ig.setAllowedFunction(address(rewardTimelock), RewardTimelock.executeRewardTransaction.selector, true);
            ig.setAllowedFunction(address(rewardTimelock), RewardTimelock.cancelTransaction.selector, true);

            // set arbitration scope in guard
            ig.setTargetAllowed(address(arbitration), true);
            ig.setScoped(address(arbitration), true);
            ig.setAllowedFunction(address(arbitration), Arbitration.requestArbVault.selector, true);

            // set vaultDelegate scope in guard
            mg.setTargetAllowed(address(vaultDelegate), true);
            mg.setScoped(address(vaultDelegate), true);
            mg.setDelegateCallAllowedOnTarget(address(vaultDelegate), true);
            mg.setAllowedFunction(vaultDelegate, VaultDelegate.sendReward.selector, true);
            mg.setAllowedFunction(vaultDelegate, VaultDelegate.sendRewardNoFees.selector, true);
            mg.setAllowedFunction(vaultDelegate, VaultDelegate.sendTokens.selector, true);
            mg.setAllowedFunction(vaultDelegate, VaultDelegate.withdrawFunds.selector, true);
        }

        ///////////////////////
        /// SETUP PROTOCOL OWNER ROLES
        ///////////////////////

        {
            RewardSystem rs = RewardSystem(rewardSystem);
            ImmunefiModule im = ImmunefiModule(immunefiModule);
            Timelock tl = Timelock(timelock);
            ImmunefiGuard ig = ImmunefiGuard(immunefiGuard);
            ScopeGuard mg = ScopeGuard(moduleGuard);
            VaultFreezer vf = VaultFreezer(vaultFreezer);

            // set protocolOwner roles
            rs.grantRole(rs.DEFAULT_ADMIN_ROLE(), protocolOwner);
            im.grantRole(im.DEFAULT_ADMIN_ROLE(), protocolOwner);
            tl.grantRole(tl.DEFAULT_ADMIN_ROLE(), protocolOwner);
            ig.transferOwnership(protocolOwner);
            mg.transferOwnership(protocolOwner);
            vf.grantRole(vf.FREEZER_ROLE(), protocolOwner);
            vf.grantRole(vf.DEFAULT_ADMIN_ROLE(), protocolOwner);

            // deployer renounces roles
            rs.renounceRole(rs.DEFAULT_ADMIN_ROLE(), deployer);
            im.renounceRole(im.DEFAULT_ADMIN_ROLE(), deployer);
            tl.renounceRole(tl.DEFAULT_ADMIN_ROLE(), deployer);
            vf.renounceRole(vf.DEFAULT_ADMIN_ROLE(), deployer);
        }

        return address(0);
    }

    function _deployNonProxyContracts() private {
        proxyAdmin = _deployProxyAdmin(protocolOwner);
        vaultFees = _deployVaultFees(protocolOwner, protocolOwner, 10_00);
        vaultDelegate = _deployVaultDelegate(address(vaultFees));
        emergencySystem = _deployEmergencySystem(protocolOwner);
        priceConsumer = _deployPriceConsumer(protocolOwner, CHAINLINK_FEED_REGISTRY);
    }

    function _deployProxyAdmin(address owner) private returns (address addr) {
        bytes32 salt = _generateSalt("proxy.admin");
        addr = address(new ProxyAdminOwnable2Step{ salt: salt }(owner));
        console.log("ProxyAdmin deployed at: %s", addr);
    }

    function _deployVaultFees(address owner, address feeRecipient, uint16 feeBps) private returns (address addr) {
        bytes32 salt = _generateSalt("vault.fees");
        addr = address(new VaultFees{ salt: salt }(owner, feeRecipient, feeBps));
        console.log("VaultFees deployed at: %s", addr);
    }

    function _deployVaultDelegate(address _vaultFees) private returns (address addr) {
        bytes32 salt = _generateSalt("vault.delegate");
        addr = address(new VaultDelegate{ salt: salt }(_vaultFees));
        console.log("VaultDelegate deployed at: %s", addr);
    }

    function _deployEmergencySystem(address owner) private returns (address addr) {
        bytes32 salt = _generateSalt("emergency.system");
        addr = address(new EmergencySystem{ salt: salt }(owner));
        console.log("EmergencySystem deployed at: %s", addr);
    }

    function _deployPriceConsumer(address owner, address feedRegistry) private returns (address addr) {
        bytes32 salt = _generateSalt("price.consumer");
        addr = address(new PriceConsumer{ salt: salt }(owner, feedRegistry));
        console.log("PriceConsumer deployed at: %s", addr);
    }

    function _deployImmunefiGuardProxy(
        address admin,
        address owner,
        address _emergencySystem
    ) private returns (address addr) {
        bytes32 implementationSalt = _generateSalt("guard.implementation");
        addr = address(
            _deployTransparentProxy(
                address(new ImmunefiGuard{ salt: implementationSalt }(_emergencySystem)),
                admin,
                abi.encodeCall(ScopeGuard.setUp, (owner)) // inherits from it
            )
        );
        console.log("ImmunefiGuard deployed at: %s", addr);
    }

    function _deployImmunefiModuleProxy(
        address admin,
        address owner,
        address _emergencySystem
    ) private returns (address addr) {
        bytes32 implementationSalt = _generateSalt("module.implementation");
        addr = address(
            _deployTransparentProxy(
                address(new ImmunefiModule{ salt: implementationSalt }(address(_emergencySystem))),
                admin,
                abi.encodeCall(ImmunefiModule.setUp, (owner))
            )
        );
        console.log("ImmunefiModule deployed at: %s", addr);
    }

    function _deployScopeGuardProxy(address admin, address owner) private returns (address addr) {
        bytes32 implementationSalt = _generateSalt("scope.guard.implementation");
        addr = address(
            _deployTransparentProxy(
                address(new ScopeGuard{ salt: implementationSalt }()),
                admin,
                abi.encodeCall(ScopeGuard.setUp, (owner))
            )
        );
        console.log("ScopeGuard deployed at: %s", addr);
    }

    function _deployVaultFreezerProxy(address admin, address owner) private returns (address addr) {
        bytes32 implementationSalt = _generateSalt("vault.freezer.implementation");
        addr = address(
            _deployTransparentProxy(
                address(new VaultFreezer{ salt: implementationSalt }()),
                admin,
                abi.encodeCall(VaultFreezer.setUp, (owner))
            )
        );
        console.log("VaultFreezer deployed at: %s", addr);
    }

    function _deployTimelockProxy(
        address admin,
        address owner,
        address immunefiModule,
        address vaultFreezer
    ) private returns (address addr) {
        bytes32 implementationSalt = _generateSalt("timelock.implementation");
        addr = address(
            _deployTransparentProxy(
                address(new Timelock{ salt: implementationSalt }()),
                admin,
                abi.encodeCall(Timelock.setUp, (owner, immunefiModule, vaultFreezer))
            )
        );
        console.log("Timelock deployed at: %s", addr);
    }

    function _deployWithdrawalSystemProxy(
        address admin,
        address owner,
        address timelock,
        address _vaultDelegate,
        uint256 txCooldown,
        uint256 txExpiration
    ) private returns (address addr) {
        bytes32 implementationSalt = _generateSalt("withdrawal.system.implementation");
        addr = address(
            _deployTransparentProxy(
                address(new WithdrawalSystem{ salt: implementationSalt }()),
                admin,
                abi.encodeCall(WithdrawalSystem.setUp, (owner, timelock, _vaultDelegate, txCooldown, txExpiration))
            )
        );
        console.log("WithdrawalSystem deployed at: %s", addr);
    }

    function _deployRewardSystemProxy(
        address admin,
        address owner,
        address immunefiModule,
        address _vaultDelegate,
        address arbitration,
        address _vaultFreezer
    ) private returns (address addr) {
        bytes32 implementationSalt = _generateSalt("reward.system.implementation");
        addr = address(
            _deployTransparentProxy(
                address(new RewardSystem{ salt: implementationSalt }()),
                admin,
                abi.encodeCall(RewardSystem.setUp, (owner, immunefiModule, _vaultDelegate, arbitration, _vaultFreezer))
            )
        );
        console.log("RewardSystem deployed at: %s", addr);
    }

    function _deployArbitrationProxy(
        address admin,
        address owner,
        address immunefiModule,
        address rewardSystem,
        address _vaultDelegate,
        address token,
        uint256 fee,
        address feeRecipient
    ) private returns (address addr) {
        bytes32 implementationSalt = _generateSalt("arbitration.implementation");
        addr = address(
            _deployTransparentProxy(
                address(new Arbitration{ salt: implementationSalt }()),
                admin,
                abi.encodeCall(
                    Arbitration.setUp,
                    (owner, immunefiModule, rewardSystem, _vaultDelegate, token, fee, feeRecipient)
                )
            )
        );
        console.log("Arbitration deployed at: %s", addr);
    }

    function _deployRewardTimelockProxy(
        address admin,
        address owner,
        address immunefiModule,
        address vaultFreezer,
        address _vaultDelegate,
        address _priceConsumer,
        address arbitration,
        uint256 txCooldown,
        uint256 txExpiration
    ) private returns (address addr) {
        bytes32 implementationSalt = _generateSalt("reward.timelock.implementation");
        addr = address(
            _deployTransparentProxy(
                address(new RewardTimelock{ salt: implementationSalt }()),
                admin,
                abi.encodeCall(
                    RewardTimelock.setUp,
                    (
                        owner,
                        immunefiModule,
                        vaultFreezer,
                        _vaultDelegate,
                        _priceConsumer,
                        arbitration,
                        uint32(txCooldown),
                        uint32(txExpiration)
                    )
                )
            )
        );
        console.log("RewardTimelock deployed at: %s", addr);
    }

    function _generateSalt(string memory contractName) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("immunefi-sepolia-1.1.0-", contractName));
    }
}
