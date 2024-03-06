// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { DeployProxyAdmin } from "../../../script/deployers/DeployProxyAdmin.s.sol";
import { DeployTimelock } from "../../../script/deployers/Timelock/DeployTimelock.s.sol";
import { GrantQueuerRoles } from "../../../script/configs/setters/GrantQueuerRoles.s.sol";
import { Timelock } from "../../../src/Timelock.sol";

contract GrantQueuerRolesTest is Test {
    // solhint-disable state-visibility
    address timelock;
    address withdrawalSystem;

    function setUp() public {
        vm.setEnv("MNEMONIC", "test test test test test test test test test test test junk");
        (address deployer, ) = deriveRememberKey({ mnemonic: vm.envString("MNEMONIC"), index: 0 });
        vm.setEnv("PROTOCOL_OWNER", vm.toString(deployer));

        address proxyAdmin = new DeployProxyAdmin().run();
        vm.setEnv("PROXY_ADMIN", vm.toString(proxyAdmin));

        withdrawalSystem = makeAddr("WithdrawalSystem");
        vm.setEnv("WITHDRAWAL_SYSTEM", vm.toString(withdrawalSystem));

        vm.setEnv("IMMUNEFI_MODULE", vm.toString(makeAddr("ImmunefiModule")));
        vm.setEnv("VAULT_FREEZER", vm.toString(makeAddr("VaultFreezer")));

        timelock = new DeployTimelock().run();
    }

    function testGrantQueuerRolesSucceeds() public {
        Timelock tl = Timelock(timelock);

        assertFalse(tl.hasRole(tl.QUEUER_ROLE(), withdrawalSystem));

        vm.setEnv("TIMELOCK", vm.toString(timelock));
        vm.setEnv("WITHDRAWAL_SYSTEM", vm.toString(withdrawalSystem));
        new GrantQueuerRoles().run();

        assertTrue(tl.hasRole(tl.QUEUER_ROLE(), withdrawalSystem));
    }
}
