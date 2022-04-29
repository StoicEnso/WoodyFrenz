// Woody Frenz
/**
A project built by the community for the planet                                         
*/

pragma solidity >=0.7.0 <0.9.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract WoodyFrenz is ERC721A, Ownable, IERC2981 {
    using Strings for uint256;

    string baseURI;
    string public baseExtension = ".json";
    uint256 public preSaleCost = 0.025 ether;
    uint256 public publicCost = 0.035 ether;
    uint256 public maxSupply = 1111;
    uint256 public remainingReserved;
    uint256 public maxMintAmount = 4;
    uint256 public allowedLimitPresale = 3;
    bool public paused = true;
    bool public revealed = false;
    string public notRevealedUri;
    // ======== Royalties =========
    address public royaltyAddress;
    uint256 public royaltyPercent;
    // ======== PreSale =========
    address public contractOwner;
    uint256 public saleMode = 0; // 0 - register, 1- presale 2- raffle sale 3 - public sale
    mapping(address => uint8) public addressMintedBalance;

    // Merkle Roots
    bytes32 private preSaleRoot;
    bytes32 private raffleRoot;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        string memory _initNotRevealedUri
    ) ERC721A(_name, _symbol) {
        contractOwner = msg.sender;
        setBaseURI(_initBaseURI);
        setNotRevealedURI(_initNotRevealedUri);
        royaltyAddress = owner();
        royaltyPercent = 5;
        remainingReserved = 33;
    }

    // Merkle Proofs
    function _leaf(address _account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account));
    }

    function getSaleMode() public view returns (uint256){
        return saleMode;
    }

    function isPresaleAproved(
        address _account,
        bytes32[] calldata _proof,
        bytes32 _root
    ) internal pure returns (bool) {
        return MerkleProof.verify(_proof, _root, _leaf(_account));
    }
    function isApprovedAddress(
        bytes32[] calldata _proof
    ) public view returns (bool){
        if(saleMode == 1) return MerkleProof.verify(_proof, preSaleRoot, _leaf(msg.sender));
        if(saleMode == 2) return MerkleProof.verify(_proof, raffleRoot, _leaf(msg.sender));
        return true;
    }
    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    
    function setMode(uint256 mode) public payable {
        require(msg.sender == contractOwner, "Only owner can switch mode");
        saleMode = mode;
    }

    // reserve mint
    function reserveMint(uint256 _mintAmount, uint256 batchSize) external onlyOwner {
        require(totalSupply() + _mintAmount <= maxSupply, "Mint exceeds total supply");
        require(remainingReserved - _mintAmount >= 0, "Mint exceeds total supply");
        require(_mintAmount % batchSize == 0, "Can only mint a multiple of batchSize");

        for (uint256 i = 0; i < _mintAmount / batchSize; i++) {
             _safeMint(msg.sender, batchSize);
        }
        remainingReserved = remainingReserved - _mintAmount;
    }

    // preSale
    function preSaleMint(bytes32[] calldata _proof, uint256 _mintAmount)
        external
        payable
    {
        require(msg.sender == tx.origin, "Can't mint through another contract");
        require(saleMode == 1 || saleMode == 2, "not presale mode"); 
        require(!paused);
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _mintAmount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");
        
        bytes32 root;
        uint256 cost;
        uint256 walletLimit;
        
        if (saleMode == 1) {
            root = preSaleRoot;
            walletLimit = allowedLimitPresale;
            cost = preSaleCost;
            }
        else {
            root = raffleRoot;
            walletLimit = maxMintAmount;
            cost = publicCost;
        }

        require(
            isPresaleAproved(msg.sender, _proof, root),
            "not approved for presale"
        );

        uint256 ownerTokenCount = addressMintedBalance[msg.sender];
        require(
            ownerTokenCount + _mintAmount <= walletLimit,
            "max NFT per address exceeded"
        );
         require(
             supply + _mintAmount <= maxSupply - remainingReserved,
             "max NFT limit exceeded"
         );
        require(msg.value >= cost * _mintAmount);

        _safeMint(msg.sender, _mintAmount);
        addressMintedBalance[msg.sender] =
            addressMintedBalance[msg.sender] +
            uint8(_mintAmount);
    }

    // public mint
    function mint(uint256 _mintAmount) external payable {
        require(msg.sender == tx.origin, "Can't mint through another contract");
        require(!paused);
        require(saleMode == 3, "not public sale sate");
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _mintAmount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        
        require(
            supply + _mintAmount <= maxSupply - remainingReserved,
            "max NFT limit exceeded"
        );
        require(msg.value >= publicCost * _mintAmount);

        _safeMint(msg.sender, _mintAmount);
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    //only owner
    function setpreSaleRoot(bytes32 _root) external onlyOwner {
        preSaleRoot = _root;
    }

    //added
    function setraffleRoot(bytes32 _root) external onlyOwner {
        raffleRoot = _root;
    }

    function reveal() public onlyOwner {
        revealed = true;
    }

    function setPresaleLimit(uint256 _limit) public onlyOwner {
        allowedLimitPresale = _limit;
    }

    function setRemainingReserved(uint256 _limit) public onlyOwner {
        remainingReserved = _limit;
    }

    function setPublicCost(uint256 _newCost) public onlyOwner {
        publicCost = _newCost;
    }

    function setpreSaleCost(uint256 _newCost) public onlyOwner {
        preSaleCost = _newCost;
    }

    function setSupply(uint256 _newSupply) public onlyOwner {
        maxSupply = _newSupply;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    // ======== Royalties =========
    function setRoyaltyReceiver(address royaltyReceiver) public onlyOwner {
        royaltyAddress = royaltyReceiver;
    }

    function setRoyaltyPercentage(uint256 royaltyPercentage) public onlyOwner {
        royaltyPercent = royaltyPercentage;
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Non-existent token");
        return (royaltyAddress, (salePrice * royaltyPercent) / 100);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
