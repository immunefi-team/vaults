// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { DeployProxyAdmin } from "../../../script/deployers/DeployProxyAdmin.s.sol";
import { DeployWithdrawalSystem } from "../../../script/deployers/WithdrawalSystem/DeployWithdrawalSystem.s.sol";
import { SetWithdrawalSystemConfigs } from "../../../script/configs/setters/SetWithdrawalSystemConfigs.s.sol";
import { WithdrawalSystem } from "../../../src/WithdrawalSystem.sol";

contract SetWithdrawalSystemConfigsTest is Test {
    // solhint-disable state-visibility
    address withdrawalSystem;
    uint256 initialTxCooldown = 60;
    uint256 initialTxExpiration = 3600;
    uint256 finalTxCooldown = 120;
    uint256 finalTxExpiration = 7200;

    function setUp() public {
        vm.setEnv("MNEMONIC", "test test test test test test test test test test test junk");
        (address deployer, ) = deriveRememberKey({ mnemonic: vm.envString("MNEMONIC"), index: 0 });
        vm.setEnv("PROTOCOL_OWNER", vm.toString(deployer));

        address proxyAdmin = new DeployProxyAdmin().run();
        vm.setEnv("PROXY_ADMIN", vm.toString(proxyAdmin));

        vm.setEnv("IMMUNEFI_MODULE", vm.toString(makeAddr("ImmunefiModule")));
        vm.setEnv("VAULT_FREEZER", vm.toString(makeAddr("VaultFreezer")));
        vm.setEnv("VAULT_DELEGATE", vm.toString(makeAddr("VaultDelegate")));
        vm.setEnv("TIMELOCK", vm.toString(makeAddr("Timelock")));
        vm.setEnv("WITHDRAWAL_TX_COOLDOWN", vm.toString(initialTxCooldown));
        vm.setEnv("WITHDRAWAL_TX_EXPIRATION", vm.toString(initialTxExpiration));

        withdrawalSystem = new DeployWithdrawalSystem().run();
    }

    function testSetWithdrawalSystemConfigsSucceeds() public {
        WithdrawalSystem ws = WithdrawalSystem(withdrawalSystem);

        assertEq(ws.txCooldown(), initialTxCooldown);
        assertEq(ws.txExpiration(), initialTxExpiration);

        vm.setEnv("WITHDRAWAL_SYSTEM", vm.toString(withdrawalSystem));
        vm.setEnv("WITHDRAWAL_TX_COOLDOWN", vm.toString(finalTxCooldown));
        vm.setEnv("WITHDRAWAL_TX_EXPIRATION", vm.toString(finalTxExpiration));
        new SetWithdrawalSystemConfigs().run();

        assertEq(ws.txCooldown(), finalTxCooldown);
        assertEq(ws.txExpiration(), finalTxExpiration);
    }
}
