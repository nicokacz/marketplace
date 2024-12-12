// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ebookNFT.sol"; 
import "./rentContract.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title A NFT Marketplace using ERC1155,
/// @author nicokacz
/// @notice You can use this contract to list NFT on Marketplace
/// @dev All function calls are currently implemented without side effects
contract Marketplace is ERC1155HolderUpgradeable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    struct NFTMarketItem {
        uint256 nftId;
        uint256 amount;
        uint256 price;
        address payable seller;
        address payable owner;
    }

    struct NFTMarketItemToRent {
        uint256 offerId;
        uint256 nftId;
        uint256 end;
        uint256 price;
        address payable renter;
        address payable tenant;
    }

    ebookNFT private nftContract;
    address private owner;
    address payable marketPlace;
    uint8 private constant PLATFORM_FEE = 2; // in percent
    uint8 private constant DENO = 100;
    
    Counters.Counter public nbOffer;
    Counters.Counter public nbOfferRent;
    
    mapping(uint256 => NFTMarketItem) public marketItem;
    mapping(uint256 => NFTMarketItemToRent) public marketItemToRent;

    constructor(address _nftContract, address _owner) {
        nftContract = ebookNFT(_nftContract); // import the contract of your nft first
        owner = _owner; // owner of the marketplace
        marketPlace = payable(_owner); //To receive the marketplace fee
    }

    /// @notice Get the current id of the offers
    /// @return uint256 The current id of the offers
    function getCurrentOfferId() public view returns (uint256) {
        return nbOffer.current();
    }

    /// @notice Get the current id of the offers
    /// @return uint256 The current id of the offers
    function getCurrentOfferRentId() public view returns (uint256) {
        return nbOfferRent.current();
    }

    /// @notice It will list the $amount of NFT for $price to marketplace.
    /// @dev It will list NFT minted from MFTMint contract.   
    /// @param _nftId the token Id of the nft
    /// @param _amount The amount of NFT to be listed 
    /// @param _price The price of the NFT in wei    
    function listNft(uint256 _nftId, uint256 _amount, uint256 _price) external nonReentrant {
        require(_nftId >= 0, "NFT doesnt exist");
        require(_nftId <= nftContract.getEbookId(), "NFT does not exist");
        require(_price >= 10000000000000, "Price has to be greater or equal than 0.00001 ETH");
        require(_amount >= 0, "Amount has to be greater or equal than 0");
        require(_amount <= nftContract.balanceOf(msg.sender, _nftId), "You dont have enough NFT");

        nbOffer.increment();

        uint256 offerId = nbOffer.current();

        marketItem[offerId] = NFTMarketItem(
            _nftId,
            _amount,
            _price,
            payable(msg.sender),
            payable(msg.sender)
        );
        
        ebookNFT(nftContract).safeTransferFrom(msg.sender, address(this), _nftId, _amount, "");
    }

    event NFTBuy(uint256 offerId, uint256 nftId, address authorAddress, uint256 royaltyPer);

    /// @notice It will buy $amount NFT of the $offerId from marketplace.
    /// @param _offerId The id of the offer to buy    
    /// @param _amount The amount of NFT to be buyed 
    /// @dev User will able to buy NFT and transfer to respectively owner or user and platform fees, roylty fees also deducted          from this function.
    function buyNFT(uint256 _offerId, uint256 _amount) public payable nonReentrant {
        require(
            _offerId >= 1 &&
            _offerId <= nbOffer.current() &&
            marketItem[_offerId].amount >= _amount,
            "Invalid offer or amount"
        );
        require(msg.value >= (marketItem[_offerId].price * _amount), "Invalid value");
        require(
            _amount <= nftContract.balanceOf(address(this), marketItem[_offerId].nftId),
            "Insufficient NFT balance"
        );

        uint256 nftId = marketItem[_offerId].nftId;
        (address authorAddress, uint256 royaltyPer) = nftContract.royaltyInfo(nftId, msg.value);
        uint256 marketFee = ((msg.value * PLATFORM_FEE) / DENO) * _amount;
        address payable seller = marketItem[_offerId].seller;

        _processPayments(seller, authorAddress, msg.value - royaltyPer - marketFee, royaltyPer, marketFee);

        marketItem[_offerId].owner = payable(msg.sender);
        marketItem[_offerId].amount = marketItem[_offerId].amount - _amount;

        if(marketItem[_offerId].amount == 0) {
            if(nbOffer.current() > 1) {
                marketItem[_offerId] = marketItem[nbOffer.current()];
            }
            nbOffer.decrement();
        }
        
        nftContract.safeTransferFrom(address(this), msg.sender, nftId, _amount, "");
        emit NFTBuy(_offerId, nftId, authorAddress, royaltyPer);
    }

    event buyOfferCancel(uint256 offerId);

    /// @notice It will cancel the $offerId of to marketplace.
    /// @dev It will remove the offer from the market place.   
    /// @param _offerId The id of the offer to be cancelled
    function cancelBuyOffer(uint256 _offerId) external nonReentrant {
        require(_offerId >= 1, "Offer doesnt exist");
        require(_offerId <= nbOffer.current(), "Offer doesnt exist");
        require(marketItem[_offerId].seller == msg.sender, "You are not the seller");
        require(marketItem[_offerId].amount <= nftContract.balanceOf(address(this), marketItem[_offerId].nftId), "The marketplace has not enough NFT");

        uint amount = marketItem[_offerId].amount;
        uint nftId = marketItem[_offerId].nftId;
        
        if(nbOffer.current() > 1){
            //delete actual offer with the last one
            marketItem[_offerId] = marketItem[nbOffer.current()];
        }
        nbOffer.decrement();

        //Send back the NFTs to seller
        nftContract.safeTransferFrom(address(this), msg.sender, nftId, amount, "");

        emit buyOfferCancel(_offerId);
    }


    /* RENTING PART */
    event NFTListedToRent(uint256 offerId, uint256 nftId);

    /// @notice It will list the NFT to rent for $price to marketplace.
    /// @dev It will list NFT minted from MFTMint contract.   
    /// @param _nftId the token Id of the nft
    /// @param _price The price of the NFT in wei
    /// @param _end Number of block before the end of the rent     
    function listNftForRent(uint256 _nftId, uint256 _price, uint256 _end) external nonReentrant {
        require(_nftId >= 0, "NFT doesnt exist");
        require(_nftId <= nftContract.getEbookId(), "NFT does not exist");
        require(_price >= 10000000000000, "Price has to be greater or equal than 0.00001 ETH");
        require(nftContract.balanceOf(msg.sender, _nftId) >= 1, "You dont have enough NFT");
        require(_end >= 100, "End of rent must be over or equal than 100 blocks");

        nbOfferRent.increment();

        uint256 offerRentId = nbOfferRent.current();

        marketItemToRent[offerRentId] = NFTMarketItemToRent(
            offerRentId,
            _nftId,
            _end,
            _price,
            payable(msg.sender),
            payable(msg.sender)
        );
        
        // Send one NFT to the marketplace
        nftContract.safeTransferFrom(msg.sender, address(this), _nftId, 1, "");

        emit NFTListedToRent(offerRentId, _nftId);
    }


    event NFTRent(uint256 offerId, uint256 nftId, address tenantAddress, address rentingContract, uint256 blockend);

    /// @notice It will rent an NFT of the $offerId from marketplace.
    /// @param _offerId The id of the offer to rent    
    /// @dev User will able to rent NFT and transfer to respectively owner or user and platform fees, roylty fees also deducted from this function.
    function rentNFT(uint256 _offerId) public payable nonReentrant {
        require(
            _offerId >= 1 &&
            _offerId <= nbOfferRent.current() &&
            marketItemToRent[_offerId].offerId == _offerId,
            "Invalid offer"
        );
        require(msg.value >= marketItemToRent[_offerId].price, "Invalid value send");
        require(
            nftContract.balanceOf(address(this), marketItemToRent[_offerId].nftId) >= 1,
            "Insufficient NFT balance"
        );

        uint256 nftId = marketItemToRent[_offerId].nftId;
        (address authorAddress, uint256 royaltyPer) = nftContract.royaltyInfo(nftId, msg.value);
        uint256 marketFee = (msg.value * PLATFORM_FEE) / DENO;
        address payable renter = marketItemToRent[_offerId].renter;

        _processPayments(renter, authorAddress, msg.value - royaltyPer - marketFee, royaltyPer, marketFee);

        marketItemToRent[_offerId].tenant = payable(msg.sender);
        uint256 end = marketItemToRent[_offerId].end;

        if(nbOfferRent.current() > 1) {
            marketItemToRent[_offerId] = marketItemToRent[nbOfferRent.current()];
        }
        nbOfferRent.decrement();

        rentContract rentingContract = new rentContract(
            address(nftContract),
            nftId,
            renter,
            msg.sender,
            end
        );
        
        nftContract.safeTransferFrom(address(this), address(rentingContract), nftId, 1, "");
        uint256 blockend = rentingContract.startRent();

        emit NFTRent(_offerId, nftId, msg.sender, address(rentingContract), blockend);
    }

    function _processPayments(
        address payable recipient,
        address authorAddress,
        uint256 amount,
        uint256 royalty,
        uint256 fee
    ) private {
        (bool sent,) = recipient.call{value: amount}("");
        require(sent, "Failed to send payment to recipient");
        
        (sent,) = payable(authorAddress).call{value: royalty}("");
        require(sent, "Failed to send royalty");
        
        (sent,) = marketPlace.call{value: fee}("");
        require(sent, "Failed to send marketplace fee");
    }

    event rentOfferCancel(uint256 offerId);

    /// @notice It will cancel the $offerId of to marketplace.
    /// @dev It will remove the offer from the market place.   
    /// @param _offerId The id of the offer to be cancelled
    function cancelRentOffer(uint256 _offerId) external nonReentrant {
        require(_offerId > 0, "Offer doesnt exist");
        require(_offerId <= nbOfferRent.current(), "Offer doesnt exist");
        require(marketItemToRent[_offerId].renter == msg.sender, "You are not the renter");
        require( nftContract.balanceOf(address(this), marketItemToRent[_offerId].nftId) >= 1, "The marketplace has not enough NFT");

        uint nftId = marketItemToRent[_offerId].nftId;
        
        if(nbOfferRent.current() > 1){
            //delete actual rent offer with the last one
            marketItemToRent[_offerId] = marketItemToRent[nbOfferRent.current()];
        }
        nbOfferRent.decrement();

        //Send back the NFTs to seller
        nftContract.safeTransferFrom(address(this), msg.sender, nftId, 1, "");

        emit rentOfferCancel(_offerId);
    }

}