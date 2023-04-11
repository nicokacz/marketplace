// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./ebookNFT.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Contrat to rent an NFT,
/// @author nicokacz
/// @notice You can use this contract to list NFT on Marketplace
/// @dev All function calls are currently implemented without side effects
contract  rentContract is ERC1155Holder, Ownable {
    ebookNFT private nftContract;
    uint256 blockend;
    uint256 nftId;
    address renter;
    address tenant;
    uint256 end;
    uint256 price;

    // modifier renterOrTenant() {
    //     require(msg.sender == renter || msg.sender == tenant, "Only the renter or the tenant ");
    //     _;
    // }


    /// @notice It will create a contract to rent an NFT
    /// @dev It will create a contract to rent an NFT.   
    /// @param _nftContract address of the ebookNFT contract
    /// @param _nftId the token Id of the nft
    /// @param _renter the renter/lender of the nft
    /// @param _tenant the tenant of the nft
    /// @param _end Number of block before the end of the rent
    constructor(address _nftContract, uint256 _nftId, address _renter, address _tenant, uint256 _end) {
        //require((msg.value) >= _price, "Invalid value send");
        require(_end >= 100, "End of rent must be over or equal than 100 blocks");
        
        nftContract = ebookNFT(_nftContract); // import the contract of your nft first
        nftId = _nftId;
        renter = _renter;
        tenant = _tenant;
        end = _end;
    }

    function startRent() onlyOwner external {
        //check that the lender has at least one NFT to rent
        require(nftContract.balanceOf(address(this), nftId) >= 1, "Cannot startRent : the contract don't have NFT");
        blockend = block.timestamp + end;
    }


    function stopRent() external {
        //check that the lender has at least one NFT to rent
        // check blockend = block.timestamp + end;
        require(blockend <= block.timestamp, "Renting period not over");
        nftContract.safeTransferFrom(address(this), renter, nftId, 1, "");

    }
    
}