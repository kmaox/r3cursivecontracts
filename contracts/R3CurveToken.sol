// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

/// @title KrownDao's ERC721 contract to handle 721s
/// @author @kmao37
/// @notice Modified fork of NounsToken.sol, with additional features such as pre-seeding
/// & the removal of NounsSeeder + Descriptor as metadata is hosted on IPFS instead of done on-chain
/// @dev Most functions here are called internally via the AuctionHouse interface
/// minter address is re-defined as AuctionHouse for additional clarity
/// since it's the only address that should be able to access the minting functions

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./base/ERC721Checkpointable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IR3CurveToken.sol";

contract R3CurveToken is IR3CurveToken, Ownable, ERC721Checkpointable {
    // The team treasury address
    address public R3CursiveTeam;

    // AuctionHouse contract address
    address public AuctionHouse;

    // The internal XTOKEN ID tracker -> this only tracks the public sale
    uint256 private AuctionIDToMint = 32;

    // This is the first tokenID that can get minted from the AuctionHouse
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
    uint256 public PRESEEDPRICE = 5 ether; //TODO

    // Preseed whitelist
    mapping(address => bool) preseed;

    // Mapping of contracts users are allowed to interact with
    mapping(address => bool) public allowedContracts;

    // Wallet limit status
    bool public walletCap = false;

    /// @notice Require that the sender is the R3Cursive Team
    modifier onlyR3CursiveTeam() {
        require(msg.sender == R3CursiveTeam, "Sender is not the Krown Team");
        _;
    }

    /// @notice Require the sender to be the AuctionHouse contract
    modifier onlyAuctionHouse() {
        require(
            msg.sender == AuctionHouse,
            "Sender is not the AuctionHouse contract"
        );
        _;
    }

    /// @notice r3cursiveTeam address should be the team's multisig/vault wallet
    /// while AuctionHouse address needs to be the AuctionHouse contract
    constructor(address _R3CursiveTeam, address _AuctionHouse)
        ERC721("R3Curve", "R3C")
    {
        R3CursiveTeam = _R3CursiveTeam;
        AuctionHouse = _AuctionHouse;
    }

    /// @notice set contractURI
    function setContractURI(string _newContractURI) external onlyOwner {
        contractURI = _newContractURI;
    }

    /// @notice Set the baseURI for the token
    /// @dev Changes the value inside of erc721a.sol
    function setBaseURI(string _uri) external onlyOwner {
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
        onlyR3CursiveTeam
    {
        allowedContracts[_address] = _access;
    }

    /// @notice The mint function for the AuctionHouse to access
    /// TeamTokens are minted every 10 R3C, starting at 0, until all 1820 R3C are minted.
    /// @dev Call _mintTo with the to address(es).
    /// Only the AuctionHouse should be able to call this function
    function auctionMint()
        external
        override
        onlyAuctionHouse
        returns (uint256)
    {
        if (AuctionIDToMint <= 1820 && AuctionIDToMint % 10 == 0) {
            _mintTo(R3CursiveTeam, AuctionIDToMint);
            AuctionIDToMint++;
        }
        _mintTo(AuctionHouse, AuctionIDToMint);
        AuctionIDToMint++;
        return AuctionIDToMint;
    }

    /// @notice This is the pre-seed function for setting up governance prior to Auctions
    /// It should mint whitelisted users a max of 1 NFT per address, and only mint tokenIDs 1-30
    /// @dev calls _mintTo with the to address(es) & mints the preseedCurrentID
    /// preseedCurrentID tracks current supply/the next tokenid to be minted
    function preseedMint() external payable {
        require(msg.value == PRESEEDPRICE, "Wrong ETH price sent");
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

    /// @notice Set the R3CursiveTeam address
    /// @dev Only callable by the R3CursiveTeam address when not locked.
    function setR3CursiveTeam(address _R3CursiveTeam)
        external
        override
        onlyR3CursiveTeam
    {
        R3CursiveTeam = _R3CursiveTeam;

        emit R3CursiveTeamUpdated(_R3CursiveTeam);
    }

    /// @notice Set the AuctionHouse address
    function setAuctionHouse(address _AuctionHouse)
        external
        override
        onlyOwner
    {
        AuctionHouse = _AuctionHouse;
        emit AuctionHouseUpdated(_AuctionHouse);
    }

    /// @notice only only can call this function to manually transfer assets
    function ownerTransfer(
        address from,
        address to,
        uint256 tokenId
    ) external onlyR3CursiveTeam {
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
            allowedContracts[to] == true,
            "Can only approve whitelisted contracts"
        );
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /// @notice implement supply limit restricts. The address that is reciving the tokens "to"
    /// needs to have less than 10% of the supply stock. AuctionIDtoMint is similar to a
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
