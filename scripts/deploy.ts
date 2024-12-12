import { ethers, run } from "hardhat";
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

  // Wait for a few block confirmations to ensure the contracts are deployed
  console.log("Waiting for block confirmations...");
  await ebookNFT.deployTransaction.wait(5);
  await marketplace.deployTransaction.wait(5);

  // Verify the contracts
  console.log("Verifying contracts...");
  try {
    await run("verify:verify", {
      address: ebookNFT.address,
      constructorArguments: [],
    });
    console.log("NFT contract verified successfully");
  } catch (error: any) {
    if (error.message.includes("Already Verified")) {
      console.log("NFT contract already verified");
    } else {
      console.error("Error verifying NFT contract:", error);
    }
  }

  try {
    await run("verify:verify", {
      address: marketplace.address,
      constructorArguments: [ebookNFT.address, owner],
    });
    console.log("Marketplace contract verified successfully");
  } catch (error: any) {
    if (error.message.includes("Already Verified")) {
      console.log("Marketplace contract already verified");
    } else {
      console.error("Error verifying Marketplace contract:", error);
    }
  }

  console.log("Minting NFT...");
  try {
    const mintTx = await ebookNFT.safeMint(
      1000, // amount
      "https://pink-crooked-grouse-531.mypinata.cloud/ipfs/bafkreian2r576ljsdmcy7spb2bwduihudgk52fx6jlq7sxcaw7q67du7sa", // tokenURI
      20, // royalty percentage
      "0x1CbBBed99ba6E63238fE74BF89c1df0eaAA505C6" // author address
    );
    await mintTx.wait(2); // wait for 2 block confirmations
    console.log("NFT minted successfully");
  } catch (error) {
    console.error("Error minting NFT:", error);
  }

  // Convert prices to wei (0.001 ETH = 1000000000000000 wei)
  const salePrice = ethers.utils.parseEther("0.001");
  const rentPrice = ethers.utils.parseEther("0.00001");
  
  // Get current NFT ID
  const nftId = await ebookNFT.getEbookId();
  
  console.log("Listing NFTs for sale...");
  try {
    // First approve marketplace to handle NFTs
    const approveTx = await ebookNFT.setApprovalForAll(marketplace.address, true);
    await approveTx.wait(2);
    
    // List 10 NFTs for sale
    const listSaleTx = await marketplace.listNft(nftId, 10, salePrice);
    await listSaleTx.wait(2);
    console.log("Successfully listed 10 NFTs for sale");
  } catch (error) {
    console.error("Error listing NFTs for sale:", error);
  }

  console.log("Listing NFTs for rent...");
  try {
    // List 10 NFTs for rent (approximately 1 week = ~50400 blocks with 12 sec block time)
    const listRentTx = await marketplace.listNftForRent(nftId, rentPrice, 50400);
    await listRentTx.wait(2);
    console.log("Successfully listed NFT for rent");
  } catch (error) {
    console.error("Error listing NFT for rent:", error);
  }

  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
