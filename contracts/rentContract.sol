// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./ebookNFT.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title Smart contract for NFT rentals
/// @author nicokacz
/// @notice Manages the rental of NFTs with time-based constraints
/// @dev Implements reentrancy protection and ownership functionality
contract RentContract is ERC1155Holder, Ownable, ReentrancyGuard {
    // State variables
    ebookNFT public immutable nftContract;
    uint256 public blockend;
    uint256 public immutable nftId;
    address public immutable renter;
    address public immutable tenant;
    uint256 private immutable rentDuration;
    bool public isActive;
    
    // Constants
    uint256 private constant MIN_DURATION = 100;
    uint256 private constant MAX_DURATION = 31536000; // 1 year in seconds
    
    // Events
    event RentStarted(
        address indexed contractAddress,
        address indexed renter,
        address indexed tenant,
        uint256 nftId,
        uint256 duration,
        uint256 endTime
    );
    
    event RentStopped(
        address indexed renter,
        address indexed tenant,
        uint256 indexed nftId,
        uint256 endTime,
        uint256 actualEndTime
    );
    
    event RentExtended(
        uint256 indexed nftId,
        uint256 newEndTime,
        uint256 extensionDuration
    );

    // Custom errors for gas optimization
    error InvalidDuration();
    error InvalidAddress();
    error RentNotActive();
    error RentStillActive();
    error NoNFTInContract();
    error UnauthorizedCaller();
    error RentExpired();

    modifier onlyRenterOrTenant() {
        if(msg.sender != renter && msg.sender != tenant) {
            revert UnauthorizedCaller();
        }
        _;
    }

    modifier whenRentActive() {
        if(!isActive) {
            revert RentNotActive();
        }
        _;
    }

    /// @notice Creates a new rental contract for an NFT
    /// @param _nftContract Address of the NFT contract
    /// @param _nftId Token ID of the NFT
    /// @param _renter Address of the NFT owner/renter
    /// @param _tenant Address of the person renting the NFT
    /// @param _duration Duration of the rental in seconds
    constructor(
        address _nftContract,
        uint256 _nftId,
        address _renter,
        address _tenant,
        uint256 _duration
    ) {
        if(_duration < MIN_DURATION || _duration > MAX_DURATION) revert InvalidDuration();
        if(_renter == address(0) || _tenant == address(0)) revert InvalidAddress();
        if(_renter == _tenant) revert InvalidAddress();
        
        nftContract = ebookNFT(_nftContract);
        nftId = _nftId;
        renter = _renter;
        tenant = _tenant;
        rentDuration = _duration;
        isActive = false;
    }

    /// @notice Starts the rental period
    /// @dev Can only be called by the contract owner (marketplace)
    /// @return uint256 The timestamp when the rental period ends
    function startRent() 
        external 
        onlyOwner 
        nonReentrant 
        returns (uint256)
    {
        if(nftContract.balanceOf(address(this), nftId) != 1) {
            revert NoNFTInContract();
        }
        
        blockend = block.timestamp + rentDuration;
        isActive = true;

        emit RentStarted(
            address(this),
            renter,
            tenant,
            nftId,
            rentDuration,
            blockend
        );
        
        return blockend;
    }

    /// @notice Stops the rental and returns the NFT to the owner
    /// @dev Can be called by anyone after the rental period ends
    function stopRent() 
        external 
        nonReentrant 
        whenRentActive 
    {
        if(nftContract.balanceOf(address(this), nftId) != 1) {
            revert NoNFTInContract();
        }
        if(block.timestamp < blockend) {
            revert RentStillActive();
        }

        isActive = false;
        nftContract.safeTransferFrom(address(this), renter, nftId, 1, "");

        emit RentStopped(
            renter,
            tenant,
            nftId,
            blockend,
            block.timestamp
        );
    }

    /// @notice Returns the remaining time of the rental
    /// @return uint256 Remaining time in seconds, 0 if expired
    function remainingTime() 
        external 
        view 
        whenRentActive 
        returns (uint256) 
    {
        if(block.timestamp >= blockend) return 0;
        return blockend - block.timestamp;
    }

    /// @notice Checks if the rental is expired
    /// @return bool True if expired, false otherwise
    function isExpired() 
        external 
        view 
        whenRentActive 
        returns (bool) 
    {
        return block.timestamp >= blockend;
    }
}