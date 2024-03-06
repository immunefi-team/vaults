// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

//solhint-disable max-line-length
/**
 * @title AggregatorV3Interface
 * @author Chainlink
 * @notice https://github.com/smartcontractkit/chainlink/blob/cf9ab4ec36292468172ef178e774d06faca005c5/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol
 */
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
