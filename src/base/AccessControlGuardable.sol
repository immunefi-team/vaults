// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { BaseGuard, IGuard } from "@gnosis.pm/zodiac/contracts/guard/BaseGuard.sol";

/**
 * @title AccessControlGuardable
 * @author Immunefi
 * @notice zodiac/contracts/guard/Guardable.sol but with AccessControl instead of Ownable
 */
contract AccessControlGuardable is AccessControlUpgradeable {
    address internal guard;

    event ChangedGuard(address _guard);

    // `_guard` does not implement IERC165.
    error NotIERC165Compliant(address _guard);

    /**
     * @notice Sets a guard that checks transactions before execution.
     * @param _guard The address of the guard to be used or the 0 address to disable the guard.
     */
    function setGuard(address _guard) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_guard != address(0)) {
            if (!BaseGuard(_guard).supportsInterface(type(IGuard).interfaceId)) revert NotIERC165Compliant(_guard);
        }
        guard = _guard;
        emit ChangedGuard(_guard);
    }

    function getGuard() external view returns (address) {
        return guard;
    }
}
