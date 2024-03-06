// SPDX-License-Identifier: Immuni Software PTE Ltd General Source License
// https://github.com/immunefi-team/vaults/blob/main/LICENSE.md
pragma solidity 0.8.18;

import { Ownable2Step } from "openzeppelin-contracts/access/Ownable2Step.sol";
import { AggregatorV3Interface } from "./chainlink/shared/interfaces/AggregatorV3Interface.sol";
import { IFeedRegistryMinimal } from "./IFeedRegistryMinimal.sol";

/**
 * @title FeedRegistryL2
 * @author Immunefi
 * @notice Custom Feed Registry for Layer 2s.
 */
contract FeedRegistryL2 is IFeedRegistryMinimal, Ownable2Step {
    uint256 private constant GRACE_PERIOD_TIME = 3600;
    AggregatorV3Interface internal immutable SEQUENCER_UPTIME_FEED;

    struct NewFeed {
        address base;
        address quote;
        address feed;
        uint8 decimals;
    }

    // @dev base => quote => decimals
    mapping(address => mapping(address => uint8)) internal _decimals;
    // @dev base => quote => feed
    mapping(address => mapping(address => address)) public feeds;

    event NewFeedSet(address indexed base, address indexed quote, address indexed feed, uint8 decimals);

    constructor(address _owner, address _sequencerUptimeFeed, NewFeed[] memory _feeds) {
        // bypasses 2-step ownership transfer
        _transferOwnership(_owner);
        SEQUENCER_UPTIME_FEED = AggregatorV3Interface(_sequencerUptimeFeed);
        _setFeeds(_feeds);
    }

    /**
     * @notice Sets the feeds for the registry.
     * @param _feeds The feeds to set.
     */
    function setFeeds(NewFeed[] calldata _feeds) external onlyOwner {
        _setFeeds(_feeds);
    }

    function _setFeeds(NewFeed[] memory _feeds) internal {
        uint256 length = _feeds.length;
        for (uint256 i = 0; i < length; i++) {
            _decimals[_feeds[i].base][_feeds[i].quote] = _feeds[i].decimals;
            feeds[_feeds[i].base][_feeds[i].quote] = _feeds[i].feed;
            emit NewFeedSet(_feeds[i].base, _feeds[i].quote, _feeds[i].feed, _feeds[i].decimals);
        }
    }

    /**
     * @notice Gets the decimals for a base and quote asset.
     * @param base The base asset.
     * @param quote The quote asset.
     * @return The decimals for the base and quote asset.
     */
    function decimals(address base, address quote) external view override returns (uint8) {
        return _decimals[base][quote];
    }

    /**
     * @notice Gets the latest round data for a base and quote asset.
     * @dev Checks if the sequencer uptime feed is up.
     * @param base The base asset.
     * @param quote The quote asset.
     * @return roundId The round ID.
     * @return answer The price.
     * @return startedAt The timestamp of the start of the round.
     * @return updatedAt The timestamp of the last update of the round.
     * @return answeredInRound The round ID in which the answer was computed.
     */
    function latestRoundData(
        address base,
        address quote
    )
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        _checkSequencerUptimeFeed();

        address feed = feeds[base][quote];
        require(feed != address(0), "FeedRegistryL2: Feed not found");

        return AggregatorV3Interface(feed).latestRoundData();
    }

    function _checkSequencerUptimeFeed() internal view {
        if (address(SEQUENCER_UPTIME_FEED) == address(0)) {
            // @dev no sequencer uptime feed
            return;
        }

        (, int256 answer, uint256 startedAt, , ) = SEQUENCER_UPTIME_FEED.latestRoundData();

        bool isSequencerUp = answer == 0;
        require(isSequencerUp, "FeedRegistryL2: Sequencer is down");

        // Make sure the grace period has passed after thesequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        require(timeSinceUp > GRACE_PERIOD_TIME, "FeedRegistryL2: Grace period not over");
    }
}
