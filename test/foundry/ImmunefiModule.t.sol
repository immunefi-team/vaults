// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import { Strings } from "openzeppelin-contracts/utils/Strings.sol";

import { ImmunefiModule } from "../../src/ImmunefiModule.sol";
import { ReturnDataModule } from "../../src/mocks/ReturnDataModule.sol";
import { Setups } from "./helpers/Setups.sol";

contract ImmunefiModuleTest is Test, Setups {
    bool internal vaultRecipientFunctionCalled;

    function setUp() public {
        _protocolSetup();
    }

    function vaultRecipientFunction() external payable {
        vaultRecipientFunctionCalled = true;
    }

    function vaulRecipientFunctionReturn() external payable returns (bool) {
        vaultRecipientFunctionCalled = true;
        return true;
    }

    function testSetupModuleReverts() public {
        vm.startPrank(vaultSigner);

        vm.expectRevert("Initializable: contract is already initialized");
        immunefiModule.setUp(protocolOwner);

        vm.stopPrank();
    }

    function testModuleGuardBlocksTxs() public {
        vm.startPrank(moduleExecutor);

        vm.deal(address(vault), 1.1 ether);
        vm.expectRevert("Target address is not allowed");
        immunefiModule.execute(
            address(vault),
            address(this),
            1.1 ether,
            abi.encodeCall(this.vaultRecipientFunction, ()),
            Enum.Operation.Call
        );

        vm.stopPrank();
    }

    function testAllowsNothingOnShutdown() public {
        vm.prank(protocolOwner);
        emergencySystem.activateEmergencyShutdown();

        vm.startPrank(moduleExecutor);

        vm.expectRevert("ImmunefiModule: emergency shutdown is active");
        immunefiModule.execute(address(vault), address(0), 0, "", Enum.Operation.Call);

        vm.stopPrank();
    }

    function testExecutesOnAllowedTargetAndFunction() public {
        // set right permissions on moduleGuard
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(this), true);
        moduleGuard.setAllowedFunction(address(this), this.vaultRecipientFunction.selector, true);
        moduleGuard.setValueAllowedOnTarget(address(this), true);
        moduleGuard.setScoped(address(this), true);
        vm.stopPrank();

        vm.startPrank(moduleExecutor);

        vm.deal(address(vault), 1.1 ether);
        immunefiModule.execute(
            address(vault),
            address(this),
            1.1 ether,
            abi.encodeCall(this.vaultRecipientFunction, ()),
            Enum.Operation.Call
        );

        vm.stopPrank();
    }

    function testRevertsOnTargetZero() public {
        vm.startPrank(moduleExecutor);

        vm.expectRevert("ImmunefiModule: target is zero address");
        immunefiModule.execute(address(0), address(0), 0, "", Enum.Operation.Call);

        vm.stopPrank();
    }

    function testRevertsOnVaultExecutionError() public {
        vm.startPrank(protocolOwner);
        moduleGuard.setTargetAllowed(address(this), true);
        vm.stopPrank();

        vm.startPrank(moduleExecutor);

        vm.expectRevert("ImmunefiModule: execution failed");
        immunefiModule.execute(address(this), address(this), 0, "", Enum.Operation.Call);

        vm.stopPrank();
    }

    function testModuleSetupBranches() public {
        ImmunefiModule module = new ImmunefiModule(address(emergencySystem));

        bytes memory initData = abi.encodeCall(module.setUp, address(0));
        vm.expectRevert("ImmunefiModule: owner cannot be 0x00");
        address(_deployTransparentProxy(address(module), address(proxyAdmin), initData));
    }

    function testRemovesGuardFromModule() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(address(this)),
                " is missing role ",
                Strings.toHexString(uint256(immunefiModule.DEFAULT_ADMIN_ROLE()), 32)
            )
        );
        immunefiModule.setGuard(address(0));

        vm.startPrank(protocolOwner);
        immunefiModule.setGuard(address(0));
        vm.stopPrank();
        assertEq(address(immunefiModule.getGuard()), address(0));

        // execution succeeds since there's no guard scoping
        vm.startPrank(moduleExecutor);

        vm.deal(address(vault), 1.1 ether);
        immunefiModule.execute(
            address(vault),
            address(this),
            1.1 ether,
            abi.encodeCall(this.vaultRecipientFunction, ()),
            Enum.Operation.Call
        );

        vm.stopPrank();
    }

    function testChangesGuardSuccessfully() public {
        vm.startPrank(protocolOwner);
        immunefiModule.setGuard(address(immunefiGuard));
        vm.stopPrank();
        assertEq(address(immunefiModule.getGuard()), address(immunefiGuard));
    }

    function testRevertsChangeToNonIGuard() public {
        vm.startPrank(protocolOwner);

        vm.expectRevert();
        immunefiModule.setGuard(address(this));

        vm.stopPrank();
    }

    function testReturnsExecWithReturnData() public {
        ReturnDataModule returnDataModule = new ReturnDataModule();

        uint256 signerKey = 123456789;
        address signer = vm.addr(signerKey);
        GnosisSafe safe = _deployGnosisSafeSingleOwner(signer);

        vm.deal(address(safe), 1.1 ether);

        vm.expectRevert("GS104");
        returnDataModule.executeReturnData(
            address(safe),
            address(this),
            1.1 ether,
            abi.encodeCall(this.vaulRecipientFunctionReturn, ()),
            Enum.Operation.Call
        );

        _setModule(safe, address(returnDataModule), signerKey);
        returnDataModule.setGuard(address(immunefiGuard));

        vm.expectRevert();
        returnDataModule.executeReturnData(
            address(safe),
            address(this),
            1.1 ether,
            abi.encodeCall(this.vaulRecipientFunctionReturn, ()),
            Enum.Operation.Call
        );

        vm.startPrank(protocolOwner);
        immunefiGuard.setTargetAllowed(address(this), true);
        immunefiGuard.setValueAllowedOnTarget(address(this), true);
        vm.stopPrank();

        (bool success, bytes memory data) = returnDataModule.executeReturnData(
            address(safe),
            address(this),
            1.1 ether,
            abi.encodeCall(this.vaulRecipientFunctionReturn, ()),
            Enum.Operation.Call
        );

        assertTrue(vaultRecipientFunctionCalled);
        assertTrue(success);
        assertTrue(abi.decode(data, (bool)));
    }

    function execTransactionFromModule(
        address,
        uint256,
        bytes calldata,
        Enum.Operation
    ) external pure returns (bool success) {
        // function to be called by a test
        return false;
    }
}
