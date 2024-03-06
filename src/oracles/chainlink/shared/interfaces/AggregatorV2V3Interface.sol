// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { AggregatorInterface } from "./AggregatorInterface.sol";
import { AggregatorV3Interface } from "./AggregatorV3Interface.sol";

//solhint-disable max-line-length
/**
 * @title AggregatorV2V3Interface
 * @author Chainlink
 * @notice https://github.com/smartcontractkit/chainlink/blob/cf9ab4ec36292468172ef178e774d06faca005c5/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol
 */

interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {

}
