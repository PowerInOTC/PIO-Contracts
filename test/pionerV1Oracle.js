const { expect } = require("chai");
const { ethers } = require("hardhat");
const {assert} = require('assert');

describe("PionerV1Oracle Contract", function () {
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
    await pionerV1Compliance.connect(addr1).deposit(ethers.parseUnits("10000", 18), 9, addr1);
    await fakeUSD.connect(addr2).mint(mintAmount);
    await fakeUSD.connect(addr2).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr2).deposit(ethers.parseUnits("10000", 18), 9, addr2);
    await fakeUSD.connect(addr3).mint(mintAmount);
    await fakeUSD.connect(addr3).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance.connect(addr3).deposit(ethers.parseUnits("10000", 18), 9, addr3);

  });

  it("Deploy & Update Pion Oracle", async function () {

        // Get oracle length before deployment
    const oracleLengthBefore = await pionerV1.getBOracleLength();

    // Deploy Oracle
    _x = 1234 ;
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
    _cType = 0 ;

    await pionerV1Oracle.deployBOraclePion( _x, _parity,_maxConfidence,_asset1,_asset2,_maxDelay,_imA,_imB,_dfA,_dfB,_expiryA,_expiryB,_timeLockA,_timeLockB,_cType );

    // Calculate new oracle's id assuming it's the last one added
    const newOracleId = oracleLengthBefore;

    // Get the newly deployed oracle
    const newOracle = await pionerV1.getBOracle(newOracleId);

    // Verify that the 'asset1' parameter has been set correctly
    expect(newOracle.asset1).to.equal(_asset1);

  });

  it("Update Price", async function () {

    const oracleLengthBefore = await pionerV1.getBOracleLength();

    // Deploy Oracle
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
    _cType = 0 ;

    await pionerV1Oracle.deployBOraclePion( _x, _parity,_maxConfidence,_asset1,_asset2,_maxDelay,_imA,_imB,_dfA,_dfB,_expiryA,_expiryB,_timeLockA,_timeLockB,_cType );

    const newOracleId = oracleLengthBefore;

    const priceSignature = {
        appId: "8819953379267741478318858059556381531978766925841974117591953483223779600878", 
        reqId: "0x6519a45ea86634dc3f369285463f6dd822b66e9feed77ee455dea421eee599a4",
        asset1: _asset1, 
        asset2: _asset2, 
        lastBid: ethers.parseUnits("100", 18), 
        lastAsk: ethers.parseUnits("105", 18), 
        confidence: ethers.parseUnits("1", 18), 
        signTime: (await ethers.provider.getBlock("latest")).timestamp, 
        signature: "0x5c2bcf2be9dfb9a1f9057392aeaebd0fbc1036bec5a700425c49069b12842038", 
        owner: "0x237A6Ec18AC7D9693C06f097c0EEdc16518d7c21",
        nonce: "0x1365a32bDd33661a3282992D1C334D5aB2faaDc7"
      };
  
      await pionerV1Oracle.updatePricePion(priceSignature, newOracleId); // newOracleId should be the ID of the oracle you're updating
  
      const updatedOracle = await pionerV1.getBOracle(newOracleId);
  
      expect(updatedOracle.lastBid).to.equal(priceSignature.lastBid);
      expect(updatedOracle.lastAsk).to.equal(priceSignature.lastAsk);
      expect(updatedOracle.lastPriceUpdateTime).to.equal(priceSignature.signTime);

      const lastBidBigInt = BigInt(priceSignature.lastBid);
      const lastAskBigInt = BigInt(priceSignature.lastAsk);
      const lastPriceBigInt = (lastBidBigInt + lastAskBigInt) / BigInt(2);
      
      expect(BigInt(updatedOracle.lastPrice)).to.equal(lastPriceBigInt);

    });

    it("Test wrong signTime", async function () {

        // Deploy Oracle
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
        _cType = 0 ;
    
        await pionerV1Oracle.deployBOraclePion( _x, _parity,_maxConfidence,_asset1,_asset2,_maxDelay,_imA,_imB,_dfA,_dfB,_expiryA,_expiryB,_timeLockA,_timeLockB,_cType );
        const newOracleId = await pionerV1.getBOracleLength();

        const wrongTimeSignature = {
            appId: "8819953379267741478318858059556381531978766925841974117591953483223779600878", 
            reqId: "0x6519a45ea86634dc3f369285463f6dd822b66e9feed77ee455dea421eee599a4",
            asset1: _asset1, 
            asset2: _asset2, 
            lastBid: ethers.parseUnits("100", 18), 
            lastAsk: ethers.parseUnits("105", 18), 
            confidence: ethers.parseUnits("1", 18), 
            signTime: 1, 
            signature: "0x5c2bcf2be9dfb9a1f9057392aeaebd0fbc1036bec5a700425c49069b12842038", 
            owner: "0x237A6Ec18AC7D9693C06f097c0EEdc16518d7c21",
            nonce: "0x1365a32bDd33661a3282992D1C334D5aB2faaDc7"
        }; 
    
        await expect(
          pionerV1Oracle.updatePricePion(wrongTimeSignature, newOracleId)
        ).to.be.revertedWith("wrong signature parameter");
      });
    
      it("Test mismatched assets", async function () {
        // Deploy Oracle
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
        _cType = 0 ;
    
        await pionerV1Oracle.deployBOraclePion( _x, _parity,_maxConfidence,_asset1,_asset2,_maxDelay,_imA,_imB,_dfA,_dfB,_expiryA,_expiryB,_timeLockA,_timeLockB,_cType );
        const newOracleId = await pionerV1.getBOracleLength();

        const wrongTimeSignature = {
            appId: "8819953379267741478318858059556381531978766925841974117591953483223779600878", 
            reqId: "0x6519a45ea86634dc3f369285463f6dd822b66e9feed77ee455dea421eee599a4",
            asset1: "0x0000000000000000000000000000000000000000000000000000000000000001", 
            asset2: _asset2, 
            lastBid: ethers.parseUnits("100", 18), 
            lastAsk: ethers.parseUnits("105", 18), 
            confidence: ethers.parseUnits("1", 18), 
            signTime: (await ethers.provider.getBlock("latest")).timestamp, 
            signature: "0x5c2bcf2be9dfb9a1f9057392aeaebd0fbc1036bec5a700425c49069b12842038", 
            owner: "0x237A6Ec18AC7D9693C06f097c0EEdc16518d7c21",
            nonce: "0x1365a32bDd33661a3282992D1C334D5aB2faaDc7"
        }; 
    
        await expect(
            pionerV1Oracle.updatePricePion(wrongTimeSignature, newOracleId)
        ).to.be.revertedWith("wrong signature parameter");

      });
    
      it("Test excessive confidence", async function () {
        // Deploy Oracle
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
        _cType = 0 ;
    
        await pionerV1Oracle.deployBOraclePion( _x, _parity,_maxConfidence,_asset1,_asset2,_maxDelay,_imA,_imB,_dfA,_dfB,_expiryA,_expiryB,_timeLockA,_timeLockB,_cType );
        const newOracleId = await pionerV1.getBOracleLength();

        const mismatchAssetsSignature = {
            appId: "8819953379267741478318858059556381531978766925841974117591953483223779600878", 
            reqId: "0x6519a45ea86634dc3f369285463f6dd822b66e9feed77ee455dea421eee599a4",
            asset1: _asset1, 
            asset2: _asset2, 
            lastBid: ethers.parseUnits("100", 18), 
            lastAsk: ethers.parseUnits("105", 18), 
            confidence: ethers.parseUnits("2", 18), 
            signTime: (await ethers.provider.getBlock("latest")).timestamp, 
            signature: "0x5c2bcf2be9dfb9a1f9057392aeaebd0fbc1036bec5a700425c49069b12842038", 
            owner: "0x237A6Ec18AC7D9693C06f097c0EEdc16518d7c21",
            nonce: "0x1365a32bDd33661a3282992D1C334D5aB2faaDc7"
        }; 
    
        await expect(
        pionerV1Oracle.updatePricePion(mismatchAssetsSignature, newOracleId)
        ).to.be.revertedWith("wrong signature parameter");
      });

});

