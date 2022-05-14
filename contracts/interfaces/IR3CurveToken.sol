// SPDX-License-Identifier: MIT

/// @title Interface for R3CurveToken.sol

pragma solidity ^0.8.6;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IR3CurveToken is IERC721 {
    event R3CurveCreated(uint256 indexed tokenId);

    event R3CurveBurned(uint256 indexed tokenId);

    event R3CursiveTeamUpdated(address R3CursiveTeam);

    event AuctionHouseUpdated(address AuctionHouse);

    function auctionMint() external returns (uint256);

    function burn(uint256 tokenId) external;

    function setR3CursiveTeam(address R3CursiveTeam) external;

    function setAuctionHouse(address _AuctionHouse) external;

    function totalStock() external view returns (uint256);
}
