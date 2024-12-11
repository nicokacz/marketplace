// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC2981Royalties {
    function royaltyInfo(uint256 _id, uint256 _value)
        external
        view
        returns (address _receiver, uint256 _royaltyAmount);
}

/// @dev This is a contract used to add ERC2981 support to ERC721 and 1155
abstract contract ERC2981Base is ERC165, IERC2981Royalties {
    struct RoyaltyInfo {
        address recipient;  // 20 bytes
        uint24 amount;     // 3 bytes
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

contract ebookNFT is ERC1155URIStorage, Ownable, ERC2981Base, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    Counters.Counter private _ebookIdTracker;
    mapping(uint256 => RoyaltyInfo) public authorList;

    // Constants
    uint24 private constant MAX_ROYALTY = 9000; // 90% in basis points
    
    // Events
    event EbookMinted(uint256 indexed tokenId, address indexed author, uint256 amount, uint24 royalty);
    event RoyaltySet(uint256 indexed tokenId, address indexed author, uint24 royalty);

    constructor() ERC1155("https://ipfs.com/123456789/{id}.json") {
    }

    /// @notice Get the current id of the nft
    /// @return uint256 The current id of the nft
    function getEbookId() public view returns (uint256) {
        return _ebookIdTracker.current();
    }

    /// @notice Mint new ebooks with royalty configuration
    /// @param amount Amount of tokens to mint
    /// @param tokenURI URI for the token metadata
    /// @param royalty Royalty percentage (0-100)
    /// @param author Address to receive royalties
    /// @return id Token ID of the minted ebook
    function safeMint(
        uint256 amount,
        string calldata tokenURI,
        uint24 royalty,
        address payable author
    ) public onlyOwner nonReentrant returns(uint256) {
        require(royalty <= 100, 'ERC2981Royalties: Too high');
        require(amount > 0, 'Invalid amount');

        uint256 id = _ebookIdTracker.current() + 1;
        _ebookIdTracker.increment();
        
        // Convert percentage to basis points (multiply by 100)
        uint24 basisPoints = royalty * 100;
        _setRoyalties(author, id, basisPoints);
        
        _mint(msg.sender, id, amount, "");
        _setURI(id, tokenURI);
        
        emit EbookMinted(id, author, amount, royalty);
        return id;
    }

    /// @notice Set royalties for a token
    /// @dev Internal function to set royalty information
    /// @param author Address to receive royalties
    /// @param ebookId Token ID
    /// @param royalty Royalty amount in basis points
    function _setRoyalties(
        address author,
        uint256 ebookId,
        uint24 royalty
    ) internal {
        require(royalty <= MAX_ROYALTY, 'ERC2981Royalties: Too high');
        require(ebookId > 0 && ebookId <= getEbookId(), "Invalid ebook ID");
        require(author != address(0), "Invalid author address");

        authorList[ebookId] = RoyaltyInfo(author, royalty);
        emit RoyaltySet(ebookId, author, royalty);
    }

    /// @notice Get royalty information for a token sale
    /// @param ebookId Token ID
    /// @param value Sale price
    /// @return receiver Address to receive royalties
    /// @return royaltyAmount Amount of royalties to pay
    function royaltyInfo(
        uint256 ebookId,
        uint256 value
    ) external view override returns (
        address receiver,
        uint256 royaltyAmount
    ) {
        RoyaltyInfo storage royalties = authorList[ebookId];
        return (
            royalties.recipient,
            (value * royalties.amount) / MAX_ROYALTY
        );
    }
    
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC2981Base) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}