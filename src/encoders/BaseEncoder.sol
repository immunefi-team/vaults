// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

/**
 * @title BaseEncoder
 * @author Immunefi
 * @notice Base contract for EIP712 encoding
 * @dev Contract is inherited by encoders for EIP712 signatures
 */
abstract contract BaseEncoder {
    // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    /**
     * @notice Returns the chain ID of the current chain
     */
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * @notice Returns the EIP-712 domain separator
     */
    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), this));
    }

    /**
     * @notice Returns the EIP-712 hash of the data to be signed
     * @param dataHash Hash of the data to be signed
     */
    function _encodeTypedData(bytes32 dataHash) internal view returns (bytes memory) {
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), dataHash);
    }
}
