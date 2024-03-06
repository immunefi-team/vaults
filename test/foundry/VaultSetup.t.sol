// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import { GnosisSafeProxyFactory } from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ProxyAdminOwnable2Step } from "../../src/proxy/ProxyAdminOwnable2Step.sol";
import { ImmunefiModule } from "../../src/ImmunefiModule.sol";
import { ImmunefiGuard } from "../../src/guards/ImmunefiGuard.sol";
import { ScopeGuard } from "../../src/guards/ScopeGuard.sol";
import { EmergencySystem } from "../../src/EmergencySystem.sol";
import { VaultSetup } from "../../src/handlers/VaultSetup.sol";

contract VaultSetupTest is Test {
    // solhint-disable state-visibility
    address ownerA = makeAddr("ownerA");
    address ownerB = makeAddr("ownerB");

    address safeSingleton;
    GnosisSafeProxyFactory proxyFactory;
    GnosisSafe ownerSafe;

    EmergencySystem emergencySystem;
    ImmunefiModule immunefiModule;
    ImmunefiGuard immunefiGuard;
    ProxyAdminOwnable2Step proxyAdmin;
    VaultSetup vaultSetup;

    function setUp() public {
        safeSingleton = address(new GnosisSafe());
        proxyFactory = new GnosisSafeProxyFactory();
        proxyAdmin = new ProxyAdminOwnable2Step(address(this));

        address[] memory owners = new address[](2);
        owners[0] = ownerA;
        owners[1] = ownerB;
        ownerSafe = GnosisSafe(
            payable(
                proxyFactory.createProxy(
                    safeSingleton,
                    abi.encodeCall(GnosisSafe.setup, (owners, 2, address(0), "", address(0), address(0), 0, payable(0)))
                )
            )
        );

        emergencySystem = new EmergencySystem(address(this));

        immunefiGuard = ImmunefiGuard(
            _deployTransparentProxy(
                address(new ImmunefiGuard(address(emergencySystem))),
                abi.encodeCall(ScopeGuard.setUp, (address(this))) // inherits from it
            )
        );

        immunefiModule = ImmunefiModule(
            _deployTransparentProxy(
                address(new ImmunefiModule(address(emergencySystem))),
                abi.encodeCall(ImmunefiModule.setUp, (address(this)))
            )
        );

        vaultSetup = new VaultSetup();
    }

    function testCreatesVaultWithGuardAndModule() public {
        address[] memory owners = new address[](1);
        owners[0] = address(ownerSafe);

        GnosisSafe vault = GnosisSafe(
            payable(
                proxyFactory.createProxy(
                    safeSingleton,
                    abi.encodeCall(
                        GnosisSafe.setup,
                        (
                            owners,
                            1,
                            address(vaultSetup),
                            abi.encodeCall(
                                vaultSetup.setupModuleAndGuard,
                                (address(immunefiModule), address(immunefiGuard))
                            ),
                            address(0),
                            address(0),
                            0,
                            payable(0)
                        )
                    )
                )
            )
        );

        assertEq(
            vm.load(address(vault), 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8),
            bytes32(uint256(uint160(address(immunefiGuard))))
        );
        assertTrue(vault.isModuleEnabled(address(immunefiModule)));
    }

    function _deployTransparentProxy(address logic, bytes memory initData) internal returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(logic),
            address(proxyAdmin),
            initData
        );
        return address(proxy);
    }
}
