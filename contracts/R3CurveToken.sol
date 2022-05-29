// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

/// @title KrownDao's ERC721 contract to handle 721s
/// @author @kmao37
/// @notice Modified fork of NounsToken.sol, with additional features such as pre-seeding
/// & the removal of NounsSeeder + Descriptor as metadata is hosted on IPFS instead of done on-chain
/// @dev Most functions here are called internally via the auctionHouse interface
/// minter address is re-defined as auctionHouse for additional clarity
/// since it's the only address that should be able to access the minting functions

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./base/ERC721Checkpointable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IR3CurveToken.sol";

contract R3CurveToken is IR3CurveToken, Ownable, ERC721Checkpointable {
    // The team treasury address
    address public r3cursiveTeam;

    // auctionHouse contract address
    address public auctionHouse;

    // The internal XTOKEN ID tracker -> this only tracks the public sale
    uint256 private auctionIdToMint = 32;

    // This is the first tokenID that can get minted from the auctionHouse
    // Token ID #1 -> _PublicTokenID are reserved for the preseed sale
    uint256 private preseedMaxTokenID = 31;

    // The internal XTOKEN id tracker for the preseed
    uint256 private preseedcurrentID = 1;

    // IPFS link to contractURI
    string public contractURI = "://";

    // Link to baseURI
    string public baseURI;

    // Sale status of Preseed Members
    bool public preseedStatus = false;

    // Preseeding Price
    uint256 public preseedPrice = 5 ether; //TODO

    // Preseed whitelist
    mapping(address => bool) preseed;

    // Mapping of contracts users are allowed to interact with
    mapping(address => bool) public allowedContracts;

    // Wallet limit status
    bool public walletCap = false;

    /// @notice Require that the sender is the R3Cursive Team
    modifier onlyr3cursiveTeam() {
        require(msg.sender == r3cursiveTeam, "Sender is not the Krown Team");
        _;
    }

    /// @notice Require the sender to be the auctionHouse contract
    modifier onlyauctionHouse() {
        require(
            msg.sender == auctionHouse,
            "Sender is not the auctionHouse contract"
        );
        _;
    }

    /// @notice r3cursiveTeam address should be the team's multisig/vault wallet
    /// while auctionHouse address needs to be the auctionHouse contract
    constructor(address _r3cursiveTeam, address _auctionHouse)
        ERC721("R3Curve", "R3C")
    {
        r3cursiveTeam = _r3cursiveTeam;
        auctionHouse = _auctionHouse;
    }

    /// @notice set contractURI
    function setContractURI(string calldata _newContractURI)
        external
        onlyOwner
    {
        contractURI = _newContractURI;
    }

    /// @notice Set the baseURI for the token
    /// @dev Changes the value inside of erc721a.sol
    function setBaseURI(string calldata _uri) external onlyOwner {
        baseURI = _uri;
    }

    /// @notice Sets the preseedMint function live
    function setPreseedStatus() public onlyOwner {
        preseedStatus = !preseedStatus;
    }

    /// @notice Whitelists addresses able to use preseedMint function
    /// @dev takes in an array of addresses
    function addPreseedList(address[] memory _user) external onlyOwner {
        for (uint256 i = 0; i < _user.length; i++) {
            preseed[_user[i]] = true;
        }
    }

    /// @notice when this toggle is turned on, people can only hold 10% of the current supply
    /// for users that have over 10% of stock, they won't be able to recieve any tokens.
    /// no admin transfers will automatically be called for users with over 10% of totalsupply.
    function setWalletCap() public onlyOwner {
        walletCap = !walletCap;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setAllowedContracts(address _address, bool _access)
        public
        onlyr3cursiveTeam
    {
        allowedContracts[_address] = _access;
    }

    /// @notice The mint function for the auctionHouse to access
    /// TeamTokens are minted every 10 R3C, starting at 0, until all 1820 R3C are minted.
    /// @dev Call _mintTo with the to address(es).
    /// Only the auctionHouse should be able to call this function
    function auctionMint()
        external
        override
        onlyauctionHouse
        returns (uint256)
    {
        if (auctionIdToMint <= 1820 && auctionIdToMint % 10 == 0) {
            _mintTo(r3cursiveTeam, auctionIdToMint);
            auctionIdToMint++;
        }
        _mintTo(auctionHouse, auctionIdToMint);
        auctionIdToMint++;
        return auctionIdToMint;
    }

    /// @notice This is the pre-seed function for setting up governance prior to Auctions
    /// It should mint whitelisted users a max of 1 NFT per address, and only mint tokenIDs 1-30
    /// @dev calls _mintTo with the to address(es) & mints the preseedCurrentID
    /// preseedCurrentID tracks current supply/the next tokenid to be minted
    function preseedMint() external payable {
        require(msg.value == preseedPrice, "Wrong ETH price sent");
        require(preseedStatus == true, "Preseeding is not live yet");
        require(
            preseedcurrentID <= preseedMaxTokenID,
            "Only tokenIDs 1-31 are avaliable for pre-seeding"
        );

        require(preseed[msg.sender], "User is not allowed to mint a preseed");
        preseed[msg.sender] = false;

        _mintTo(msg.sender, preseedcurrentID);
        preseedcurrentID++;
    }

    /// @notice Burn a R3C token
    /// @dev The only purpose of  burns is to allow users to burn their
    /// token to the DAO and recieve a % share of liquid funds
    /// do we need to make this function transferable only ?? or can open to everyone
    function burn(uint256 r3curveID) public override {
        _burn(r3curveID);
        emit R3CurveBurned(r3curveID);
    }

    /// @notice Set the r3cursiveTeam address
    /// @dev Only callable by the r3cursiveTeam address when not locked.
    function setR3CursiveTeam(address _r3cursiveTeam)
        external
        override
        onlyr3cursiveTeam
    {
        r3cursiveTeam = _r3cursiveTeam;

        emit R3CursiveTeamUpdated(_r3cursiveTeam);
    }

    /// @notice Set the auctionHouse address
    function setAuctionHouse(address _auctionHouse)
        external
        override
        onlyOwner
    {
        auctionHouse = _auctionHouse;
        emit AuctionHouseUpdated(_auctionHouse);
    }

    // TODO how do we want to organise funds here
    function withdraw() external onlyr3cursiveTeam {
        uint256 sendAmount = address(this).balance;
        bool success;

        (success, ) = r3cursiveTeam.call{value: ((sendAmount * 25) / 100)}("");
        require(success, "Payment Failed");

        (success, ) = r3cursiveTeam.call{value: ((sendAmount * 74) / 100)}("");
        require(success, "Payment Failed");
    }

    /// @notice only only can call this function to manually transfer assets
    function ownerTransfer(
        address from,
        address to,
        uint256 tokenId
    ) external onlyr3cursiveTeam {
        _transfer(from, to, tokenId);
    }

    /// @notice set approval for the token to custom R3C marketplace
    /// @dev users should only be able to approve their token with the R3C marketplace
    /// and should not be allowed to approve items to opensea, LR and other marketplaces
    function approve(address to, uint256 tokenId)
        public
        virtual
        override(ERC721, IERC721)
    {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(
            allowedContracts[to] == true,
            "Can only approve whitelisted contracts"
        );

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /// @notice set approval for token to the marketplace
    /// @dev this should only allow users to approve their
    /// token for trades on the marketplace
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override(ERC721, IERC721)
    {
        require(
            allowedContracts[operator] == true,
            "Can only approve whitelisted contracts"
        );
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /// @notice implement supply limit restricts. The address that is reciving the tokens "to"
    /// needs to have less than 10% of the supply stock. auctionIdToMint is similar to a
    /// totalsupply tracker, as long as you minus 1 from it. Dividing by this by 10 refers to the total amount
    /// of tokens that a user can own and minusing one factors in the additional token that is being
    /// transferred to the new person
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        uint256 bal = balanceOf((to));
        if (walletCap == true) {
            require(
                bal + 1 < totalSupply(),
                "User owns more 10% or more of supply and cannot recieve additional tokens"
            );
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /// @notice Mint a R3C with `TokenID` to the provided `to` address.
    /// todo change variabel names here
    function _mintTo(address _to, uint256 tokenID) internal returns (uint256) {
        _mint(_to, tokenID);
        emit R3CurveCreated(tokenID);

        return tokenID;
    }

    function totalStock() external view override returns (uint256) {
        uint256 i = totalSupply();
        return i;
    }
}
