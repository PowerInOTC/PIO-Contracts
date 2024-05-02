const { expect } = require("chai");
const { ethers } = require("hardhat");
const {assert} = require('assert');

describe("PionerV1Open Contract", function () {
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
    PionerV1Oracle = await ethers.getContractFactory("PionerV1Oracle");
    pionerV1Oracle  = await PionerV1Oracle.deploy(pionerV1.target, pionerV1Compliance.target);
    PionerV1Warper = await ethers.getContractFactory("PionerV1Warper");
    pionerV1Warper = await PionerV1Warper.deploy(pionerV1.target, pionerV1Compliance.target, pionerV1Open.target ,pionerV1Close.target ,pionerV1Default.target, pionerV1Oracle.target );
    
    await pionerV1.connect(owner).setContactAddress(pionerV1Open.target,pionerV1Close.target,pionerV1Default.target,pionerV1Stable.target,pionerV1Compliance.target,pionerV1Oracle.target, pionerV1Warper.target );
    const mintAmount = ethers.parseUnits("10000", 18);
    await fakeUSD.connect(addr1).mint(mintAmount);
    await fakeUSD.connect(addr1).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr1).deposit(ethers.parseUnits("10000", 18), 1, addr1);
    await fakeUSD.connect(addr2).mint(mintAmount);
    await fakeUSD.connect(addr2).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr2).deposit(ethers.parseUnits("10000", 18), 1, addr2);
    await fakeUSD.connect(addr3).mint(mintAmount);
    await fakeUSD.connect(addr3).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr3).deposit(ethers.parseUnits("10000", 18), 1, addr3);

    _x = "0x20568a84796e6ade0446adfd2d8c4bba2c798c2af0e8375cc3b734f71b17f5fd" ;
    _parity = 0 ;
    _maxConfidence = ethers.parseUnits("1", 18) ;
    _asset1 = "0x757373746f636b2e6161706c0000000000000000000000000000000000000000" ;
    _asset2 = "0x66782e6575727573640000000000000000000000000000000000000000000000" ;
    _maxDelay = 600 ;
    _imA = ethers.parseUnits("10", 16) ;
    _imB = ethers.parseUnits("10", 16) ;
    _dfA = ethers.parseUnits("25", 15) ;
    _dfB = ethers.parseUnits("25", 15) ;
    _expiryA = 60 ;
    _expiryB = 60 ;
    _timeLockA = 1440 * 30 * 3 ;
    _timeLockB = 1440 * 30 * 3 ;
    _cType = 1 ;

    await pionerV1Oracle.deployBOraclePion( _x, _parity,_maxConfidence,_asset1,_asset2,_maxDelay,_imA,_imB,_dfA,_dfB,_expiryA,_expiryB,_timeLockA,_timeLockB,_cType );
  });

  it("Open Quote Long", async function () {
    const e18 = BigInt(ethers.parseUnits("1", 18));
    const initialBalanceAddr1 = await pionerV1.getBalance(addr1);
    const initialBalanceAddr2 = await pionerV1.getBalance(addr2);
    const oracleLength = await pionerV1.getBOracleLength();

    const _issLong = true;
    const _bOracleId = oracleLength - BigInt(1);
    const _price = ethers.parseUnits("50", 18);
    const _qty = ethers.parseUnits("10", 18);
    const _interestRate = ethers.parseUnits("50", 16); 
    const _isAPayingAPR = true;
    const _frontEnd = owner.address;
    const _affiliate = owner.address;

    const IM = ethers.parseUnits("10", 16);
    const DF = ethers.parseUnits("25", 15);

    const expectedAmountTaken = BigInt(_qty) * BigInt(_price) * BigInt(BigInt(IM) + BigInt(DF)) / e18 / e18;

    await pionerV1Open.connect(addr1).openQuote(_issLong, _bOracleId, _price, _qty, _interestRate, _isAPayingAPR, _frontEnd, _affiliate);

    const _acceptPrice = ethers.parseUnits("50", 18);
    const _backendAffiliate = owner.address;

    await pionerV1Open.connect(addr2).acceptQuote(_bOracleId, _acceptPrice, _backendAffiliate);

    const finalBalanceAddr1 = await pionerV1.getBalance(addr1);
    const finalBalanceAddr2 = await pionerV1.getBalance(addr2);

    const actualAmountTakenAddr1 = BigInt(initialBalanceAddr1) - BigInt(finalBalanceAddr1);
    const actualAmountTakenAddr2 = BigInt(initialBalanceAddr2) - BigInt(finalBalanceAddr2);

    expect(actualAmountTakenAddr1).to.equal(expectedAmountTaken, "Amount taken from addr1 does not match expected value");
    expect(actualAmountTakenAddr2).to.equal(expectedAmountTaken, "Amount taken from addr2 does not match expected value");
});

