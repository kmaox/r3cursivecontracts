// SPDX-License-Identifier: BSD-3-Clause

/// @title The R3Cursive DAO proxy contract
/// @notice
/// LICENSE
/// R3CursiveDAOProxy is a fork of
/// https://github.com/nounsDAO/nouns-monorepo/blob/master/packages/nouns-contracts/contracts/governance/NounsDAOProxy.sol
/// /// thank you for providing flawless code to be used

pragma solidity >=0.8.2 <0.9.0;

import "./R3CursiveDAOInterfaces.sol";

contract R3CursiveDAOProxy is R3CursiveDAOProxyStorage, R3CursiveDAOEvents {
    constructor(
        address timelock_,
        address R3Cursive_,
        address vetoer_,
        address admin_,
        address implementation_,
        uint256 votingPeriod_,
        uint256 votingDelay_,
        uint256 proposalThresholdBPS_,
        uint256 quorumVotesBPS_
    ) {
        // Admin set to msg.sender for initialization
        admin = msg.sender;

        delegateTo(
            implementation_,
            abi.encodeWithSignature(
                "initialize(address,address,address,uint256,uint256,uint256,uint256)",
                timelock_,
                R3Cursive_,
                vetoer_,
                votingPeriod_,
                votingDelay_,
                proposalThresholdBPS_,
                quorumVotesBPS_
            )
        );

        _setImplementation(implementation_);

        admin = admin_;
    }

    /**
     * @notice Called by the admin to update the implementation of the delegator
     * @param implementation_ The address of the new implementation for delegation
     */
    function _setImplementation(address implementation_) public {
        require(
            msg.sender == admin,
            "R3CursiveDAOProxy::_setImplementation: admin only"
        );
        require(
            implementation_ != address(0),
            "R3CursiveDAOProxy::_setImplementation: invalid implementation address"
        );

        address oldImplementation = implementation;
        implementation = implementation_;

        emit NewImplementation(oldImplementation, implementation);
    }

    /**
     * @notice Internal method to delegate execution to another contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param callee The contract to delegatecall
     * @param data The raw data to delegatecall
     */
    function delegateTo(address callee, bytes memory data) internal {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
    }

    /**
     * @dev Delegates execution to an implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    function _fallback() internal {
        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize())

            switch success
            case 0 {
                revert(free_mem_ptr, returndatasize())
            }
            default {
                return(free_mem_ptr, returndatasize())
            }
        }
    }

    /**
     * @dev Fallback function that delegates calls to the `implementation`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to `implementation`. Will run if call data
     * is empty.
     */
    receive() external payable {
        _fallback();
    }
}
