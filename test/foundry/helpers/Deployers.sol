// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

// solhint-disable no-console
import { GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import { GnosisSafeProxyFactory } from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import { ERC20PresetMinterPauser } from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { EmergencySystem } from "../../../src/EmergencySystem.sol";
import { ImmunefiModule } from "../../../src/ImmunefiModule.sol";
import { ImmunefiGuard } from "../../../src/guards/ImmunefiGuard.sol";
import { ScopeGuard } from "../../../src/guards/ScopeGuard.sol";
import { VaultFreezer } from "../../../src/VaultFreezer.sol";
import { Timelock } from "../../../src/Timelock.sol";
import { WithdrawalSystem } from "../../../src/WithdrawalSystem.sol";
import { RewardSystem } from "../../../src/RewardSystem.sol";
import { Arbitration } from "../../../src/Arbitration.sol";
import { VaultDelegate } from "../../../src/common/VaultDelegate.sol";
import { VaultFees } from "../../../src/common/VaultFees.sol";
import { ProxyAdminOwnable2Step } from "../../../src/proxy/ProxyAdminOwnable2Step.sol";
import { VaultSetup } from "../../../src/handlers/VaultSetup.sol";
import { RewardTimelock } from "../../../src/RewardTimelock.sol";
import { PriceConsumer } from "../../../src/oracles/PriceConsumer.sol";

abstract contract Deployers {
    address internal constant DEAD = address(0xdead);

    function _deployTestERC20PresetMinterPauser(address _minter) internal returns (ERC20PresetMinterPauser token) {
        // Pranked address becomes minter
        token = new ERC20PresetMinterPauser("Test", "TST");
        token.grantRole(token.MINTER_ROLE(), _minter);
    }

    function _deployGnosisSafeSingleOwner(address _owner) internal returns (GnosisSafe safe) {
        address safeSingleton = address(new GnosisSafe());
        GnosisSafeProxyFactory proxyFactory = new GnosisSafeProxyFactory();
        safe = GnosisSafe(payable(proxyFactory.createProxy(safeSingleton, "")));

        address[] memory owners = new address[](1);
        owners[0] = _owner;
        safe.setup(owners, 1, address(0), "", address(0), address(0), 0, payable(0));
    }

    function _deployProxyAdmin(address _owner) internal returns (ProxyAdminOwnable2Step) {
        bytes32 salt = keccak256(abi.encodePacked("immunefi.proxy.admin"));
        return new ProxyAdminOwnable2Step{ salt: salt }(_owner);
    }

    function _deployVaultFees(address _owner, address _feeRecipient, uint16 _feeBps) internal returns (VaultFees) {
        bytes32 salt = keccak256(abi.encodePacked("immunefi.vault.fees"));
        return new VaultFees{ salt: salt }(_owner, _feeRecipient, _feeBps);
    }

    function _deployVaultDelegate(address _vaultFees) internal returns (VaultDelegate) {
        bytes32 salt = keccak256(abi.encodePacked("immunefi.vault.delegate"));
        return new VaultDelegate{ salt: salt }(_vaultFees);
    }

    function _deployEmergencySystem(address _owner) internal returns (EmergencySystem) {
        bytes32 salt = keccak256(abi.encodePacked("immunefi.emergency.system"));
        return new EmergencySystem{ salt: salt }(_owner);
    }

    function _deployPriceConsumer(address _owner, address _registry) internal returns (PriceConsumer) {
        bytes32 salt = keccak256(abi.encodePacked("immunefi.price.consumer"));
        return new PriceConsumer{ salt: salt }(_owner, _registry);
    }

    function _deployImmunefiGuardProxy(
        address _proxyAdmin,
        address _owner,
        address _emergencySystem
    ) internal returns (ImmunefiGuard) {
        bytes32 implementationSalt = keccak256(abi.encodePacked("immunefi.guard.implementation"));
        return
            ImmunefiGuard(
                _deployTransparentProxy(
                    address(new ImmunefiGuard{ salt: implementationSalt }(_emergencySystem)),
                    _proxyAdmin,
                    abi.encodeCall(ScopeGuard.setUp, (_owner)) // inherits from it
                )
            );
    }

    function _deployImmunefiModuleProxy(
        address _proxyAdmin,
        address _owner,
        address _emergencySystem
    ) internal returns (ImmunefiModule) {
        bytes32 implementationSalt = keccak256(abi.encodePacked("immunefi.module.implementation"));
        return
            ImmunefiModule(
                _deployTransparentProxy(
                    address(new ImmunefiModule{ salt: implementationSalt }(address(_emergencySystem))),
                    _proxyAdmin,
                    abi.encodeCall(ImmunefiModule.setUp, (_owner))
                )
            );
    }

    function _deployScopeGuardProxy(address _proxyAdmin, address _owner) internal returns (ScopeGuard) {
        bytes32 implementationSalt = keccak256(abi.encodePacked("immunefi.scope.guard.implementation"));
        return
            ScopeGuard(
                _deployTransparentProxy(
                    address(new ScopeGuard{ salt: implementationSalt }()),
                    _proxyAdmin,
                    abi.encodeCall(ScopeGuard.setUp, (_owner))
                )
            );
    }

    function _deployVaultFreezerProxy(address _proxyAdmin, address _owner) internal returns (VaultFreezer) {
        bytes32 implementationSalt = keccak256(abi.encodePacked("immunefi.vault.freezer.implementation"));
        return
            VaultFreezer(
                _deployTransparentProxy(
                    address(new VaultFreezer{ salt: implementationSalt }()),
                    _proxyAdmin,
                    abi.encodeCall(VaultFreezer.setUp, (_owner))
                )
            );
    }

    function _deployTimelockProxy(
        address _proxyAdmin,
        address _owner,
        address _immunefiModule,
        address _vaultFreezer
    ) internal returns (Timelock) {
        bytes32 implementationSalt = keccak256(abi.encodePacked("immunefi.timelock.implementation"));
        return
            Timelock(
                _deployTransparentProxy(
                    address(new Timelock{ salt: implementationSalt }()),
                    _proxyAdmin,
                    abi.encodeCall(Timelock.setUp, (_owner, _immunefiModule, _vaultFreezer))
                )
            );
    }

    function _deployWithdrawalSystemProxy(
        address _proxyAdmin,
        address _owner,
        address _timelock,
        address _vaultDelegate,
        uint256 _txCooldown,
        uint256 _txExpiration
    ) internal returns (WithdrawalSystem) {
        bytes32 implementationSalt = keccak256(abi.encodePacked("immunefi.withdrawal.system.implementation"));
        return
            WithdrawalSystem(
                _deployTransparentProxy(
                    address(new WithdrawalSystem{ salt: implementationSalt }()),
                    _proxyAdmin,
                    abi.encodeCall(
                        WithdrawalSystem.setUp,
                        (_owner, _timelock, _vaultDelegate, _txCooldown, _txExpiration)
                    )
                )
            );
    }

    function _deployRewardSystemProxy(
        address _proxyAdmin,
        address _owner,
        address _immunefiModule,
        address _vaultDelegate,
        address _arbitration,
        address _vaultFreezer
    ) internal returns (RewardSystem) {
        bytes32 implementationSalt = keccak256(abi.encodePacked("immunefi.reward.system.implementation"));
        return
            RewardSystem(
                _deployTransparentProxy(
                    address(new RewardSystem{ salt: implementationSalt }()),
                    _proxyAdmin,
                    abi.encodeCall(
                        RewardSystem.setUp,
                        (_owner, _immunefiModule, _vaultDelegate, _arbitration, _vaultFreezer)
                    )
                )
            );
    }

    function _deployArbitrationProxy(
        address _proxyAdmin,
        address _owner,
        address _immunefiModule,
        address _rewardSystem,
        address _vaultDelegate,
        address _token,
        uint256 _fee,
        address _feeRecipient
    ) internal returns (Arbitration) {
        bytes32 implementationSalt = keccak256(abi.encodePacked("immunefi.arbitration.implementation"));
        return
            Arbitration(
                _deployTransparentProxy(
                    address(new Arbitration{ salt: implementationSalt }()),
                    _proxyAdmin,
                    abi.encodeCall(
                        Arbitration.setUp,
                        (_owner, _immunefiModule, _rewardSystem, _vaultDelegate, _token, _fee, _feeRecipient)
                    )
                )
            );
    }

    function _deployRewardTimelockProxy(
        address _proxyAdmin,
        address _owner,
        address _immunefiModule,
        address _vaultFreezer,
        address _vaultDelegate,
        address _priceConsumer,
        address _arbitration,
        uint256 _txCooldown,
        uint256 _txExpiration
    ) internal returns (RewardTimelock) {
        bytes32 implementationSalt = keccak256(abi.encodePacked("immunefi.reward.timelock.implementation"));
        return
            RewardTimelock(
                _deployTransparentProxy(
                    address(new RewardTimelock{ salt: implementationSalt }()),
                    _proxyAdmin,
                    abi.encodeCall(
                        RewardTimelock.setUp,
                        (
                            _owner,
                            _immunefiModule,
                            _vaultFreezer,
                            _vaultDelegate,
                            _priceConsumer,
                            _arbitration,
                            uint32(_txCooldown),
                            uint32(_txExpiration)
                        )
                    )
                )
            );
    }

    function _deployTransparentProxy(
        address logic,
        address proxyAdmin,
        bytes memory initData
    ) internal returns (address) {
        bytes32 salt = keccak256(abi.encodePacked("immunefi.transparent.proxy"));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }(logic, proxyAdmin, initData);
        return address(proxy);
    }

    function _computeArbitrationProxyDeterministicAddress(
        address _proxyAdmin,
        address _owner,
        address _immunefiModule,
        address _rewardSystem,
        address _vaultDelegate,
        address _token,
        uint256 _fee,
        address _feeRecipient
    ) internal view returns (address) {
        address logic = _computeDeterministicAddress(
            address(this),
            keccak256(abi.encodePacked("immunefi.arbitration.implementation")),
            keccak256(abi.encodePacked(type(Arbitration).creationCode))
        );
        return
            _computeTransparentProxyDeterministicAddress(
                logic,
                _proxyAdmin,
                abi.encodeCall(
                    Arbitration.setUp,
                    (_owner, _immunefiModule, _rewardSystem, _vaultDelegate, _token, _fee, _feeRecipient)
                )
            );
    }

    function _computeTransparentProxyDeterministicAddress(
        address logic,
        address proxyAdmin,
        bytes memory initData
    ) internal view returns (address) {
        return
            _computeDeterministicAddress(
                address(this),
                keccak256(abi.encodePacked("immunefi.transparent.proxy")),
                keccak256(
                    abi.encodePacked(
                        abi.encodePacked(
                            type(TransparentUpgradeableProxy).creationCode,
                            abi.encode(logic, proxyAdmin, initData)
                        )
                    )
                )
            );
    }

    function _computeDeterministicAddress(
        address deployer,
        bytes32 salt,
        bytes32 bytecodeHash
    ) internal pure returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), // 0xff
                deployer, // deployer
                salt, // salt
                bytecodeHash // init code hash
            )
        );
        return address(uint160(uint256(hash)));
    }

    function _deployVaultWithSetup(
        address _owner,
        address _immunefiModule,
        address _immunefiGuard
    ) internal returns (GnosisSafe) {
        address[] memory owners = new address[](1);
        owners[0] = _owner;

        address safeSingleton = address(new GnosisSafe());
        GnosisSafeProxyFactory proxyFactory = new GnosisSafeProxyFactory();
        VaultSetup vaultSetup = _deployVaultSetup();

        return
            GnosisSafe(
                payable(
                    proxyFactory.createProxy(
                        safeSingleton,
                        abi.encodeCall(
                            GnosisSafe.setup,
                            (
                                owners,
                                1,
                                address(vaultSetup),
                                abi.encodeCall(vaultSetup.setupModuleAndGuard, (_immunefiModule, _immunefiGuard)),
                                address(0),
                                address(0),
                                0,
                                payable(0)
                            )
                        )
                    )
                )
            );
    }

    function _deployVaultSetup() internal returns (VaultSetup) {
        return new VaultSetup();
    }
}
