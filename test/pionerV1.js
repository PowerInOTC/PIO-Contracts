const { expect } = require("chai");
const { ethers } = require("hardhat");
const {assert} = require('assert');

describe("PionerV1 Contract", function () {
  let FakeUSD, fakeUSD, PionerV1, pionerV1;
  let owner, addr1, addr2, addr3, balances, owed1, owed2;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const PionerV1Utils = await ethers.getContractFactory("PionerV1Utils"); // Initialize PionerV1Utils
    const pionerV1Utils = await PionerV1Utils.deploy();
    
    FakeUSD = await ethers.getContractFactory("fakeUSD");
    fakeUSD = await FakeUSD.deploy();
    PionerV1 = await ethers.getContractFactory("PionerV1", {
      libraries: {
        PionerV1Utils: pionerV1Utils.target,
      },
    });
        pionerV1 = await PionerV1.deploy(
      fakeUSD.target,
      ethers.parseUnits("25", 18),
      ethers.parseUnits("3", 17),
      ethers.parseUnits("2", 17),
      ethers.parseUnits("1", 17),
      ethers.parseUnits("4", 17),
      ethers.parseUnits("2", 17),
      20,
      20,
      100,
      300,
      owner.address,
      owner.address
    );
    PionerV1Compliance = await ethers.getContractFactory("PionerV1Compliance");
    pionerV1Compliance = await PionerV1Compliance.deploy(pionerV1.target);
    PionerV1Open = await ethers.getContractFactory("PionerV1Open", {libraries: {PionerV1Utils: pionerV1Utils.target,},});
    pionerV1Open = await PionerV1Open.deploy(pionerV1.target, pionerV1Compliance.target);
    PionerV1Close = await ethers.getContractFactory("PionerV1Close", {libraries: {PionerV1Utils: pionerV1Utils.target,},});
    pionerV1Close = await PionerV1Close.deploy(pionerV1.target, pionerV1Compliance.target);
    PionerV1Default = await ethers.getContractFactory("PionerV1Default", {libraries: {PionerV1Utils: pionerV1Utils.target,},});
    pionerV1Default = await PionerV1Default.deploy(pionerV1.target, pionerV1Compliance.target);
    PionerV1Stable = await ethers.getContractFactory("PionerV1Stable");
    pionerV1Stable = await PionerV1Stable.deploy(pionerV1.target, pionerV1Compliance.target);
    
    await pionerV1.connect(owner).setContactAddress(pionerV1Open.target,pionerV1Close.target,pionerV1Default.target,pionerV1Stable.target,pionerV1Compliance.target);
    const mintAmount = ethers.parseUnits("10000", 18);
    await fakeUSD.mint(addr1.address, mintAmount);
    await fakeUSD.connect(addr1).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr1).firstDeposit(ethers.parseUnits("10000", 18), 9, addr1);
    await fakeUSD.mint(addr2.address, mintAmount);
    await fakeUSD.connect(addr2).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr2).firstDeposit(ethers.parseUnits("10000", 18), 9, addr2);
    await fakeUSD.mint(addr3.address, mintAmount);
    await fakeUSD.connect(addr3).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr3).firstDeposit(ethers.parseUnits("10000", 18), 9, addr3);
  });
