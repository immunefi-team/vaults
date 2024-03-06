// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { BaseEncoder } from "./BaseEncoder.sol";

/**
 * @title ArbitrationOperationEncoder
 * @author Immunefi
 * @notice Message encoder for the Arbitration component
 */
abstract contract ArbitrationOperationEncoder is BaseEncoder {
    // keccak256("RequestArbitrationWhitehat(uint96 referenceId,address vault)");
    bytes32 private constant REQUEST_ARB_WHITEHAT_TYPEHASH =
        0xfcbb80b4009f0d54ca5337ddfa8d0a07be7e701e462a3afe711b6e48a384d7f5;

    /**
     * @notice Returns the requestArbFromWhitehat message that is hashed to be signed.
     * @param referenceId Reference ID of the request.
     * @param vault Address of the vault.
     */
    function encodeRequestArbFromWhitehatData(uint96 referenceId, address vault) public view returns (bytes memory) {
        bytes32 requestArbHash = keccak256(abi.encode(REQUEST_ARB_WHITEHAT_TYPEHASH, referenceId, vault));
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), requestArbHash);
    }

    /**
     * @notice Returns the arbitration id computed from inputs.
     * @param referenceId Reference ID of the request.
     * @param vault Address of the vault.
     * @param whitehat Address of the whitehat.
     */
    function computeArbitrationId(uint96 referenceId, address vault, address whitehat) public pure returns (bytes32) {
        return keccak256(abi.encode(referenceId, vault, whitehat));
    }
}
