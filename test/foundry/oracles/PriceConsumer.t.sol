// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { Denominations } from "../../../src/oracles/chainlink/Denominations.sol";
import { FeedRegistryInterface } from "../../../src/oracles/chainlink/FeedRegistryInterface.sol";
import { PriceConsumer } from "../../../src/oracles/PriceConsumer.sol";
import { IPriceConsumerEvents } from "../../../src/oracles/IPriceConsumerEvents.sol";
import { IPriceFeed } from "../../../src/oracles/IPriceFeed.sol";
import { Setups } from "../helpers/Setups.sol";

contract PriceConsumerTest is Test, Setups, IPriceConsumerEvents {
    // solhint-disable state-visibility
    address nonPrivilegedAddr;

    modifier wrapPrank(address _addr) {
        vm.startPrank(_addr);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        _protocolSetup();

        nonPrivilegedAddr = makeAddr("nonPriviligedAddr");
    }

    function testTryRequestRevertsRoundIdZero() public wrapPrank(unprivilegedAddress) {
        address someBase = makeAddr("someBase");

        uint80 roundId = 0;
        int256 answer = 1 ether;
        uint256 startedAt = 0; // irrelevant
        uint256 updatedAt = block.timestamp;
        uint80 answeredInRound = 0; // irrelevant

        // Mock feedRegistry
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.latestRoundData, (someBase, Denominations.USD)),
            abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
        );
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.decimals, (someBase, Denominations.USD)),
            abi.encode(uint8(18))
        );

        vm.expectRevert("PriceConsumer: Chainlink feed roundId is 0");
        priceConsumer.tryGetSaneUsdPrice18Decimals(someBase);
    }

    function testTryRequestRevertsAnswerZero() public wrapPrank(unprivilegedAddress) {
        address someBase = makeAddr("someBase");

        uint80 roundId = 1;
        int256 answer = 0;
        uint256 startedAt = 0; // irrelevant
        uint256 updatedAt = block.timestamp;
        uint80 answeredInRound = 0; // irrelevant

        // Mock feedRegistry
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.latestRoundData, (someBase, Denominations.USD)),
            abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
        );
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.decimals, (someBase, Denominations.USD)),
            abi.encode(uint8(18))
        );

        vm.expectRevert("PriceConsumer: Feed price is not positive");
        priceConsumer.tryGetSaneUsdPrice18Decimals(someBase);
    }

    function testTryRequestRevertsUpdatedAtZero() public wrapPrank(unprivilegedAddress) {
        address someBase = makeAddr("someBase");

        uint80 roundId = 1;
        int256 answer = 1 ether;
        uint256 startedAt = 0; // irrelevant
        uint256 updatedAt = 0;
        uint80 answeredInRound = 0; // irrelevant

        // Mock feedRegistry
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.latestRoundData, (someBase, Denominations.USD)),
            abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
        );
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.decimals, (someBase, Denominations.USD)),
            abi.encode(uint8(18))
        );

        vm.expectRevert("PriceConsumer: Feed updatedAt is 0");
        priceConsumer.tryGetSaneUsdPrice18Decimals(someBase);
    }

    function testTryRequestRevertsUpdatedAtBiggerThanTimestamp() public wrapPrank(unprivilegedAddress) {
        address someBase = makeAddr("someBase");

        uint80 roundId = 1;
        int256 answer = 1 ether;
        uint256 startedAt = 0; // irrelevant
        uint256 updatedAt = block.timestamp + 1;
        uint80 answeredInRound = 0; // irrelevant

        // Mock feedRegistry
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.latestRoundData, (someBase, Denominations.USD)),
            abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
        );
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.decimals, (someBase, Denominations.USD)),
            abi.encode(uint8(18))
        );

        vm.expectRevert("PriceConsumer: Feed updatedAt is in the future");
        priceConsumer.tryGetSaneUsdPrice18Decimals(someBase);
    }

    function testTryRequestRevertsStale() public wrapPrank(unprivilegedAddress) {
        address someBase = makeAddr("someBase");

        uint80 roundId = 1;
        int256 answer = 1 ether;
        uint256 startedAt = 0; // irrelevant
        uint256 updatedAt = block.timestamp;
        uint80 answeredInRound = 0; // irrelevant

        vm.warp(block.timestamp + 1 days + 1);

        // Mock feedRegistry
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.latestRoundData, (someBase, Denominations.USD)),
            abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
        );
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.decimals, (someBase, Denominations.USD)),
            abi.encode(uint8(18))
        );

        vm.expectRevert("PriceConsumer: Feed is stale");
        priceConsumer.tryGetSaneUsdPrice18Decimals(someBase);
    }

    function testTryRequestRevertsChainlinkRevert() public wrapPrank(unprivilegedAddress) {
        address someBase = makeAddr("someBase");

        // Mock feedRegistry
        vm.mockCallRevert(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.latestRoundData, (someBase, Denominations.USD)),
            ""
        );
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.decimals, (someBase, Denominations.USD)),
            abi.encode(uint8(18))
        );

        vm.expectRevert("PriceConsumer: Chainlink feed roundId is 0");
        priceConsumer.tryGetSaneUsdPrice18Decimals(someBase);
    }

    function testTryRequestSuceedsWithChainlink() public wrapPrank(unprivilegedAddress) {
        address someBase = makeAddr("someBase");

        uint80 roundId = 1;
        int256 answer = 1 ether;
        uint256 startedAt = 0; // irrelevant
        uint256 updatedAt = block.timestamp;
        uint80 answeredInRound = 0; // irrelevant

        // Mock feedRegistry
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.latestRoundData, (someBase, Denominations.USD)),
            abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
        );
        vm.mockCall(
            feedRegistry,
            abi.encodeCall(FeedRegistryInterface.decimals, (someBase, Denominations.USD)),
            abi.encode(uint8(18))
        );

        uint256 response = priceConsumer.tryGetSaneUsdPrice18Decimals(someBase);
        assertEq(response, uint256(answer)); // decimals is 18
    }

    function testTryRequestSuceedsWithCustomFeed() public wrapPrank(protocolOwner) {
        address someBase = makeAddr("someBase");
        address someCustomFeed = makeAddr("someCustomFeed");

        int256 price = 1 ether;
        uint256 updatedAt = block.timestamp;

        vm.expectEmit(true, true, false, false);
        emit CustomFeedSet(someBase, someCustomFeed);
        priceConsumer.setCustomFeed(someBase, someCustomFeed);

        // Mock customFeed
        vm.mockCall(someCustomFeed, abi.encodeCall(IPriceFeed.getUsdPrice, ()), abi.encode(price, updatedAt));
        vm.mockCall(someCustomFeed, abi.encodeCall(IPriceFeed.decimals, ()), abi.encode(uint8(18)));

        uint256 response = priceConsumer.tryGetSaneUsdPrice18Decimals(someBase);
        assertEq(response, uint256(price)); // decimals is 18
    }
}
