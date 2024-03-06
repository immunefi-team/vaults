// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";

/**
 * @title VaultSetup
 * @author Immunefi
 * @dev This contract is used in the GnosisSafe.setup process, for setupModules to delegatecall to.
 */
contract VaultSetup {
    address private immutable setupAddress;

    constructor() {
        setupAddress = address(this);
    }

    function setupModuleAndGuard(address module, address guard) external {
        require(address(this) != setupAddress, "VaultSetup: must be delegatecall");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let fmp := mload(0x40)
            // calldata will start at the last 4bytes of the first word, corresponding to the sighash
            let dataPointer := add(fmp, 0x1c)
            let success := 0

            // bytes4(keccak256("enableModule(address)")) -> 0x610b5925
            mstore(fmp, 0x00000000000000000000000000000000000000000000000000000000610b5925)
            mstore(add(fmp, 0x20), module)
            success := call(gas(), address(), 0, dataPointer, 0x24, 0, 0)
            if iszero(success) {
                revert(0, 0)
            }

            // bytes4(keccak256("setGuard(address)")) -> 0xe19a9dd9
            mstore(fmp, 0x00000000000000000000000000000000000000000000000000000000e19a9dd9)
            mstore(add(fmp, 0x20), guard)
            success := call(gas(), address(), 0, dataPointer, 0x24, 0, 0)
            if iszero(success) {
                revert(0, 0)
            }
        }
    }
}
