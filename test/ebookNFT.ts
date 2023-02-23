//import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";
import { Marketplace__factory } from "../typechain-types";
//import "@nomiclabs/hardhat-waffle"
//var chai = require('chai');
//chai.use(require('chai-bignumber')(ethers.BigNumber));

async function main() {
    
}

describe("ebookNFT & Marketplace tests", async function () {

    // create a ebookNFT variable
    let ebookNFT: Contract;
    let marketplace: Contract;

    let Marketplace: Marketplace__factory;

    let ads: any[] = [];

    this.beforeAll(async function() {
        // This is executed before each test
        // Deploying the smart contract
        const EbookNFT = await ethers.getContractFactory("ebookNFT");
        ebookNFT = await EbookNFT.deploy();
        Marketplace = await ethers.getContractFactory("Marketplace");
        
        ads = await ethers.getSigners();
    })

    it("NFT is minted successfully", async function() {
        let owner = ads[0];
        let marketplaceAd = ads[1];
        let author = ads[2];
        //const [owner, marketplaceAd] = await ethers.getSigners();
        //console.log(await ebookNFT.balanceOf(owner.address, 1));
        let balance = await ebookNFT.balanceOf(owner.address, 1);
        //console.log(balance);
        
        expect(balance.toNumber(), "BalanceOf should be 0").to.equal(0);
        
        const tokenURI = "https://opensea-creatures-api.herokuapp.com/api/creature/1"
        const tx = await ebookNFT.connect(owner).safeMint(1000, tokenURI, 10, author.address);
        //console.log(tx);
        balance = await ebookNFT.balanceOf(owner.address, 1);
        expect(balance.toNumber()).to.equal(1000);

        marketplace  = await Marketplace.deploy(ebookNFT.address, marketplaceAd.address);

        const tx2 = await ebookNFT.connect(owner).setApprovalForAll(marketplace.address, true);

        //console.log(await ebookNFT.isApprovedForAll(owner.address, marketplace.address ));
        expect(await ebookNFT.isApprovedForAll(owner.address, marketplace.address )).to.equal(true);

        
    })

    it("NFT is list in marketplace successfully", async function() {
        let owner = ads[0];
        let marketplaceAd = ads[1];

        const tx3 = await marketplace.connect(owner).listNft(1, 1, 10000000000000);
        let nbOffer = await marketplace.nbOffer();
        expect(nbOffer.toNumber()).to.equal(1);
        let balance = await ebookNFT.balanceOf(owner.address, 1);
        expect(balance.toNumber()).to.equal(999);
    });

    it("Offer in marketplace cancelled successfully", async function() {
        let owner = ads[0];
        let marketplaceAd = ads[1];

        const tx4 = await marketplace.connect(owner).cancelBuyOffer(1);
        let nbOffer = await marketplace.nbOffer();
        expect(nbOffer.toNumber()).to.equal(0);

        let balance = await ebookNFT.balanceOf(owner.address, 1);
        expect(balance.toNumber()).to.equal(1000);

    });

    it("Buy an NFT from the marketplace successfully", async function() {
        let owner = ads[0];
        let marketplaceAd = ads[1];
        let author = ads[2];
        let buyer = ads[3];
        
        const tx3 = await marketplace.connect(owner).listNft(1, 1, 10000000000000);
        let nbOffer = await marketplace.nbOffer();
        expect(nbOffer.toNumber()).to.equal(1);

        let balance = await ebookNFT.balanceOf(owner.address, 1);
        expect(balance.toNumber(), "list ok").to.equal(999);

        balance = await ebookNFT.balanceOf(buyer.address, 1);
        expect(balance.toNumber()).to.equal(0);

        //console.log(await marketplace.marketItem(0));
        //console.log(await marketplaceAd.getBalance());
        let marketplaceAdBalanceBefore = await marketplaceAd.getBalance();
        let ownerBalanceBefore = await owner.getBalance();
        let buyerBalanceBefore = await buyer.getBalance();
        let authorBalanceBefore = await author.getBalance();

        const tx5 = await marketplace.connect(buyer).buyNFT(2, 1, {value: 10000000000000} );

        let ownerBalanceAfter = await owner.getBalance();
        let marketplaceAdBalanceAfter = await marketplaceAd.getBalance();

        // Check the marketplace fees
        //console.log(marketplaceAdBalanceBefore, marketplaceAdBalanceAfter, marketplaceAdBalanceAfter.sub(marketplaceAdBalanceBefore));
        let marketplaceFees = marketplaceAdBalanceAfter.sub(marketplaceAdBalanceBefore);
        let fee = ethers.BigNumber.from(10000000000000 * 0.02);
        // 10% royalties + 2% marketplace fees
        expect(marketplaceFees.toNumber(), "marketplaceFees issue").to.equal(fee.toNumber());

        let balanceAfter = await ebookNFT.balanceOf(buyer.address, 1);
        expect(balanceAfter.toNumber()).to.equal(1);
        let buyerBalanceAfter = await buyer.getBalance();
        let authorBalanceAfter = await author.getBalance();

        nbOffer = await marketplace.nbOffer();
        expect(nbOffer.toNumber()).to.equal(0);

        //Check the owner fees
        //console.log(ownerBalanceBefore, ownerBalanceAfter, ownerBalanceAfter.sub(ownerBalanceBefore));
        let ownerFees = ownerBalanceAfter.sub(ownerBalanceBefore);

        let ownerFeesExpected = ethers.BigNumber.from(10000000000000 * (1 - 0.1 - 0.02));
        // 10% royalties + 2% marketplace fees
        expect(ownerFees.toNumber(), "ownerFees issue").to.equal(ownerFeesExpected.toNumber());

        //console.log(buyerBalanceBefore, buyerBalanceAfter, buyerBalanceBefore.sub(buyerBalanceAfter));
        //console.log(authorBalanceBefore, authorBalanceAfter, authorBalanceAfter.sub(authorBalanceBefore));

        let buyerFees = buyerBalanceBefore - buyerBalanceAfter;
        //Buyer balance after buying has to be lower than before
        expect(buyerFees, "Buyer balance issue").to.gt(10000000000000);

        //Check the royalties
        let royaltyFeesExpected = ethers.BigNumber.from(10000000000000 * 0.1);
        let royaltyFees = authorBalanceAfter.sub(authorBalanceBefore);
        expect(royaltyFees.toNumber(), "royaltyFees issue").to.equal(royaltyFeesExpected.toNumber());

    });


    // it("ListNFT in the marketplace", async function() {
    //     let owner = ads[0];
    //     let marketplaceAd = ads[1];

    //     expect(await ebookNFT.balanceOf(owner.address, 1)).to.equal(1000);
    // });


   
});
