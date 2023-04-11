import { ethers } from "hardhat";
require('dotenv').config();

async function main() {

  const EbookNFT = await ethers.getContractFactory("ebookNFT");
  const ebookNFT = await EbookNFT.deploy();

  await ebookNFT.deployed();

  let owner:string = process.env.MARKETPLACE_OWNER_AD!;

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(ebookNFT.address, owner );

  await marketplace.deployed();

  console.log(`marketplace deployed to ${marketplace.address}, NFT deployed to ${ebookNFT.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
