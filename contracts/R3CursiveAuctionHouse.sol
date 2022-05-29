// SPDX-License-Identifier: MIT

/// @title The IR3CurveToken DAO auction house
/// @author @kmao37

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IR3CursiveAuctionHouse.sol";
import "./R3CurveToken.sol";
import "./KaijusContracts/IKaijuKingz.sol";

contract R3CursiveAuctionHouse is
    IR3CursiveAuctionHouse,
    Pausable,
    ReentrancyGuard,
    Ownable
{
    using SafeMath for uint256;

    // The R3Curve ERC721 token contract
    IR3CurveToken public IR3C;

    // Kaiju's actual address
    IKaijuKingz public KaijuAddress;

    // The address of the WETH contract
    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Multi-sig owned by Dots & Lord Quas + ?
    //TODO update with actual multisig
    address public multiSig = 0xdA27937582B0ed4211e9C322778658b7B151e44d;

    // The DAO address
    address public r3cursiveDAO;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;
    // The minimum price accepted in an auction, USD value
    // Create bid only accepts ethervalues, so this is not used in
    uint256 public reservePrice = 5 ether;

    // The minimum percentage difference between the last bid amount and the current bid
    uint8 public minBidIncrementPercentage;

    // The duration of a single auction
    uint256 public duration = 1 days;

    // The active auction struct details
    IR3CursiveAuctionHouse.Auction public auction;

    // This enum controls the current requirements for users to access the createBid function
    enum BidAllowance {
        GENESISONLY,
        KAIJUONLY
    }
    BidAllowance bidRequirements;
    BidAllowance constant defaultRequirements = BidAllowance.GENESISONLY;

    // The lasttokenID of a genesis Kaiju is 3332
    uint256 public lastGenesisTokenID = 3332;

    // This variable controls if all users can bid or not, and should only be called in years
    bool public publicBidding = false;

    constructor() Ownable() {
        _pause();
    }

    function getBidAllowanceStatus() public view returns (BidAllowance) {
        return bidRequirements;
    }

    function setGenesisOnly() external onlyOwner {
        bidRequirements = BidAllowance.GENESISONLY;
    }

    function setKaijuOnly() external onlyOwner {
        bidRequirements = BidAllowance.KAIJUONLY;
    }

    function openBidstoAll() external onlyOwner {
        publicBidding = !publicBidding;
    }

    /**
     * @notice Initialize the auction house and base contracts,
     * populate configuration values, and pause the contract.
     * @dev This function can only be called once.
     */
    function initialize(
        IR3CurveToken _IR3C,
        IKaijuKingz _kaijuAddress,
        address _r3cursiveDAO,
        uint256 _timeBuffer,
        uint8 _minBidIncrementPercentage
    ) external onlyOwner {
        IR3C = _IR3C;
        KaijuAddress = _kaijuAddress;
        r3cursiveDAO = _r3cursiveDAO;
        timeBuffer = _timeBuffer;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        _createAuction();
        _unpause();
    }

    /**
     * @notice Settle the current auction, auctionMint(); a new r3c, and put it up for auction.
     */
    function settleCurrentAndCreateNewAuction()
        external
        override
        nonReentrant
        whenNotPaused
        onlyOwner
    {
        _settleAuction();
        _createAuction();
    }

    /**
     * @notice Create a bid for a r3c, with a given amount.
     * @dev This contract only accepts payment in ETH.
     */

    // @audit lines 140 could be passed in as zero, potentially passing the
    function createBid(uint256 r3CurveID)
        external
        payable
        override
        nonReentrant
    {
        IR3CursiveAuctionHouse.Auction memory _auction = auction;

        require(
            _auction.r3CurveID == r3CurveID,
            "R3Curve Token not up for auction"
        );
        require(block.timestamp < _auction.endTime, "Auction expired");
        require(
            uint256(msg.value) >= reservePrice,
            "Must send at least reserve price"
        );
        require(
            _bidAllowanceCheck(msg.sender) == true || publicBidding == true,
            "User does not qualify to bid, or bidding restrictments have not been lifted"
        );
        require(
            msg.value >=
                _auction.amount +
                    ((_auction.amount * minBidIncrementPercentage) / 100),
            "Must send more than last bid by minBidIncrementPercentage amount"
        );

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            _safeTransferETHWithFallback(lastBidder, _auction.amount);
        }

        auction.amount = msg.value;
        auction.bidder = payable(msg.sender);

        // Extend the auction if the bid was received within `timeBuffer` of the auction end time
        bool extended = _auction.endTime - block.timestamp < timeBuffer;
        if (extended) {
            auction.endTime = _auction.endTime = block.timestamp + timeBuffer;
        }

        emit AuctionBid(_auction.r3CurveID, msg.sender, msg.value, extended);

        if (extended) {
            emit AuctionExtended(_auction.r3CurveID, _auction.endTime);
        }
    }

    /**nou
     * @notice Pause the IR3CurveToken auction house.
     * @dev This function can only be called by the owner when the
     * contract is unpaused. While no new auctions can be started when paused,
     * anyone can settle an ongoing auction.
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the IR3CurveToken auction house.
     * @dev This function can only be called by the owner when the
     * contract is paused. If required, this function will start a new auction.
     */
    function unpause() external override onlyOwner {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _createAuction();
        }
    }

    /**
     * @notice Set the auction time buffer.
     * @dev Only callable by the owner.
     */
    function setTimeBuffer(uint256 _timeBuffer) external override onlyOwner {
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    /**
     * @notice Set the auction reserve price.
     * @dev Only callable by the owner.
     */
    function setReservePrice(uint256 _reservePrice)
        external
        override
        onlyOwner
    {
        reservePrice = _reservePrice;

        emit AuctionReservePriceUpdated(_reservePrice);
    }

    /**
     * @notice Set the auction minimum bid increment percentage.
     * @dev Only callable by the owner.
     */
    function setMinBidIncrementPercentage(uint8 _minBidIncrementPercentage)
        external
        override
        onlyOwner
    {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(
            _minBidIncrementPercentage
        );
    }

    /**
     * @notice Create an auction.
     * @dev Store the auction details in the `auction` state variable and emit an AuctionCreated event.
     * If the auctionMint(); reverts, the auctionMint();er was updated without pausing this contract first. To remedy this,
     * catch the revert and pause this contract.
     */
    function _createAuction() internal {
        try IR3C.auctionMint() returns (uint256 r3CurveID) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + duration;

            auction = Auction({
                r3CurveID: r3CurveID,
                amount: 0,
                startTime: startTime,
                endTime: endTime,
                bidder: payable(0),
                settled: false
            });

            emit AuctionCreated(r3CurveID, startTime, endTime);
        } catch Error(string memory) {
            _pause();
        }
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, the r3curve is burned. //TODO - EDIT
     */
    function _settleAuction() internal {
        IR3CursiveAuctionHouse.Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, "Auction has already been settled");
        require(
            block.timestamp >= _auction.endTime,
            "Auction hasn't completed"
        );

        auction.settled = true;

        // if the reserve price i(s not met, the auctionMinted token is sent to the contract
        if (uint256(auction.amount) < reservePrice) {
            IR3C.transferFrom(address(this), r3cursiveDAO, _auction.r3CurveID);
        } else {
            IR3C.transferFrom(
                address(this),
                _auction.bidder,
                _auction.r3CurveID
            );
        }

        if (_auction.amount > 0) {
            _safeTransferETHWithFallback(
                r3cursiveDAO,
                ((_auction.amount * 75) / 100)
            );
            _safeTransferETHWithFallback(
                multiSig,
                ((_auction.amount * 25) / 100)
            );
        }

        emit AuctionSettled(
            _auction.r3CurveID,
            _auction.bidder,
            _auction.amount
        );
    }

    /**
     * @notice Transfer ETH. If the ETH transfer fails, wrap the ETH and try send it as WETH.
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            IWETH(weth).deposit{value: amount}();
            IERC20(weth).transfer(to, amount);
        }
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     */
    function _safeTransferETH(address to, uint256 value)
        internal
        returns (bool)
    {
        (bool success, ) = to.call{value: value, gas: 30_000}(new bytes(0));
        return success;
    }

    // This function checks if the caller has a genesis kaiju
    function _bidAllowanceCheck(address caller) internal view returns (bool) {
        // create temporary array of caller's owned kaijus
        uint256[] memory OwnedKaijus = KaijuAddress.walletOfOwner(caller);

        if (getBidAllowanceStatus() == BidAllowance.GENESISONLY) {
            // create temporary array of caller's owned kaijus
            for (uint256 i; i < OwnedKaijus.length; i++) {
                if (OwnedKaijus[i] <= lastGenesisTokenID) {
                    return true;
                }
            }
        } else if (getBidAllowanceStatus() == BidAllowance.KAIJUONLY) {
            // if the array has more than 1 value, it means the caller owns 1 kaiju
            if (OwnedKaijus.length > 0) {
                return true;
            }
        }
        return false;
    }
}
