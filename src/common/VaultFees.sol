// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { AccessControl } from "openzeppelin-contracts/access/AccessControl.sol";

/**
 * @title VaultFees
 * @author Immunefi
 * @dev This contract allows setting custom fees for vaults.
 */
contract VaultFees is AccessControl {
    bytes32 public constant SETTER_ROLE = keccak256("vault.fees.setter.role");
    uint256 public constant FEE_BASIS = 100_00;

    struct Fee {
        uint16 feeBps;
        address feeRecipient;
    }

    Fee internal defaultFee;
    mapping(address => Fee) internal fee;

    event FeeSet(address indexed vault, address indexed feeRecipient, uint16 feeBps);
    event DefaultFeeSet(address indexed defaultFeeRecipient, uint16 feeBps);

    constructor(address _owner, address _defaultFeeRecipient, uint16 _defaultFeeBps) {
        require(_owner != address(0), "VaultFees: owner cannot be 0x00");

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(SETTER_ROLE, _owner);

        _setDefaultFee(_defaultFeeBps, _defaultFeeRecipient);
    }

    /**
     * @notice Sets the fee for a vault
     * @param _vault Address of the vault
     * @param _feeBps Fee basis points
     * @param _feeRecipient Address of the fee recipient
     */
    function setVaultFee(address _vault, uint16 _feeBps, address _feeRecipient) external onlyRole(SETTER_ROLE) {
        require(_feeBps <= FEE_BASIS, "VaultFees: feeBps must be below FEE_BASIS");
        if (_feeRecipient == address(0) && _feeBps > 0) {
            revert("VaultFees: feeRecipient as 0x00 but feeBps not being set to 0");
        }
        fee[_vault].feeBps = _feeBps;
        // @dev feeRecipient can be 0x00
        fee[_vault].feeRecipient = _feeRecipient;
        emit FeeSet(_vault, _feeRecipient, _feeBps);
    }

    /**
     * @notice Sets the default fee
     * @param _defaultFeeBps Fee basis points
     * @param _defaultFeeRecipient Address of the fee recipient
     */
    function setDefaultFee(uint16 _defaultFeeBps, address _defaultFeeRecipient) external onlyRole(SETTER_ROLE) {
        _setDefaultFee(_defaultFeeBps, _defaultFeeRecipient);
        emit DefaultFeeSet(_defaultFeeRecipient, _defaultFeeBps);
    }

    function _setDefaultFee(uint16 _defaultFeeBps, address _defaultFeeRecipient) internal {
        require(_defaultFeeBps <= FEE_BASIS, "VaultFees: feeBps must be below FEE_BASIS");
        require(_defaultFeeRecipient != address(0), "VaultFees: defaultFeeRecipient cannot be 0x00");
        defaultFee.feeRecipient = _defaultFeeRecipient;
        defaultFee.feeBps = _defaultFeeBps;
    }

    /**
     * @notice Gets the fee for a vault
     * @param _vault Address of the vault
     * @return feeBps Fee basis points
     * @return feeRecipient Address of the fee recipient
     */
    function getFee(address _vault) external view returns (uint16 feeBps, address feeRecipient) {
        Fee memory _fee = fee[_vault];
        if (_fee.feeRecipient == address(0)) {
            // @dev default fee
            Fee memory _defaultFee = defaultFee;
            feeBps = _defaultFee.feeBps;
            feeRecipient = _defaultFee.feeRecipient;
        } else {
            feeBps = _fee.feeBps;
            feeRecipient = _fee.feeRecipient;
        }
    }
}
