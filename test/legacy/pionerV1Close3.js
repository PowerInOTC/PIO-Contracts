const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PionerV1Close Signatures Contract", function () {
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
    PionerV1Open = await ethers.getContractFactory("PionerV1Open");
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
    pionerV1Warper = await PionerV1Warper.deploy(pionerV1.target, pionerV1Compliance.target, pionerV1Open.target ,pionerV1Close.target ,pionerV1Default.target, pionerV1Oracle.target, {libraries: {PionerV1Utils: pionerV1Utils.target,},} );
    
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
    _precision = 5 ;
    _imA = ethers.parseUnits("10", 16) ;
    _imB = ethers.parseUnits("10", 16) ;
    _dfA = ethers.parseUnits("25", 15) ;
    _dfB = ethers.parseUnits("25", 15) ;
    _expiryA = 60 ;
    _expiryB = 60 ;
    _timeLock = 1440 * 30 * 3 ;
    _cType = 1 ;

    await pionerV1Oracle.deployBOraclePion( _x, _parity,_maxConfidence,_asset1,_asset2,_maxDelay, _precision, _imA,_imB,_dfA,_dfB,_expiryA,_expiryB,_timeLock,_cType );

    const oracleLength = await pionerV1.getBOracleLength();

    const _issLong = true;
    const _bOracleId = oracleLength - BigInt(1);
    const _price = ethers.parseUnits("50", 18);
    const _amount = ethers.parseUnits("10", 18);
    const _interestRate = ethers.parseUnits("1", 17); 
    const _isAPayingAPR = true;
    const _frontEnd = owner.address;
    const _affiliate = owner.address;

    await pionerV1Open.connect(addr1).openQuote(_issLong, _bOracleId, _price, _amount, _interestRate, _isAPayingAPR, _frontEnd, _affiliate);

    const _acceptPrice = ethers.parseUnits("50", 18);
    const _backendAffiliate = owner.address;

    await pionerV1Open.connect(addr2).acceptQuote(_bOracleId, _acceptPrice, _backendAffiliate);
  });

  it("openCloseQuote signature test", async function () {

    const initialBalanceAddr1 = await pionerV1.getBalance(addr1);
    const initialBalanceAddr2 = await pionerV1.getBalance(addr2);

    console.log("balances : ",BigInt(initialBalanceAddr1)/BigInt(1e18),BigInt(initialBalanceAddr2)/BigInt(1e18));
      const domain = {
        name: 'PionerV1Open',
        version: '1.0',
        chainId: 31337,
        verifyingContract: pionerV1Open.target
      };
      
    const types = {
      Quote: [
        { name: 'isLong', type: 'bool' },
        { name: 'bOracleId', type: 'uint256' },
        { name: 'price', type: 'uint256' },
        { name: 'amount', type: 'uint256' },
        { name: 'interestRate', type: 'uint256' },
        { name: 'isAPayingAPR', type: 'bool' },
        { name: 'frontEnd', type: 'address' },
        { name: 'affiliate', type: 'address' },
        { name: 'authorized', type: 'address' },
        { name: 'nonce', type: 'uint256' }
      ]
    };
    const bContractLength = await pionerV1.getBContractLength();
    const _bContractId = bContractLength - BigInt(1);
    const bOracleLength = await pionerV1.getBOracleLength();
    const _bOracleId = bOracleLength - BigInt(1);
    const value = {
      isLong: true,
      bOracleId: bOracleLength - BigInt(1),
      price: ethers.parseUnits("50", 18),
      amount: ethers.parseUnits("10", 18),
      interestRate: ethers.parseUnits("1", 17),
      isAPayingAPR: true,
      frontEnd: owner.address,
      affiliate: owner.address,
      authorized: "0x0000000000000000000000000000000000000000",
      nonce: 0
    };


    await network.provider.send("evm_increaseTime", [1 * 24 * 60 * 60]);
    await network.provider.send("evm_mine");
    const signOpenQuote = await addr1.signTypedData(domain, types, value);
    await expect(pionerV1Open.connect(addr1).openQuoteSigned(
      value,signOpenQuote, "0x0000000000000000000000000000000000000000"
    )).to.emit(pionerV1Open, "openQuoteSignedEvent");
    const _acceptPrice = ethers.parseUnits("50", 18);
    const _backendAffiliate = owner.address;

    const newbContractLength = await pionerV1.getBContractLength();
    const _newbContractId = newbContractLength - BigInt(1);
    await pionerV1Open.connect(addr2).acceptQuote(_newbContractId, _acceptPrice, _backendAffiliate);
      const types3 = {
          OpenCloseQuote: [
              { name: 'bContractId', type: 'uint256' },
              { name: 'price', type: 'uint256' },
              { name: 'amount', type: 'uint256' },
              { name: 'limitOrStop', type: 'uint256' },
              { name: 'expiry', type: 'uint256' },
              { name: 'authorized', type: 'address' },
              { name: 'nonce', type: 'uint256' }
          ]};

    const types4 = {
        CancelCloseQuoteRequest: [
            { name: 'targetHash', type: 'bytes' },
            { name: 'nonce', type: 'uint256' }
        ]};
    
    const openCloseQuoteValue = {
        bContractId: _newbContractId,
        price: ethers.parseUnits("600", 18),
        amount: ethers.parseUnits("10", 18),
        limitOrStop: 0, 
        expiry: 100000000000, 
        authorized: "0x0000000000000000000000000000000000000000", 
        nonce: 0
    };
    
    const signCloseQuote = await addr1.signTypedData(domain, types3, openCloseQuoteValue);
    
    const cancelCloseRequestValue = {
        targetHash: signCloseQuote, 
        nonce: 0
    };

    //pionerV1Close.connect(addr2).openCloseQuoteSigned(openCloseQuoteValue,signCloseQuote); 
    const getBCloseQuoteLength1 = await pionerV1.getBCloseQuoteLength();
    const _newbCloseQuoteId = getBCloseQuoteLength1 - BigInt(1);

    //pionerV1Close.connect(addr2).acceptCloseQuote(0, 0 , ethers.parseUnits("10", 18));
    //const signCancelCloseQuote = await addr1.signTypedData(domain, CancelCloseQuoteRequest, cancelCloseRequestValue);
    pionerV1Warper.connect(addr2).warperCloseQuoteSignedAndAcceptClose( openCloseQuoteValue, signCloseQuote );
    const bbob = await pionerV1.getBalance(addr1);

    const bob1 = await pionerV1.getBalance(addr1);
    const bob2 = await pionerV1.getBalance(addr2);
    const owedAmount1 = await pionerV1.getOwedAmount(addr1,addr2);
    const owedAmount2 = await pionerV1.getOwedAmount(addr2,addr1);
    console.log("balances : ",BigInt(bob1)/BigInt(1e18),BigInt(bob2)/BigInt(1e18), BigInt(owedAmount1)/BigInt(1e18), BigInt(owedAmount2)/BigInt(1e18));
  });


  });





