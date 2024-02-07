const { expect } = require("chai");
const { ethers } = require("hardhat");
const {assert} = require('assert');

describe("PionerV1Close Contract", function () {
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

    _daiAddress = fakeUSD.target ;
    _min_notional = ethers.parseUnits("25", 18) ;
    _frontend_share = ethers.parseUnits("3", 17) ;
    _affiliation_share = ethers.parseUnits("3", 17) ;
    _hedger_share = ethers.parseUnits("5", 16) ;
    _pioner_dao_share = ethers.parseUnits("4", 17) ;
    _total_share = ethers.parseUnits("3", 17) ;
    _default_auction_period = 30 ;
    _cancel_time_buffer = 30 ;
    _max_open_positions = 100 ;
    _grace_period = 300 ; 
    _pioner_dao = owner.address ;
    _admin = owner.address ;

    PionerV1 = await ethers.getContractFactory("PionerV1", {
      libraries: {
        PionerV1Utils: pionerV1Utils.target,
      },
    });
        pionerV1 = await PionerV1.deploy(
          _daiAddress ,
          _min_notional ,
          _frontend_share ,
          _affiliation_share ,
          _hedger_share,
          _pioner_dao_share,
          _total_share,
          _default_auction_period,
          _cancel_time_buffer,
          _max_open_positions,
          _grace_period,
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

    const oracleLength = await pionerV1.getBOracleLength();

    const _issLong = false;
    const _bOracleId = oracleLength - BigInt(1);
    const _price = ethers.parseUnits("50", 18);
    const _qty = ethers.parseUnits("10", 18);
    const _interestRate = ethers.parseUnits("1", 17); 
    const _isAPayingAPR = true;
    const _frontEnd = owner.address;
    const _affiliate = owner.address;

    await pionerV1Open.connect(addr1).openQuote(_issLong, _bOracleId, _price, _qty, _interestRate, _isAPayingAPR, _frontEnd, _affiliate);

    const _acceptPrice = ethers.parseUnits("50", 18);
    const _backendAffiliate = owner.address;

    await pionerV1Open.connect(addr2).acceptQuote(_bOracleId, _acceptPrice, _backendAffiliate);
  });

  it("Default Test", async function () {
    const e18 = BigInt(ethers.parseUnits("1", 18));
    const bContractLength = await pionerV1.getBContractLength();
    const bOracleLength = await pionerV1.getBOracleLength();
    const bContractId = bContractLength - BigInt(1);
    const bOracleId = bOracleLength - BigInt(1);

    const initBalanceAddr1 = await pionerV1.getBalance(addr1);
    const initBalanceAddr2 = await pionerV1.getBalance(addr2);
    const initowedAmount1 = await pionerV1.getOwedAmount(addr1,addr2);
    const initowedAmount2 = await pionerV1.getOwedAmount(addr2,addr1);
    console.log("balances : ",BigInt(initBalanceAddr1)/BigInt(1e18),BigInt(initBalanceAddr2)/BigInt(1e18), BigInt(initowedAmount1)/BigInt(1e18), BigInt(initowedAmount2)/BigInt(1e18));

    const priceSignature = {
      appId: "8819953379267741478318858059556381531978766925841974117591953483223779600878", 
      reqId: "0x6519a45ea86634dc3f369285463f6dd822b66e9feed77ee455dea421eee599a4",
      asset1:  "0x757373746f636b2e6161706c0000000000000000000000000000000000000000",
      asset2: "0x66782e6575727573640000000000000000000000000000000000000000000000",
      lastBid: ethers.parseUnits("55100000", 17), 
      lastAsk: ethers.parseUnits("55000000", 17), 
      confidence: ethers.parseUnits("1", 18), 
      signTime: (await ethers.provider.getBlock("latest")).timestamp, 
      signature: "0x5c2bcf2be9dfb9a1f9057392aeaebd0fbc1036bec5a700425c49069b12842038", 
      owner: "0x237A6Ec18AC7D9693C06f097c0EEdc16518d7c21",
      nonce: "0x1365a32bDd33661a3282992D1C334D5aB2faaDc7"
    };
  
    await pionerV1Oracle.updatePricePion(priceSignature, bOracleId);

    await pionerV1Default.settleAndLiquidate(bContractId);

    const finalBalanceAddr1 = await pionerV1.getBalance(addr1);
    const finalBalanceAddr2 = await pionerV1.getBalance(addr2);
    const owedAmount1 = await pionerV1.getOwedAmount(addr1,addr2);
    const owedAmount2 = await pionerV1.getOwedAmount(addr2,addr1);
    console.log("balances : ",BigInt(finalBalanceAddr1)/BigInt(1e18),BigInt(finalBalanceAddr2)/BigInt(1e18), BigInt(owedAmount1)/BigInt(1e18), BigInt(owedAmount2)/BigInt(1e18));

  });

});