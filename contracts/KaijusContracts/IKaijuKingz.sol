// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IKaijuKingz {
    function walletOfOwner(address owner)
        external
        view
        returns (uint256[] memory);
}
