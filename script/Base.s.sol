// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// solhint-disable no-global-import
import "forge-std/Script.sol";

// @notice This comes from PaulRBerg
abstract contract BaseScript is Script {
    /// @dev The address of the contract deployer.
    address internal deployer;

    /// @dev Used to derive the deployer's address.
    string internal mnemonic;

    constructor() {
        mnemonic = vm.envString("MNEMONIC");
        (deployer, ) = deriveRememberKey({ mnemonic: mnemonic, index: 0 });
    }

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}
