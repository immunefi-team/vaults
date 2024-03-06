// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

//solhint-disable max-line-length
/**
 * @title AggregatorInterface
 * @author Chainlink
 * @notice https://github.com/smartcontractkit/chainlink/blob/cf9ab4ec36292468172ef178e774d06faca005c5/contracts/src/v0.8/shared/interfaces/AggregatorInterface.sol
 */

interface AggregatorInterface {
    function latestAnswer() external view returns (int256);

    function latestTimestamp() external view returns (uint256);

    function latestRound() external view returns (uint256);

    function getAnswer(uint256 roundId) external view returns (int256);

    function getTimestamp(uint256 roundId) external view returns (uint256);

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}
