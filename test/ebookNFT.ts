//import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";
import { Marketplace__factory, RentContract__factory } from "../typechain-types";
import { time } from "@nomicfoundation/hardhat-network-helpers";

//@ts-check

async function main() {
    
}

describe("ebookNFT & Marketplace tests", async function () {

    // create a ebookNFT variable
    let ebookNFT: Contract;
    let marketplace: Contract;
    let rentContract: Contract;

    let Marketplace: Marketplace__factory;
    let RentContract: RentContract__factory;
    //let EbookNFT: EbookNFT__factory;

    let ads: any[] = [];

    let owner: any;
    let marketplaceAd: any;
    let author: any;
    let renter: any;
    let tenant: any;

    this.beforeAll(async function() {
        // This is executed before each test
        // Deploying the smart contract
        
        const EbookNFT = await ethers.getContractFactory("ebookNFT");
        ebookNFT = await EbookNFT.deploy();
       
        Marketplace = await ethers.getContractFactory("Marketplace");
        
        RentContract = await ethers.getContractFactory("rentContract") as RentContract__factory;
        
        ads = await ethers.getSigners();

        owner = ads[0];
        marketplaceAd = ads[1];
        author = ads[2];

        renter = ads[3];
        tenant = ads[4];
    })

    

    it("NFT is minted successfully", async function() {
        
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

        //console.log(marketplace.address);
        const ebookNFTAddress = ebookNFT.address;
        
        marketplace  = await Marketplace.deploy(ebookNFTAddress, marketplaceAd.address);
        const marketplaceAddress = marketplace.address;
        const tx2 = await ebookNFT.connect(owner).setApprovalForAll(marketplaceAddress, true);

        const tx3 = await ebookNFT.connect(renter).setApprovalForAll(marketplaceAddress, true);

        //console.log(await ebookNFT.isApprovedForAll(owner.address, marketplace.address ));
        //give approval to marketplace from owner
        expect(await ebookNFT.isApprovedForAll(owner.address, marketplaceAddress ), "owner approval failed").to.equal(true);

        //give approval to marketplace from renter
        expect(await ebookNFT.isApprovedForAll(renter.address, marketplaceAddress ), "renter approval failed").to.equal(true);
    })

    it("NFT is list in marketplace successfully", async function() {
        // let owner = ads[0];
        // let marketplaceAd = ads[1];

        const tx3 = await marketplace.connect(owner).listNft(1, 1, 10000000000000);
        const tx4 = await marketplace.connect(owner).listNft(1, 1, 10000000000000);
        let nbOffer = await marketplace.nbOffer();
        expect(nbOffer.toNumber()).to.equal(2);
        let balance = await ebookNFT.balanceOf(owner.address, 1);
        expect(balance.toNumber()).to.equal(998);
    });

    it("Offer in marketplace cancelled successfully", async function() {
        // let owner = ads[0];
        // let marketplaceAd = ads[1];

        const tx4 = await marketplace.connect(owner).cancelBuyOffer(1);
        const tx5 = await marketplace.connect(owner).cancelBuyOffer(1);
        let nbOffer = await marketplace.nbOffer();
        expect(nbOffer.toNumber()).to.equal(0);

        let balance = await ebookNFT.balanceOf(owner.address, 1);
        expect(balance.toNumber()).to.equal(1000);

    });

    it("Buy an NFT from the marketplace with one offer only successfully", async function() {
        // let owner = ads[0];
        // let marketplaceAd = ads[1];
        // let author = ads[2];
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

        const tx5 = await marketplace.connect(buyer).buyNFT(1, 1, {value: 10000000000000} );

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

    it("Buy 2 NFTs from the marketplace with multiples offers successfully", async function() {
        // let owner = ads[0];
        // let marketplaceAd = ads[1];
        // let author = ads[2];
        let buyer = ads[4];
        
        const tx3 = await marketplace.connect(owner).listNft(1, 1, 10000000000000);
        const tx4 = await marketplace.connect(owner).listNft(1, 1, 10000000000000);
        const tx6 = await marketplace.connect(owner).listNft(1, 1, 10000000000000);
        let nbOffer = await marketplace.nbOffer();
        expect(nbOffer.toNumber()).to.equal(3);

        let balance = await ebookNFT.balanceOf(owner.address, 1);
        expect(balance.toNumber(), "list ok").to.equal(996);

        balance = await ebookNFT.balanceOf(buyer.address, 1);
        expect(balance.toNumber()).to.equal(0);

        //console.log(await marketplace.marketItem(0));
        //console.log(await marketplaceAd.getBalance());
        let marketplaceAdBalanceBefore = await marketplaceAd.getBalance();
        let ownerBalanceBefore = await owner.getBalance();
        let buyerBalanceBefore = await buyer.getBalance();
        let authorBalanceBefore = await author.getBalance();

        const tx5 = await marketplace.connect(buyer).buyNFT(1, 1, {value: 10000000000000} );
        const tx7 = await marketplace.connect(buyer).buyNFT(1, 1, {value: 10000000000000} );

        let ownerBalanceAfter = await owner.getBalance();
        let marketplaceAdBalanceAfter = await marketplaceAd.getBalance();

        // Check the marketplace fees
        //console.log(marketplaceAdBalanceBefore, marketplaceAdBalanceAfter, marketplaceAdBalanceAfter.sub(marketplaceAdBalanceBefore));
        let marketplaceFees = marketplaceAdBalanceAfter.sub(marketplaceAdBalanceBefore);
        
        let fee = ethers.BigNumber.from(20000000000000 * 0.02);
        // 10% royalties + 2% marketplace fees
        expect(marketplaceFees.toNumber(), "marketplaceFees issue").to.equal(fee.toNumber());

        let balanceAfter = await ebookNFT.balanceOf(buyer.address, 1);
        expect(balanceAfter.toNumber()).to.equal(2);
        let buyerBalanceAfter = await buyer.getBalance();
        let authorBalanceAfter = await author.getBalance();

        nbOffer = await marketplace.nbOffer();
        expect(nbOffer.toNumber()).to.equal(1);

        //Check the owner fees
        //console.log(ownerBalanceBefore, ownerBalanceAfter, ownerBalanceAfter.sub(ownerBalanceBefore));
        let ownerFees = ownerBalanceAfter.sub(ownerBalanceBefore);

        let ownerFeesExpected = ethers.BigNumber.from(20000000000000 * (1 - 0.1 - 0.02));
        // 10% royalties + 2% marketplace fees
        expect(ownerFees.toNumber(), "ownerFees issue").to.equal(ownerFeesExpected.toNumber());

        //console.log(buyerBalanceBefore, buyerBalanceAfter, buyerBalanceBefore.sub(buyerBalanceAfter));
        //console.log(authorBalanceBefore, authorBalanceAfter, authorBalanceAfter.sub(authorBalanceBefore));

        let buyerFees = buyerBalanceBefore - buyerBalanceAfter;
        //Buyer balance after buying has to be lower than before
        expect(buyerFees, "Buyer balance issue").to.gt(10000000000000);

        //Check the royalties
        let royaltyFeesExpected = ethers.BigNumber.from(20000000000000 * 0.1);
        let royaltyFees = authorBalanceAfter.sub(authorBalanceBefore);
        expect(royaltyFees.toNumber(), "royaltyFees issue").to.equal(royaltyFeesExpected.toNumber());

    });

    /*it("rent Contract Standalone", async function() {
        let marketplace = ads[0];
        let renter = ads[1];
        let tenant = ads[2];

        let nftId = 1;
    
        
        //expect(await ebookNFT.isApprovedForAll(lender.address, marketplace.address )).to.equal(true);
        //address _nftContract, uint256 _nftId, uint256 _end, uint256 _price
        rentContract = await RentContract.connect(marketplace).deploy(ebookNFT.address, nftId, renter.address, tenant.address, 100 );
        
        //Give approve to the rent contract of ebookNFT
        //const tx2 = await ebookNFT.connect(marketplace).setApprovalForAll(rentContract.address, true);
        //expect(await ebookNFT.isApprovedForAll(marketplace.address, rentContract.address )).to.equal(true);

        // let marketplaceBalanceBefore = await marketplace.getBalance();

        // const tx4 = await rentContract.connect(marketplace).startRent();
        // let balance = await ebookNFT.balanceOf(rentContract.address, nftId);
        // expect(balance.toNumber()).to.equal(0);

        // let marketplaceBalanceAfter = await marketplace.getBalance();
        // expect(marketplaceBalanceAfter.sub(marketplaceBalanceBefore) == -1);


        // let renterBalanceBefore = await ebookNFT.balanceOf(renter.address, nftId);
        // const tx5 =  await expect(rentContract.connect(renter).stopRent()).to.be.revertedWith('Renting period not over');

        // // advance time by one hour and mine a new block
        // await time.increase(100);
            
        // renterBalanceBefore = await ebookNFT.balanceOf(renter.address, nftId);
        // const tx6 = await rentContract.connect(renter).stopRent();
        // balance = await ebookNFT.balanceOf(renter.address, nftId);
        // expect(balance.sub(renterBalanceBefore) == 1);

    });*/

    it("Rent Contract List in Marketplace", async function() {
        // let renter = ads[0];
        // let marketplaceAd = ads[1];
        // let tenant = ads[2];

        let nftId = 1;
        const ebookNFTAddress = ebookNFT.address;
        const marketplaceAddress = marketplace.address;

        // list rent, rent and cancel rent offer from marketplace
        let balanceBefore = await ebookNFT.balanceOf(renter.address, 1);
        let balanceMrkBefore = await ebookNFT.balanceOf(marketplaceAddress, 1);
        // listNftForRent(uint256 _nftId, uint256 _price, uint256 _end)
        const tx3 = await marketplace.connect(renter).listNftForRent(1, 10000000000000, 100);
        let nbOffer = await marketplace.nbOfferRent();
        expect(nbOffer.toNumber()).to.equal(1);

        let balance = await ebookNFT.balanceOf(renter.address, 1);
        expect(balance.sub(balanceBefore) == -1);

        let balanceMrk = await ebookNFT.balanceOf(marketplaceAddress, 1);
        expect(balanceMrk.sub(balanceMrkBefore) == 1);
    });

    let rentingContractAd: any;
    it("Rent Contract Rent Marketplace", async function() {
        // let marketplaceAd = ads[0];
        // let renter = ads[1];
        // let author = ads[2];
        // let tenant = ads[3];
        
        // let nftId = 1;
        const ebookNFTAddress = await ebookNFT.address;
        const marketplaceAddress = await marketplace.address;

        let nbOffer = await marketplace.nbOfferRent();
        expect(nbOffer.toNumber(), "Marketplace has no offer").to.equal(1);

        let balanceMrk = await ebookNFT.balanceOf(marketplaceAddress, 1);
        expect(balanceMrk, "Marketplace has no NFT").to.be.gte(1);
        
        //console.log(await marketplace.marketItem(0));
        //console.log(await marketplaceAd.getBalance());
        let marketplaceAdBalanceBefore = await marketplaceAd.getBalance();
        let renterBalanceBefore = await renter.getBalance();
        let tenantBalanceBefore = await tenant.getBalance();
        let authorBalanceBefore = await author.getBalance();

        //const tx2 = await ebookNFT.connect(marketplaceAd).setApprovalForAll(rentContract.address, true);
        //expect(await ebookNFT.isApprovedForAll(marketplaceAd, rentContract.address )).to.equal(true);

        //function rentNFT(uint256 _offerId) public payable {
        const tx5 = await marketplace.connect(tenant).rentNFT(1, {value: 10000000000000} );
        const receipt = await tx5.wait();
        //console.log(receipt.events[2]);
        rentingContractAd = receipt.events[2].address;
        let balanceRC = await ebookNFT.balanceOf(rentingContractAd, 1);
        expect(balanceRC, "ok").to.be.gte(1);

        let renterBalanceAfter = await renter.getBalance();
        let marketplaceAdBalanceAfter = await marketplaceAd.getBalance();

        // Check the marketplace fees
        //console.log(marketplaceAdBalanceBefore, marketplaceAdBalanceAfter, marketplaceAdBalanceAfter.sub(marketplaceAdBalanceBefore));
        let marketplaceFees = marketplaceAdBalanceAfter.sub(marketplaceAdBalanceBefore);
        //console.log(marketplaceAdBalanceBefore, marketplaceAdBalanceAfter);
        let fee = ethers.BigNumber.from(10000000000000 * 0.02);
        // 10% royalties + 2% marketplace fees
        expect(marketplaceFees.toNumber(), "marketplaceFees issue").to.equal(fee.toNumber());

        let tenantBalanceAfter = await tenant.getBalance();
        let authorBalanceAfter = await author.getBalance();

        nbOffer = await marketplace.nbOfferRent();
        expect(nbOffer.toNumber(), "nbOfferRent no good").to.equal(0);

        //Check the owner fees
        //console.log(ownerBalanceBefore, ownerBalanceAfter, ownerBalanceAfter.sub(ownerBalanceBefore));
        let renterFees = renterBalanceAfter.sub(renterBalanceBefore);

        let renterFeesExpected = ethers.BigNumber.from(10000000000000 * (1 - 0.1 - 0.02));
        // 10% royalties + 2% marketplace fees
        expect(renterFees.toNumber(), "renterFees issue").to.equal(renterFeesExpected.toNumber());

        //console.log(buyerBalanceBefore, buyerBalanceAfter, buyerBalanceBefore.sub(buyerBalanceAfter));
        //console.log(authorBalanceBefore, authorBalanceAfter, authorBalanceAfter.sub(authorBalanceBefore));

        let tenantFees = tenantBalanceBefore - tenantBalanceAfter;
        //tenant balance after buying has to be lower than before
        expect(tenantFees, "Tenant balance issue").to.gt(10000000000000);

        //Check the royalties
        let royaltyFeesExpected = ethers.BigNumber.from(10000000000000 * 0.1);
        let royaltyFees = authorBalanceAfter.sub(authorBalanceBefore);
        expect(royaltyFees.toNumber(), "royaltyFees issue").to.equal(royaltyFeesExpected.toNumber());

    });

    it("Rent Contract Stop", async function() {
        let nftId = 1;

        let renterBalanceBefore = await ebookNFT.balanceOf(renter.address, nftId);

        const rentingContract = await RentContract.attach(rentingContractAd);
        const tx5 =  await expect(rentingContract.connect(renter).stopRent()).to.be.revertedWith('Renting period not over');

        // advance time by one hour and mine a new block
        await time.increase(100);
        
        renterBalanceBefore = await ebookNFT.balanceOf(renter.address, nftId);
        const tx6 = await rentingContract.connect(renter).stopRent();
        let balance = await ebookNFT.balanceOf(renter.address, nftId);
        expect(balance.sub(renterBalanceBefore) == 1);
    });

    it("Rent Contract Stop", async function() {
        let nftId = 1;
        const tx3 = await marketplace.connect(renter).listNftForRent(nftId, 10000000000000, 100);
        let renterBalanceBefore = await ebookNFT.balanceOf(renter.address, nftId);

        const tx4 = await expect(marketplace.connect(tenant).cancelRentOffer(1)).to.be.revertedWith('You are not the renter');
        const tx5 = marketplace.connect(tenant).cancelRentOffer(1);
        
        let balance = await ebookNFT.balanceOf(renter.address, nftId);
        expect(balance.sub(renterBalanceBefore) == 1);
        
    });
    // it("ListNFT in the marketplace", async function() {
    //     let owner = ads[0];
    //     let marketplaceAd = ads[1];

    //     expect(await ebookNFT.balanceOf(owner.address, 1)).to.equal(1000);
    // });


   
});
