const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PionerV1 Contract", function () {
  let utils, pionerV1;
  let owner, addr1;
  let blockTimestampBeforeTransaction;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    // Deploy Utils contract if it's a separate contract
    // or get the instance of the utils library if it's within the PionerV1 contract
    const Utils = await ethers.getContractFactory("PionerV1Utils");
    utils = await Utils.deploy();
    
    // Deploy the PionerV1 contract or get its instance if it's already deployed
    // Simulate other necessary setups here
  });

  it("Check ir", async function () {
    // Assuming bC and _bCloseQuote represent contract states you need to setup or mock
    
    const bCPrice = ethers.parseUnits("50", 18);
    const bCloseQuotePrice = ethers.parseUnits("50", 18);
    const bCQty = ethers.parseUnits("10", 18);
    const bCInterestRate = ethers.parseUnits("10", 17);
    const bCIsAPayingAPR = false;

    const block = await ethers.provider.getBlock("latest");
    const openTime = block.timestamp - 31536000;

    const [uPnl, isNegative] = await utils.calculateuPnl(
      bCPrice, 
      bCloseQuotePrice, 
      bCQty, 
      bCInterestRate, 
      openTime, 
      bCIsAPayingAPR
    );

    const ir = await utils.calculateIr(bCInterestRate, (block.timestamp - openTime), bCPrice, bCQty);

    console.log(BigInt(ir)/BigInt(1e18));    
    console.log(isNegative, BigInt(uPnl)/BigInt(1e18));
    // want 500 * 1e18
 
  });

  it("ccheck upnl", async function () {
    // Assuming bC and _bCloseQuote represent contract states you need to setup or mock
    
    const bCPrice = ethers.parseUnits("50", 18);
    const bCloseQuotePrice = ethers.parseUnits("50", 32);
    const bCQty = ethers.parseUnits("10", 18);
    const bCInterestRate = ethers.parseUnits("0", 17);
    const bCIsAPayingAPR = true;

    const block = await ethers.provider.getBlock("latest");
    const openTime = block.timestamp - 31536000;

    const [uPnl, isNegative] = await utils.calculateuPnl(
      bCPrice, 
      bCloseQuotePrice, 
      bCQty, 
      bCInterestRate, 
      openTime, 
      bCIsAPayingAPR
    );

    const ir = await utils.calculateIr(bCInterestRate, (block.timestamp - openTime), bCPrice, bCQty);

    console.log(BigInt(ir)/BigInt(1e18));    
    console.log(isNegative, BigInt(uPnl)/BigInt(1e18));
 
  });
});