/*
  it("Deposit and withdraw tests", async function () {
    const mintAmount = ethers.parseUnits("10000", 18);

    expect(await fakeUSD.allowance(addr1.address, pionerV1.target)).to.equal(mintAmount);
    await pionerV1.connect(addr1).deposit(mintAmount);

    let tokenBalance = await fakeUSD.balanceOf(addr1.address);
    let userBalance = await pionerV1.getBalance(addr1.address);
    expect(tokenBalance).to.equal(0);
    expect(userBalance).to.equal(mintAmount);
    
    await pionerV1.connect(addr1).initiateWithdraw(mintAmount);
    //test time lock
    await expect(pionerV1.connect(addr1).withdraw(mintAmount)).to.be.revertedWith("Too Early");
    // pass 5 minutes
    
    await network.provider.send("evm_increaseTime", [301]);
    await network.provider.send("evm_mine");
    await pionerV1.connect(addr1).withdraw(mintAmount);
    tokenBalance = await fakeUSD.balanceOf(addr1.address);
    userBalance = await pionerV1.getBalance(addr1.address);
    expect(tokenBalance).to.equal(mintAmount);
    expect(userBalance).to.equal(0);

    await fakeUSD.connect(addr1).approve(pionerV1.target, mintAmount);
    await pionerV1.connect(addr1).deposit(mintAmount);
    await pionerV1.connect(addr1).initiateWithdraw(mintAmount);
    await pionerV1.connect(addr1).cancelWithdraw(mintAmount);
    tokenBalance = await fakeUSD.balanceOf(addr1.address);
    userBalance = await pionerV1.getBalance(addr1.address);
    expect(tokenBalance).to.equal(0);
    expect(userBalance).to.equal(mintAmount);

  });
*/
  it("Tests Long", async function () {

    await pionerV1Open.connect(addr1).deployBOracle(
      "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C", "0x2167ece6ee3201b7b61f4cdc17bf2e874ca6ad850c390ba2c5a76d703a1b8cd2", "0xc2dec53d44e1fcc69b96f72c2d0a73080c328a0c6ac74bac9f575e7afbf6884b",
      10, 2, ethers.parseUnits("10", 16), ethers.parseUnits("10", 16), ethers.parseUnits("25", 15), ethers.parseUnits("25", 15),
      60, 1440 * 30 * 3, 1440 * 30 * 3, 1440 * 30 * 3 , 0); 
    await pionerV1Open.connect(addr1).openQuote( true,0, ethers.parseUnits("50", 18), ethers.parseUnits("10", 18), ethers.parseUnits("50", 16),
      true, owner,owner ); 

    await pionerV1Open.connect(addr2).acceptQuote(0, ethers.parseUnits("50", 18), owner); 
    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}`);
    const block = await ethers.provider.getBlock('latest');
    await pionerV1.connect(addr1).updatePriceDummy(1, ethers.parseUnits("45", 18), block.timestamp);
    
    await pionerV1Close.connect(addr1).openCloseQuote( [0], [ethers.parseUnits("55000", 18)], [ethers.parseUnits("10", 18)], [0], [block.timestamp + 300]);
    await pionerV1Close.connect(addr2).acceptCloseQuote( 0, 0,ethers.parseUnits("10", 18));

    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    owed1 = await pionerV1.getOwedAmount(addr1, addr2);
    owed2 = await pionerV1.getOwedAmount(addr2, addr1);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}, Owed : ${owed1}, ${owed2}`);
    console.log('Long Tests Pass');
    
  });

  it("Tests Short", async function () {

    await pionerV1Open.connect(addr1).deployBOracle(
      "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C", "0x2167ece6ee3201b7b61f4cdc17bf2e874ca6ad850c390ba2c5a76d703a1b8cd2", "0xc2dec53d44e1fcc69b96f72c2d0a73080c328a0c6ac74bac9f575e7afbf6884b",
      10, 2, ethers.parseUnits("10", 16), ethers.parseUnits("10", 16), ethers.parseUnits("25", 15), ethers.parseUnits("25", 15),
      60, 1440 * 30 * 3, 1440 * 30 * 3, 1440 * 30 * 3 , 0); 
    await pionerV1Open.connect(addr1).openQuote( false,0, ethers.parseUnits("50", 18), ethers.parseUnits("10", 18), ethers.parseUnits("50", 16),
      true, owner,owner ); 
    await pionerV1Open.connect(addr2).acceptQuote(0, ethers.parseUnits("50", 18), owner); 
    const block = await ethers.provider.getBlock('latest');
    await pionerV1Close.connect(addr1).openCloseQuote( [0], [ethers.parseUnits("55", 18)], [ethers.parseUnits("10", 18)], [0], [block.timestamp + 300]);
    await pionerV1.connect(addr1).updatePriceDummy(0, ethers.parseUnits("54", 18), block.timestamp);
    await expect(
      pionerV1Close.connect(addr2).acceptCloseQuote(0, 0, ethers.parseUnits("10", 18))
    ).to.be.revertedWith("Close29");
    
    await pionerV1.connect(addr1).updatePriceDummy(0, ethers.parseUnits("56001", 18), block.timestamp);
    await pionerV1Close.connect(addr1).openCloseQuote( [0], [ethers.parseUnits("56000", 18)], [ethers.parseUnits("10", 18)], [0], [block.timestamp + 300]);
    await pionerV1Close.connect(addr2).acceptCloseQuote( 1, 0,ethers.parseUnits("10", 18));

    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    owed1 = await pionerV1.getOwedAmount(addr1, addr2);
    owed2 = await pionerV1.getOwedAmount(addr2, addr1);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}, Owed : ${owed1}, ${owed2}`);
    console.log('Short Tests Pass');
    
  }); /*
  it("Tests Market Close Long", async function () {

    await pionerV1Open.connect(addr1).deployBOracle(
      "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C", "0x2167ece6ee3201b7b61f4cdc17bf2e874ca6ad850c390ba2c5a76d703a1b8cd2", "0xc2dec53d44e1fcc69b96f72c2d0a73080c328a0c6ac74bac9f575e7afbf6884b",
      10, 2, ethers.parseUnits("10", 16), ethers.parseUnits("10", 16), ethers.parseUnits("25", 15), ethers.parseUnits("25", 15),
      60, 1440 * 30 * 3, 1440 * 30 * 3, 1440 * 30 * 3 , 0); 
    await pionerV1Open.connect(addr1).openQuote( true,0, ethers.parseUnits("50", 18), ethers.parseUnits("10", 18), ethers.parseUnits("50", 16),
      true, owner,owner ); 

    await pionerV1Open.connect(addr2).acceptQuote(0, ethers.parseUnits("50", 18), owner); 
    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}`);
    
    const block = await ethers.provider.getBlock('latest');
    await pionerV1Close.connect(addr1).openCloseQuote( [0], [ethers.parseUnits("55", 18)], [ethers.parseUnits("10", 18)], [0], [block.timestamp + 3000]);
    await pionerV1.connect(addr1).updatePriceDummy(0, ethers.parseUnits("551", 17), block.timestamp);
    await network.provider.send("evm_increaseTime", [21]);
    await network.provider.send("evm_mine");
    await pionerV1Close.connect(addr1).closeMarket(0, 0);

    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    owed1 = await pionerV1.getOwedAmount(addr1, addr2);
    owed2 = await pionerV1.getOwedAmount(addr2, addr1);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}, Owed : ${owed1}, ${owed2}`);
    console.log('Market Close Tests Pass');
    
  }); */
/*
  it("Tests Expiration Close Long", async function () {

    await pionerV1Open.connect(addr1).deployBOracle(
      "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C", "0x2167ece6ee3201b7b61f4cdc17bf2e874ca6ad850c390ba2c5a76d703a1b8cd2", "0xc2dec53d44e1fcc69b96f72c2d0a73080c328a0c6ac74bac9f575e7afbf6884b",
      10, 2, ethers.parseUnits("10", 16), ethers.parseUnits("10", 16), ethers.parseUnits("25", 15), ethers.parseUnits("25", 15),
      60, 1440 * 30 * 3, 1440 * 30 * 3, 1440 * 30 * 3 , 0); 
    await pionerV1Open.connect(addr1).openQuote( true,0, ethers.parseUnits("50", 18), ethers.parseUnits("10", 18), ethers.parseUnits("50", 16),
      true, owner,owner ); 

    await pionerV1Open.connect(addr2).acceptQuote(0, ethers.parseUnits("50", 18), owner); 
    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}`);
    
    const block = await ethers.provider.getBlock('latest');
    await pionerV1.connect(addr1).updatePriceDummy(0, ethers.parseUnits("45", 18), block.timestamp);
    await network.provider.send("evm_increaseTime", [1440 * 30 * 3 + 1]);
    await network.provider.send("evm_mine");
    await pionerV1Close.connect(addr1).expirateBContract(0);

    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    owed1 = await pionerV1.getOwedAmount(addr1, addr2);
    owed2 = await pionerV1.getOwedAmount(addr2, addr1);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}, Owed : ${owed1}, ${owed2}`);
    console.log('Expiration Tests Pass');
    
  }); */
  it("Tests Settlement  ", async function () {

    await pionerV1Open.connect(addr1).deployBOracle(
      "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C", "0x2167ece6ee3201b7b61f4cdc17bf2e874ca6ad850c390ba2c5a76d703a1b8cd2", "0xc2dec53d44e1fcc69b96f72c2d0a73080c328a0c6ac74bac9f575e7afbf6884b",
      10, 2, ethers.parseUnits("10", 16), ethers.parseUnits("10", 16), ethers.parseUnits("25", 15), ethers.parseUnits("25", 15),
      60, 1440 * 30 * 3, 1440 * 30 * 3, 1440 * 30 * 3 , 0); 
    await pionerV1Open.connect(addr1).openQuote( true,0, ethers.parseUnits("50", 18), ethers.parseUnits("10", 18), ethers.parseUnits("50", 16),
      true, owner,owner ); 

    await pionerV1Open.connect(addr2).acceptQuote(0, ethers.parseUnits("50", 18), owner); 
    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}`);

    await network.provider.send("evm_increaseTime", [1440 * 30 * 3 + 1]);
    await network.provider.send("evm_mine");
    const block = await ethers.provider.getBlock('latest');
    await pionerV1.connect(addr1).updatePriceDummy(0, ethers.parseUnits("45", 18), block.timestamp);
    await pionerV1Default.connect(addr2).settleAndLiquidate(0);

    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    owed1 = await pionerV1.getOwedAmount(addr1, addr2);
    owed2 = await pionerV1.getOwedAmount(addr2, addr1);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}, Owed : ${owed1}, ${owed2}`);
    console.log('Settle Tests Pass');
    
  });

  it("Tests Defaults  ", async function () {

    await pionerV1Open.connect(addr1).deployBOracle(
      "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C", "0x2167ece6ee3201b7b61f4cdc17bf2e874ca6ad850c390ba2c5a76d703a1b8cd2", "0xc2dec53d44e1fcc69b96f72c2d0a73080c328a0c6ac74bac9f575e7afbf6884b",
      10, 2, ethers.parseUnits("10", 16), ethers.parseUnits("10", 16), ethers.parseUnits("25", 15), ethers.parseUnits("25", 15),
      60, 1440 * 30 * 3, 1440 * 30 * 3, 1440 * 30 * 3 , 0); 
    await pionerV1Open.connect(addr1).openQuote( true,0, ethers.parseUnits("50", 18), ethers.parseUnits("10", 18), ethers.parseUnits("50", 16),
      true, owner,owner ); 

    await pionerV1Open.connect(addr2).acceptQuote(0, ethers.parseUnits("50", 18), owner); 
    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}`);

    await network.provider.send("evm_increaseTime", [1440 * 30 * 3 + 1]);
    await network.provider.send("evm_mine");
    const block = await ethers.provider.getBlock('latest');
    await pionerV1.connect(addr1).updatePriceDummy(0, ethers.parseUnits("45000", 18), block.timestamp);
    await pionerV1Default.connect(addr2).settleAndLiquidate(0);

    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    owed1 = await pionerV1.getOwedAmount(addr1, addr2);
    owed2 = await pionerV1.getOwedAmount(addr2, addr1);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}, Owed : ${owed1}, ${owed2}`);
    console.log('Defaults Tests Pass');
    
  });
  
});
