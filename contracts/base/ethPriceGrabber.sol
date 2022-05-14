// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;
import "./AggregatorV3Interface.sol";

contract ETHPriceGrabber {
    AggregatorV3Interface internal priceFeed;

    /**
     * Network: ETH Mainnet
     * Aggregator: ETH/USD
     * Address: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
     */
    constructor() {
        priceFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() internal view returns (int256) {
        (
            ,
            /*uint80 roundID*/
            int256 ethprice, /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = priceFeed.latestRoundData();
        return ethprice / 100000000;
        ///@dev returns the latest eth price, rounded to the dollar
        /// for defi apps, better accuracy would be preferred but since the
        /// values the contract deals in are so high,
        /// slight cent discrepencies are passable
    }
}
