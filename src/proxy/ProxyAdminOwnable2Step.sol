// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { Ownable2Step } from "openzeppelin-contracts/access/Ownable2Step.sol";
import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";

// solhint-disable reason-string
/**
 * @title ProxyAdminOwnable2Step
 * @author Immunefi
 * @dev OZ's ProxyAdmin.sol (v4.4.1) but with Ownable2Step instead of Ownable
 * @dev This is an auxiliary contract meant to be assigned as the admin of a TransparentUpgradeableProxy.
 */
contract ProxyAdminOwnable2Step is ProxyAdmin, Ownable2Step {
    constructor(address _owner) {
        // bypasses 2-step ownership transfer
        _transferOwnership(_owner);
    }

    function transferOwnership(address newOwner) public override(Ownable, Ownable2Step) {
        Ownable2Step.transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal override(Ownable, Ownable2Step) {
        Ownable2Step._transferOwnership(newOwner);
    }
}
