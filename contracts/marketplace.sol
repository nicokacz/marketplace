// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma abicoder v2;

import "./ebookNFT.sol"; 
import "./rentContract.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title A NFT Marketplace using ERC1155,
/// @author nicokacz
/// @notice You can use this contract to list NFT on Marketplace
/// @dev All function calls are currently implemented without side effects
contract  Marketplace is ERC1155Holder {
    using Counters for Counters.Counter;
    Counters.Counter private offerIds;
    Counters.Counter private nftSold;
    ebookNFT private nftContract;
    address private owner;
    address payable marketPlace;
    uint256 private platformFee = 2;// in percent
    uint256 private deno = 100;
    Counters.Counter public nbOffer;
    mapping(uint256 => NFTMarketItem) public marketItem;
    mapping(uint256 => NFTMarketItem) public marketItemSold;

    //Rent    
    Counters.Counter private offerRentIds;
    Counters.Counter public nbOfferRent;
    Counters.Counter private nftRented;
    mapping(uint256 => NFTMarketItemToRent) public marketItemToRent;
    mapping(uint256 => NFTMarketItemToRent) public marketItemRented;


    constructor(address _nftContract, address _owner) {
        nftContract = ebookNFT(_nftContract); // import the contract of your nft first
        owner = _owner; // owner of the marketplace
        marketPlace = payable(_owner); //To receive the marketplace fee
    }

    struct NFTMarketItem{
        uint256 offerId;
        uint256 nftId;
        uint256 amount;
        uint256 price;
        address payable seller;
        address payable owner;
    }

    struct NFTMarketItemToRent{
        uint256 offerId;
        uint256 nftId;
        uint256 end;
        uint256 price;
        address payable renter;
        address payable tenant;
    }

    /// @notice Get the current id of the offers
    /// @return uint256 The current id of the offers
    function getCurrentOfferId() public view returns (uint256) {
        return offerIds.current();
    }

    /// @notice It will list the $amount of NFT for $price to marketplace.
    /// @dev It will list NFT minted from MFTMint contract.   
    /// @param _nftId the token Id of the nft
    /// @param _amount The amount of NFT to be listed 
    /// @param _price The price of the NFT in wei    
    function listNft(uint256 _nftId, uint256 _amount, uint256 _price) external {
        require(_nftId >= 0, "NFT doesnt exist");
        require(_nftId <= nftContract.getEbookId(), "NFT does not exist");
        require(_price >= 10000000000000, "Price has to be greater or equal than 0.00001 ETH");
        require(_amount >= 0, "Amount has to be greater or equal than 0");
        require(_amount <= nftContract.balanceOf(msg.sender, _nftId), "You dont have enough NFT");

        offerIds.increment();
        nbOffer.increment();

        uint256 offerId = offerIds.current();

        marketItem[offerId] = NFTMarketItem(
            offerId,
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
    function buyNFT(uint256 _offerId, uint256 _amount) public payable {
        require(_offerId >= 0, "Offer doesnt exist");
        require(_offerId <= offerIds.current(), "Offer does not exist");
        require(marketItem[_offerId].amount >= 1, "No more NFT to sell");
        require((msg.value) >= SafeMath.mul(marketItem[_offerId].price, _amount), "Invalid value send");
        require(marketItem[_offerId].amount >= _amount, "No enough NFT to sell");
        require(_amount <= nftContract.balanceOf(address(this), marketItem[_offerId].nftId), "The marketplace has not enough NFT");

        uint256 nftId = marketItem[_offerId].nftId;
        (address authorAddress, uint256 royaltyPer) = nftContract.royaltyInfo(nftId, msg.value );
        //                = (msg.value * platformFee / deno) * _amount;
        uint256 marketFee = SafeMath.mul(SafeMath.div(SafeMath.mul(msg.value, platformFee), deno), _amount);
        address payable seller = marketItem[_offerId].seller;

        // Price without royalty and fee
        (bool sent, bytes memory data) = seller.call{value: (SafeMath.sub(SafeMath.sub(msg.value, royaltyPer), marketFee))}("");
        require(sent, "Failed to send fee to seller");

        // Royalties for Author
        (sent, data) = payable(authorAddress).call{value: royaltyPer}("");
        require(sent, "Failed to send fee to author");

        // Market place
        (sent, data) = marketPlace.call{value: marketFee}("");
        require(sent, "Failed to send fee to marketplace");

        marketItem[_offerId].owner = payable(msg.sender);
        marketItem[_offerId].amount = SafeMath.sub(marketItem[_offerId].amount, _amount);
        nftSold.increment();
        marketItemSold[nftSold.current()] = NFTMarketItem(
            marketItem[_offerId].offerId,
            marketItem[_offerId].nftId,
            _amount,
            SafeMath.mul(marketItem[_offerId].price, _amount),
            payable(msg.sender),
            payable(msg.sender)
        );

        //No more item to sell in this offer, delete it
        if(marketItem[_offerId].amount == 0){
            nbOffer.decrement();
            delete(marketItem[_offerId]);
        }
        
        nftContract.safeTransferFrom(address(this), msg.sender, nftId, _amount, "");

        emit NFTBuy(_offerId, nftId, authorAddress, royaltyPer);
    }

    event buyOfferCancel(uint256 offerId);

    /// @notice It will cancel the $offerId of to marketplace.
    /// @dev It will remove the offer from the market place.   
    /// @param _offerId The id of the offer to be cancelled
    function cancelBuyOffer(uint256 _offerId) external {
        require(_offerId >= 0, "Offer doesnt exist");
        require(_offerId <= offerIds.current(), "Offer doesnt exist");
        require(marketItem[_offerId].seller == msg.sender, "You are not the seller");
        require(marketItem[_offerId].amount <= nftContract.balanceOf(address(this), marketItem[_offerId].nftId), "The marketplace has not enough NFT");

        uint amount = marketItem[_offerId].amount;
        uint nftId = marketItem[_offerId].nftId;
        //Set amount to 0, no more to sell
        marketItem[_offerId].amount = 0;
        delete(marketItem[_offerId]);
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
    function listNftForRent(uint256 _nftId, uint256 _price, uint256 _end) external {
        require(_nftId >= 0, "NFT doesnt exist");
        require(_nftId <= nftContract.getEbookId(), "NFT does not exist");
        require(_price >= 10000000000000, "Price has to be greater or equal than 0.00001 ETH");
        require(nftContract.balanceOf(msg.sender, _nftId) >= 1, "You dont have enough NFT");
        require(_end >= 100, "End of rent must be over or equal than 100 blocks");

        offerRentIds.increment();
        nbOfferRent.increment();

        uint256 offerRentId = offerRentIds.current();

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


    event NFTRent(uint256 offerId, uint256 nftId, address tenantAddress, address rentingContract);

    /// @notice It will rent an NFT of the $offerId from marketplace.
    /// @param _offerId The id of the offer to rent    
    /// @dev User will able to rent NFT and transfer to respectively owner or user and platform fees, roylty fees also deducted from this function.
    function rentNFT(uint256 _offerId) public payable {
        require(_offerId >= 0, "Offer doesnt exist");
        require(_offerId <= offerRentIds.current(), "Offer does not exist");
        require((msg.value) >= marketItemToRent[_offerId].price, "Invalid value send");
        require(nftContract.balanceOf(address(this), marketItemToRent[_offerId].nftId) >= 1, "The marketplace has not enough NFT");

        uint256 nftId = marketItemToRent[_offerId].nftId;
        (address authorAddress, uint256 royaltyPer) = nftContract.royaltyInfo(nftId, msg.value );
        //                = (msg.value * platformFee / deno);
        uint256 marketFee = SafeMath.div(SafeMath.mul(msg.value, platformFee), deno);
        address payable renter = marketItemToRent[_offerId].renter;

        // Price without royalty and fee
        (bool sent, bytes memory data) = renter.call{value: (SafeMath.sub(SafeMath.sub(msg.value, royaltyPer), marketFee))}("");
        require(sent, "Failed to send fee to renter");

        // Royalties for Author
        (sent, data) = payable(authorAddress).call{value: royaltyPer}("");
        require(sent, "Failed to send fee to author");

        // Market place
        (sent, data) = marketPlace.call{value: marketFee}("");
        require(sent, "Failed to send fee to marketplace");

        marketItemToRent[_offerId].tenant = payable(msg.sender);
        nftRented.increment();
        marketItemRented[nftRented.current()] = NFTMarketItemToRent(
            marketItemToRent[_offerId].offerId,
            marketItemToRent[_offerId].nftId,
            marketItemToRent[_offerId].end,
            marketItemToRent[_offerId].price,
            marketItemToRent[_offerId].renter,
            payable(msg.sender)
        );

        uint256 end = marketItemToRent[_offerId].end;

        //No more item to sell in this offer, delete it
        delete(marketItemToRent[_offerId]);
        nbOfferRent.decrement();

        //Create the rent contract
        rentContract rentingContract = new rentContract(address(nftContract), nftId, renter, msg.sender, end);
        
        //Send the NFT to the contract
        nftContract.safeTransferFrom(address(this), address(rentingContract), nftId, 1, "");

        //Start the rent (and transfer one NFT)
        rentingContract.startRent();

        emit NFTRent(_offerId, nftId, msg.sender, address(rentingContract));
    }


    event rentOfferCancel(uint256 offerId);

    /// @notice It will cancel the $offerId of to marketplace.
    /// @dev It will remove the offer from the market place.   
    /// @param _offerId The id of the offer to be cancelled
    function cancelRentOffer(uint256 _offerId) external {
        require(_offerId >= 0, "Offer doesnt exist");
        require(_offerId <= offerRentIds.current(), "Offer doesnt exist");
        require(marketItemToRent[_offerId].renter == msg.sender, "You are not the renter");
        require( nftContract.balanceOf(address(this), marketItemToRent[_offerId].nftId) >= 1, "The marketplace has not enough NFT");

        uint nftId = marketItemToRent[_offerId].nftId;
        //Set amount to 0, no more to sell
        delete(marketItemToRent[_offerId]);
        nbOfferRent.decrement();

        //Send back the NFTs to seller
        nftContract.safeTransferFrom(address(this), msg.sender, nftId, 1, "");

        emit rentOfferCancel(_offerId);
    }

}