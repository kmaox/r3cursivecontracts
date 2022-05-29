// SPDX-License-Identifier: BSD-3-Clause

/// @title The R3cursive DAO executor and treasury
/// @notice
/// LICENSE
/// R3CursiveDAOExecutor is a fork of
/// https://github.com/nounsDAO/nouns-monorepo/blob/master/packages/nouns-contracts/contracts/governance/NounsDAOExecutor.sol
/// thank you for providing flawless code to be used

import "./interfaces/IR3CurveToken.sol";

pragma solidity >=0.8.2 <0.9.0;

contract R3CursiveDAOExecutor {
    // The R3Curve ERC721 token contract
    IR3CurveToken public IR3C;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    constructor(
        address admin_,
        uint256 delay_,
        IR3CurveToken IR3C_
    ) {
        require(
            delay_ >= MINIMUM_DELAY,
            "R3CursiveDAOExecutor::constructor: Delay must exceed minimum delay."
        );
        require(
            delay_ <= MAXIMUM_DELAY,
            "R3CursiveDAOExecutor::setDelay: Delay must not exceed maximum delay."
        );

        admin = admin_;
        delay = delay_;
        IR3C = IR3C_;
    }

    function setDelay(uint256 delay_) public {
        require(
            msg.sender == address(this),
            "R3CursiveDAOExecutor::setDelay: Call must come from R3CursiveDAOExecutor."
        );
        require(
            delay_ >= MINIMUM_DELAY,
            "R3CursiveDAOExecutor::setDelay: Delay must exceed minimum delay."
        );
        require(
            delay_ <= MAXIMUM_DELAY,
            "R3CursiveDAOExecutor::setDelay: Delay must not exceed maximum delay."
        );
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public {
        require(
            msg.sender == pendingAdmin,
            "R3CursiveDAOExecutor::acceptAdmin: Call must come from pendingAdmin."
        );
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        require(
            msg.sender == address(this),
            "R3CursiveDAOExecutor::setPendingAdmin: Call must come from R3CursiveDAOExecutor."
        );
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public returns (bytes32) {
        require(
            msg.sender == admin,
            "R3CursiveDAOExecutor::queueTransaction: Call must come from admin."
        );
        require(
            eta >= getBlockTimestamp() + delay,
            "R3CursiveDAOExecutor::queueTransaction: Estimated execution block must satisfy delay."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public {
        require(
            msg.sender == admin,
            "R3CursiveDAOExecutor::cancelTransaction: Call must come from admin."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public returns (bytes memory) {
        require(
            msg.sender == admin,
            "R3CursiveDAOExecutor::executeTransaction: Call must come from admin."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        require(
            queuedTransactions[txHash],
            "R3CursiveDAOExecutor::executeTransaction: Transaction hasn't been queued."
        );
        require(
            getBlockTimestamp() >= eta,
            "R3CursiveDAOExecutor::executeTransaction: Transaction hasn't surpassed time lock."
        );
        require(
            getBlockTimestamp() <= eta + GRACE_PERIOD,
            "R3CursiveDAOExecutor::executeTransaction: Transaction is stale."
        );

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(
            callData
        );
        require(
            success,
            "R3CursiveDAOExecutor::executeTransaction: Transaction execution reverted."
        );

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function rageQuit(uint256 _tokenID) external {
        require(
            msg.sender == IR3C.ownerOf(_tokenID),
            "User does not own the NFT you are trying to burn"
        );
        IR3C.burn(_tokenID);
        uint256 refund = (address(this).balance / IR3C.totalStock()); // calculates the current liquid value of a NFT
        bool sent = payable(msg.sender).send(refund);
        require(sent, "ETH failed to send");
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    receive() external payable {}

    fallback() external payable {}
}
