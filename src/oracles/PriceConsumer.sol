// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Ownable2Step } from "openzeppelin-contracts/access/Ownable2Step.sol";
import { IFeedRegistryMinimal } from "./IFeedRegistryMinimal.sol";
import { Denominations } from "./chainlink/Denominations.sol";
import { IPriceFeed } from "./IPriceFeed.sol";
import { IPriceConsumerEvents } from "./IPriceConsumerEvents.sol";

/**
 * @title PriceConsumer
 * @author Immunefi
 * @notice This contract is used to wrap around price feeds.
 */
contract PriceConsumer is Ownable2Step, IPriceConsumerEvents {
    uint256 internal constant FEED_TIMEOUT = 1 days;
    IFeedRegistryMinimal internal immutable registry;

    struct PriceResponse {
        uint80 roundId;
        int256 answer;
        uint256 updatedAt;
        bool success;
        bool custom;
    }

    // @dev some tokens might need a custom feed, e.g. if we want to include one not in registry
    mapping(address => address) public customFeed;
    // @dev some tokens might need a custom feed timeout, e.g. if a feed heartbeat is much much slower
    mapping(address => uint256) public customFeedTimeout;

    constructor(address _owner, address _registry) {
        // bypasses 2-step ownership transfer
        _transferOwnership(_owner);
        registry = IFeedRegistryMinimal(_registry);
    }

    /**
     * @notice Gets the USD price of a token with safety checks. Returns with 18 decimals.
     * @param base The address of the token to get the price of.
     * @dev This view function reverts if the price is not sane.
     */
    function tryGetSaneUsdPrice18Decimals(address base) public view returns (uint256) {
        PriceResponse memory response = getUsdPrice18Decimals(base);

        if (!response.custom) {
            require(response.roundId != 0, "PriceConsumer: Chainlink feed roundId is 0");
        }
        require(response.success, "PriceConsumer: Feed not successful");
        require(response.answer > 0, "PriceConsumer: Feed price is not positive");
        require(response.updatedAt != 0, "PriceConsumer: Feed updatedAt is 0");
        require(response.updatedAt <= block.timestamp, "PriceConsumer: Feed updatedAt is in the future");
        require(block.timestamp - response.updatedAt <= _getFeedTimeout(base), "PriceConsumer: Feed is stale");

        return uint256(response.answer);
    }

    /**
     * @notice Gets the USD price of a list of tokens with safety checks. Returns with 18 decimals.
     * @param bases The addresses of the tokens to get the price of.
     * @dev This view function reverts if the price is not sane.
     */
    function tryGetSaneUsdPrice18DecimalsBatch(address[] calldata bases) external view returns (uint256[] memory) {
        uint256 length = bases.length;
        uint256[] memory prices = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            prices[i] = tryGetSaneUsdPrice18Decimals(bases[i]);
        }
        return prices;
    }

    /**
     * @notice Gets the USD price of a token. Returns with 18 decimals.
     * @param base The address of the token to get the price of.
     */
    function getUsdPrice18Decimals(address base) public view returns (PriceResponse memory) {
        address feed = customFeed[base];

        if (feed != address(0)) {
            // @dev base has a custom feed set
            return getCustomFeedUsdPrice18Decimals(feed);
        } else {
            // @dev base has no custom feed set, query chainlink's registry
            return getChainlinkPrice18Decimals(base, Denominations.USD);
        }
    }

    /**
     * @notice Wrapper around calling the Chainlink registry.
     * @param base The address of the token to get the price of.
     * @param quote The address of the token/denomination to quote in.
     */
    function getChainlinkPrice18Decimals(
        address base,
        address quote
    ) public view returns (PriceResponse memory response) {
        try registry.latestRoundData(base, quote) returns (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 updatedAt,
            uint80 /* answeredInRound */
        ) {
            response.success = true;
            response.roundId = roundId;
            response.answer = _convertTo18Decimals(answer, registry.decimals(base, quote));
            response.updatedAt = updatedAt;
        } catch {}
    }

    /**
     * @notice Wrapper around getting a usd price from a custom feed.
     * @param feed The address of the custom feed.
     */
    function getCustomFeedUsdPrice18Decimals(address feed) public view returns (PriceResponse memory response) {
        response.custom = true;
        try IPriceFeed(feed).getUsdPrice() returns (int256 price, uint256 updatedAt) {
            response.success = true;
            response.answer = _convertTo18Decimals(price, IPriceFeed(feed).decimals());
            response.updatedAt = updatedAt;
        } catch {}
    }

    /**
     * @notice Sets a custom feed for a token.
     * @param base The address of the token to set the custom feed for.
     * @param feed The address of the custom feed.
     */
    function setCustomFeed(address base, address feed) external onlyOwner {
        customFeed[base] = feed;
        emit CustomFeedSet(base, feed);
    }

    /**
     * @notice Sets a custom feed timeout for a token.
     * @param base The address of the token to set the custom feed timeout for.
     * @param timeout The timeout to set.
     */
    function setCustomFeedTimeout(address base, uint256 timeout) external onlyOwner {
        require(timeout > 1 minutes, "PriceConsumer: custom timeout must be more than 1min");
        customFeedTimeout[base] = timeout;
        emit CustomFeedTimeoutSet(base, timeout);
    }

    /**
     * @notice Gets the feed timeout for a specific base.
     * @param base The address of the token to get the price of.
     */
    function _getFeedTimeout(address base) internal view returns (uint256) {
        uint256 customTimeout = customFeedTimeout[base];
        return customTimeout == 0 ? FEED_TIMEOUT : customTimeout;
    }

    /**
     * @notice Converts a price to 18 decimals.
     * @param price The price to convert.
     * @param decimals The decimals of the price.
     */
    function _convertTo18Decimals(int256 price, uint8 decimals) internal pure returns (int256) {
        if (decimals == 18) {
            return price;
        } else if (decimals > 18) {
            // @dev truncation of extra decimals
            return price / int256(10 ** (decimals - 18));
        } else {
            return price * int256(10 ** (18 - decimals));
        }
    }
}
