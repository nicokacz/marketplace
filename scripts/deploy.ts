import { ethers } from "hardhat";

async function main() {

  const EbookNFT = await ethers.getContractFactory("ebookNFT");
  const ebookNFT = await EbookNFT.deploy();

  await ebookNFT.deployed();

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(ebookNFT.address, "" );

  await marketplace.deployed();

  console.log(`marketplace deployed to ${marketplace.address}, NFT deployed to ${ebookNFT.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
