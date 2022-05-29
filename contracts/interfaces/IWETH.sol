// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.2 <0.9.0;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function transfer(address to, uint256 value) external returns (bool);
}
