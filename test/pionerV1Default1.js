const { expect } = require("chai");
const { ethers } = require("hardhat");
const {assert} = require('assert');

describe("PionerV1 Contract", function () {
  let FakeUSD, fakeUSD, PionerV1, pionerV1;
  let owner, addr1, addr2, addr3, balances, owed1, owed2;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const PionerV1Utils = await ethers.getContractFactory("PionerV1Utils"); 
    const pionerV1Utils = await PionerV1Utils.deploy();
    const SchnorrSECP256K1VerifierV2 = await ethers.getContractFactory("SchnorrSECP256K1VerifierV2"); 
    const schnorrSECP256K1VerifierV2 = await SchnorrSECP256K1VerifierV2.deploy();
    const MuonClientBase = await ethers.getContractFactory("MuonClientBase"); 
    const muonClientBase = await MuonClientBase.deploy();
    
    
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
    PionerV1Oracle = await ethers.getContractFactory("PionerV1Close", {libraries: {PionerV1Utils: pionerV1Utils.target,},});
    pionerV1Oracle  = await PionerV1Close.deploy(pionerV1.target, pionerV1Compliance.target);
    PionerV1Warper = await ethers.getContractFactory("PionerV1Warper");
    pionerV1Warper = await PionerV1Warper.deploy(pionerV1.target, pionerV1Compliance.target, pionerV1Open.target ,pionerV1Close.target ,pionerV1Default.target, pionerV1Oracle.target );
    
    
    await pionerV1.connect(owner).setContactAddress(pionerV1Open.target,pionerV1Close.target,pionerV1Default.target,pionerV1Stable.target,pionerV1Compliance.target,pionerV1Oracle.target, pionerV1Warper.target );
    const mintAmount = ethers.parseUnits("10000", 18);
    await fakeUSD.connect(addr1).mint(mintAmount);
    await fakeUSD.connect(addr1).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr1).deposit(ethers.parseUnits("10000", 18), 9, addr1);
    await fakeUSD.connect(addr2).mint(mintAmount);
    await fakeUSD.connect(addr2).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr2).deposit(ethers.parseUnits("10000", 18), 9, addr2);
    await fakeUSD.connect(addr3).mint(mintAmount);
    await fakeUSD.connect(addr3).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr3).deposit(ethers.parseUnits("10000", 18), 9, addr3);

  });


  /*
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
    console.log('Settlement Tests Pass');
    
  }); */

  it("Tests Defaults A ", async function () {

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
  it("Tests Defaults B ", async function () {

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
    await pionerV1.connect(addr1).updatePriceDummy(0, ethers.parseUnits("1", 15), block.timestamp);
    await pionerV1Default.connect(addr2).settleAndLiquidate(0);

    balances = await pionerV1.getBalances(addr1, addr2, addr3);
    owed1 = await pionerV1.getOwedAmount(addr1, addr2);
    owed2 = await pionerV1.getOwedAmount(addr2, addr1);
    console.log(`Balances: ${balances[0]}, ${balances[1]}, ${balances[2]}, Owed : ${owed1}, ${owed2}`);
    console.log('Defaults Tests Pass');
    
  });
});

