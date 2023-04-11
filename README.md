# marketplace

Solidity NFT marketplace with royalties (ERC2981) enabled & possibility to rent the NFT

## Getting Started

 - Clone git repo locally
 - Run the test *npx hardhat test*

## Overview

 _BUY_
 - *listNft* : Create an offer with the NFT, the amount of NFT & the price of sell (for one NFT). The NFTs will be send to the contract.
 - *buyNFT* : Buy an amount of NFTs of an offer. (don't forget to attach some ETH to pay). 2% fees will go to the owner of the marketplace contract and x% (x comes from royaltyInfo() getter from the NFT contract) will go to the author of the NFT (this x% depends on how is implemented the royalty in the NFT contract).
 - *cancelBuyOffer* : remove an offer (thanks to its id) from the marketplace. You have to be the seller to remove it.

_RENT_
 - *listNftForRent* : Create an offer with the NFT, the price of renting and time of rent (in number of block). The NFTs will be send to the contract.
 - *rentNFT* : Rent a NFT of an offer. (don't forget to attach some ETH to pay). 2% fees will go to the owner of the marketplace contract and x% (x comes from royaltyInfo() getter from the NFT contract) will go to the author of the NFT (this x% depends on how is implemented the royalty in the NFT contract).
 - *cancelRentOffer* : remove an offer (thanks to its id) from the marketplace. You have to be the renter to remove it.

## License

This contract is released under the [MIT License].
