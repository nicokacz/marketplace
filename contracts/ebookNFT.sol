// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';

interface IERC2981Royalties {
    function royaltyInfo(uint256 _id, uint256 _value)
        external
        view
        returns (address _receiver, uint256 _royaltyAmount);
}

/// @dev This is a contract used to add ERC2981 support to ERC721 and 1155
abstract contract ERC2981Base is ERC165, IERC2981Royalties {
    struct RoyaltyInfo {
        address recipient;
        uint24 amount;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC2981Royalties).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

contract ebookNFT is ERC1155URIStorage, Ownable, ERC2981Base {
    using Counters for Counters.Counter;
    
    Counters.Counter private _ebookIdTracker;
    mapping(uint256 => RoyaltyInfo) public authorList;

    constructor() ERC1155("https://ipfs.com/123456789/{id}.json") {
    }

    /// @notice Get the current id of the nft
    /// @return uint256 The current id of the nft
    function getEbookId() public view returns (uint256) {
        return _ebookIdTracker.current();
    }

    /// @notice Mint $amount of the nft describe with metadata json file $tokenURI, with $royalty to be paid to the $author
    /// @return id of the nft freshly minted
    /// @param royalty Royalty is in percent so 100 = 100% , 1 = 1% etc
    function safeMint(
        uint256 amount,
        string memory tokenURI,
        uint24 royalty,
        address payable author
    ) public onlyOwner returns(uint256) {
        require(royalty <= 100, 'ERC2981Royalties: Too high');
        require(royalty >= 0, 'ERC2981Royalties: Too low');
        require(amount > 0, 'At least create one NFT please... :)');

        _ebookIdTracker.increment();
        uint256 id = _ebookIdTracker.current();
        _setRoyalties(author, id, royalty*100);
        _mint(msg.sender, id, amount, "");
        _setURI(id, tokenURI);
        return id;
    } 

    //TODO : emit event

    /*
    For opensea
    {
        "name": "NFT Contract",
        "description": "Really cool description about my art",
        "image": "https://openseacreatures.io/image.png", # Link to collection image
        "external_link": "https://openseacreatures.io", # Link to website
        "seller_fee_basis_points": 100, # Indicates a 1% seller fee.
        "fee_recipient": "0xA97F337c39cccE66adfeCB2BF99C1DdC54C2D721" # Where seller fees will be paid to.
    }

    
    function contractURI() public view returns (string memory) {
        return "https://metadata-url.com/my-metadata";
    }
    
    function mint( address to, uint256 id, uint256 amount) public onlyOwner {
        _mint(to, id, amount, "");
    }
    function burn( address from, uint256 id, uint256 amount) public {
        require(msg.sender == from);
        _burn(from, id, amount);
    }*/
    
    // Royalty is in basis points so 10000 = 100% , 100 = 1% etc
    function _setRoyalties(address author,uint256 ebookId, uint24 royalty) internal {
        require(royalty <= 10000, 'ERC2981Royalties: Too high');
        require(royalty >= 0, 'ERC2981Royalties: Too low');
        require(ebookId >= 0, "NFT doesnt exist");
        require(ebookId <= getEbookId(), "NFT does not exist");

        authorList[ebookId] = RoyaltyInfo(author, uint24(royalty));
    }

    function royaltyInfo(uint256 ebookId, uint256 value)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory royalties = authorList[ebookId];
        receiver = royalties.recipient;
        royaltyAmount = (value * royalties.amount) / 10000;
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC2981Base) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}