it("Cancel Quote", async function () {

    const e18 = BigInt(ethers.parseUnits("1", 18));
    const initialBalanceAddr1 = await pionerV1.getBalance(addr1);
    const initialBalanceAddr2 = await pionerV1.getBalance(addr2);
    const oracleLength = await pionerV1.getBOracleLength();

    const _issLong = true;
    const _bOracleId = oracleLength - BigInt(1);
    const _price = ethers.parseUnits("50", 18);
    const _qty = ethers.parseUnits("10", 18);
    const _interestRate = ethers.parseUnits("50", 16); 
    const _isAPayingAPR = true;
    const _frontEnd = owner.address;
    const _affiliate = owner.address;

    const IM = ethers.parseUnits("10", 16);
    const DF = ethers.parseUnits("25", 15);

    const expectedAmountTaken = BigInt(0);

    await pionerV1Open.connect(addr1).openQuote(_issLong, _bOracleId, _price, _qty, _interestRate, _isAPayingAPR, _frontEnd, _affiliate);

    const bContractLength = await pionerV1.getBOracleLength();
    await pionerV1Open.connect(addr1).cancelOpenQuote(bContractLength - BigInt(1));

    const _acceptPrice = ethers.parseUnits("50", 18);
    const _backendAffiliate = owner.address;

    await pionerV1Open.connect(addr2).acceptQuote(_bOracleId, _acceptPrice, _backendAffiliate);

    const finalBalanceAddr1 = await pionerV1.getBalance(addr1);
    const finalBalanceAddr2 = await pionerV1.getBalance(addr2);

    const actualAmountTakenAddr1 = BigInt(initialBalanceAddr1) - BigInt(finalBalanceAddr1);
    const actualAmountTakenAddr2 = BigInt(initialBalanceAddr2) - BigInt(finalBalanceAddr2);

    expect(actualAmountTakenAddr1).to.equal(expectedAmountTaken, "Amount taken from addr1 does not match expected value");
    expect(actualAmountTakenAddr2).to.equal(expectedAmountTaken, "Amount taken from addr2 does not match expected value");

});

it("Double accept quote in the same block", async function () {
    const e18 = BigInt(ethers.parseUnits("1", 18));
    const initialBalanceAddr1 = await pionerV1.getBalance(addr1);
    const initialBalanceAddr2 = await pionerV1.getBalance(addr2);
    const initialBalanceAddr3 = await pionerV1.getBalance(addr3);
    const oracleLength = await pionerV1.getBOracleLength();

    const _issLong = true;
    const _bOracleId = oracleLength - BigInt(1);
    const _price = ethers.parseUnits("50", 18);
    const _qty = ethers.parseUnits("10", 18);
    const _interestRate = ethers.parseUnits("50", 16); 
    const _isAPayingAPR = true;
    const _frontEnd = owner.address;
    const _affiliate = owner.address;

    const IM = ethers.parseUnits("10", 16);
    const DF = ethers.parseUnits("25", 15);

    const expectedAmountTaken = BigInt(_qty) * BigInt(_price) * BigInt(BigInt(IM) + BigInt(DF)) / e18 / e18;

    await pionerV1Open.connect(addr1).openQuote(_issLong, _bOracleId, _price, _qty, _interestRate, _isAPayingAPR, _frontEnd, _affiliate);

    const _acceptPrice = ethers.parseUnits("50", 18);
    const _acceptPrice2 = ethers.parseUnits("51", 18);
    const _backendAffiliate = owner.address;

    await pionerV1Open.connect(addr2).acceptQuote(_bOracleId, _acceptPrice, _backendAffiliate);
    await pionerV1Open.connect(addr3).acceptQuote(_bOracleId, _acceptPrice2, _backendAffiliate);

    const finalBalanceAddr1 = await pionerV1.getBalance(addr1);
    const finalBalanceAddr2 = await pionerV1.getBalance(addr2);
    const finalBalanceAddr3 = await pionerV1.getBalance(addr3);

    const actualAmountTakenAddr1 = BigInt(initialBalanceAddr1) - BigInt(finalBalanceAddr1);
    const actualAmountTakenAddr2 = BigInt(initialBalanceAddr2) - BigInt(finalBalanceAddr2);
    const actualAmountTakenAddr3 = BigInt(initialBalanceAddr3) - BigInt(finalBalanceAddr3);

    expect(actualAmountTakenAddr1).to.equal(expectedAmountTaken, "Amount taken from addr1 does not match expected value");
    expect(actualAmountTakenAddr2).to.equal(expectedAmountTaken, "Amount taken from addr2 does not match expected value");
    expect(actualAmountTakenAddr3).to.equal(BigInt(0), "Amount taken from addr2 does not match expected value");

    console.log
});



});

