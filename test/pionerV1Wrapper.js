const { expect } = require("chai");
const { ethers } = require("hardhat");
const Web3 = require("web3");
const { printBalances } = require("./utils/utils.js");
const {
  reverseConvertToBytes32,
  convertToBytes32,
} = require("./utils/utils.js");

describe("PionerV1Wrappers Signatures Contract", function () {
  let FakeUSD, fakeUSD, PionerV1, pionerV1;
  let owner, addr1, addr2, addr3, balances, owed1, owed2;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const PionerV1Utils = await ethers.getContractFactory("PionerV1Utils");
    const pionerV1Utils = await PionerV1Utils.deploy();
    const SchnorrSECP256K1VerifierV2 = await ethers.getContractFactory(
      "SchnorrSECP256K1VerifierV2"
    );
    const schnorrSECP256K1VerifierV2 =
      await SchnorrSECP256K1VerifierV2.deploy();
    const MuonClientBase = await ethers.getContractFactory("MuonClientBase");
    const muonClientBase = await MuonClientBase.deploy();

    FakeUSD = await ethers.getContractFactory("fakeUSD");
    fakeUSD = await FakeUSD.deploy();

    _daiAddress = fakeUSD.target;
    _min_notional = ethers.parseUnits("25", 18);
    _frontend_share = ethers.parseUnits("3", 17);
    _affiliation_share = ethers.parseUnits("3", 17);
    _hedger_share = ethers.parseUnits("5", 16);
    _pioner_dao_share = ethers.parseUnits("4", 17);
    _total_share = ethers.parseUnits("3", 17);
    _default_auction_period = 30;
    _cancel_time_buffer = 30;
    _max_open_positions = 100;
    _grace_period = 300;
    _pioner_dao = addr3.address;
    _admin = addr3.address;

    PionerV1 = await ethers.getContractFactory("PionerV1", {
      libraries: {
        PionerV1Utils: pionerV1Utils.target,
      },
    });
    pionerV1 = await PionerV1.deploy();

    PionerV1Compliance = await ethers.getContractFactory("PionerV1Compliance");
    pionerV1Compliance = await PionerV1Compliance.deploy(pionerV1.target);
    PionerV1Open = await ethers.getContractFactory("PionerV1Open");
    pionerV1Open = await PionerV1Open.deploy(
      pionerV1.target,
      pionerV1Compliance.target
    );
    PionerV1Close = await ethers.getContractFactory("PionerV1Close", {
      libraries: { PionerV1Utils: pionerV1Utils.target },
    });
    pionerV1Close = await PionerV1Close.deploy(
      pionerV1.target,
      pionerV1Compliance.target
    );
    PionerV1Default = await ethers.getContractFactory("PionerV1Default", {
      libraries: { PionerV1Utils: pionerV1Utils.target },
    });
    pionerV1Default = await PionerV1Default.deploy(
      pionerV1.target,
      pionerV1Compliance.target
    );
    PionerV1View = await ethers.getContractFactory("PionerV1View");
    pionerV1View = await PionerV1View.deploy(
      pionerV1.target,
      pionerV1Compliance.target
    );

    PionerV1Oracle = await ethers.getContractFactory("PionerV1Oracle");
    pionerV1Oracle = await PionerV1Oracle.deploy(
      pionerV1.target,
      pionerV1Compliance.target
    );
    PionerV1Wrapper = await ethers.getContractFactory("PionerV1Wrapper");
    pionerV1Wrapper = await PionerV1Wrapper.deploy(
      pionerV1.target,
      pionerV1Compliance.target,
      pionerV1Open.target,
      pionerV1Close.target,
      pionerV1Default.target,
      pionerV1Oracle.target,
      { libraries: { PionerV1Utils: pionerV1Utils.target } }
    );

    await pionerV1
      .connect(owner)
      .setContactAddress(
        _daiAddress,
        _min_notional,
        _frontend_share,
        _affiliation_share,
        _hedger_share,
        _pioner_dao_share,
        _total_share,
        _default_auction_period,
        _cancel_time_buffer,
        _max_open_positions,
        _grace_period,
        owner.address,
        owner.address,
        pionerV1Open.target,
        pionerV1Close.target,
        pionerV1Default.target,
        pionerV1Compliance.target,
        pionerV1Oracle.target,
        pionerV1Wrapper.target
      );
    const mintAmount = ethers.parseUnits("10000", 18);
    await fakeUSD.connect(addr1).mint(mintAmount);
    await fakeUSD.connect(addr1).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance
      .connect(addr1)
      .deposit(ethers.parseUnits("10000", 18), 1, addr1);
    await fakeUSD.connect(addr2).mint(mintAmount);
    await fakeUSD.connect(addr2).approve(pionerV1Compliance.target, mintAmount);
    await pionerV1Compliance
      .connect(addr2)
      .deposit(ethers.parseUnits("10000", 18), 1, addr2);
    await fakeUSD.connect(addr3).mint(mintAmount);
    await fakeUSD.connect(addr3).approve(pionerV1Compliance.target, mintAmount);

    _x = "0x20568a84796e6ade0446adfd2d8c4bba2c798c2af0e8375cc3b734f71b17f5fd";
    _parity = 0;
    _maxConfidence = ethers.parseUnits("1", 18);
    _assetHex = convertToBytes32("forex.EURUSD/forex.GBPUSD");

    _maxDelay = 60000;
    _precision = 5;
    _imA = ethers.parseUnits("10", 16);
    _imB = ethers.parseUnits("10", 16);
    _dfA = ethers.parseUnits("25", 15);
    _dfB = ethers.parseUnits("25", 15);
    _expiryA = 60;
    _expiryB = 60;
    _timeLock = 1440 * 30 * 3;
    _cType = 1;

    await pionerV1Oracle.deployBOraclePion(
      _x,
      _parity,
      _maxConfidence,
      _assetHex,
      _maxDelay,
      _precision,
      _imA,
      _imB,
      _dfA,
      _dfB,
      _expiryA,
      _expiryB,
      _timeLock,
      _cType
    );

    const oraclePrint = await pionerV1View.getOracle(0);
    console.log("oraclePrint : ", oraclePrint);

    const oracleLength = await pionerV1.getBOracleLength();

    const _issLong = true;
    const _bOracleId = oracleLength - BigInt(1);
    const _price = ethers.parseUnits("50", 18);
    const _amount = ethers.parseUnits("10", 18);
    const _interestRate = ethers.parseUnits("1", 17);
    const _isAPayingAPR = true;
    const _frontEnd = addr3.address;
    const _affiliate = addr3.address;

    await pionerV1Open
      .connect(addr1)
      .openQuote(
        _issLong,
        _bOracleId,
        _price,
        _amount,
        _interestRate,
        _isAPayingAPR,
        _frontEnd,
        _affiliate
      );

    const _acceptPrice = ethers.parseUnits("50", 18);

    await pionerV1Open.connect(addr2).acceptQuote(_bOracleId, _acceptPrice);
  });

  it("openMM + closeMM wrappers", async function () {
    await printBalances(pionerV1, addr1, addr2, addr3, owner);

    const domainOpen = {
      name: "PionerV1Open",
      version: "1.0",
      chainId: 31337,
      verifyingContract: pionerV1Open.target,
    };

    const openQuoteSignType = {
      Quote: [
        { name: "isLong", type: "bool" },
        { name: "bOracleId", type: "uint256" },
        { name: "price", type: "uint256" },
        { name: "amount", type: "uint256" },
        { name: "interestRate", type: "uint256" },
        { name: "isAPayingAPR", type: "bool" },
        { name: "frontEnd", type: "address" },
        { name: "affiliate", type: "address" },
        { name: "authorized", type: "address" },
        { name: "nonce", type: "uint256" },
      ],
    };

    const openQuoteSignValue = {
      isLong: false,
      bOracleId: "0",
      price: ethers.parseUnits("11", 17),
      amount: ethers.parseUnits("100000", 18),
      interestRate: ethers.parseUnits("400", 16),
      isAPayingAPR: true,
      frontEnd: addr1.address,
      affiliate: addr1.address,
      authorized: addr2.address,
      nonce: 123,
    };

    const openQuoteSignature = await addr1.signTypedData(
      domainOpen,
      openQuoteSignType,
      openQuoteSignValue
    );

    const domainWrapper = {
      name: "PionerV1Wrapper",
      version: "1.0",
      chainId: 31337,
      verifyingContract: pionerV1Wrapper.target,
    };
    const bOracleSignType = {
      bOracleSign: [
        { name: "x", type: "uint256" },
        { name: "parity", type: "uint8" },
        { name: "maxConfidence", type: "uint256" },
        { name: "assetHex", type: "bytes32" },
        { name: "maxDelay", type: "uint256" },
        { name: "precision", type: "uint256" },
        { name: "imA", type: "uint256" },
        { name: "imB", type: "uint256" },
        { name: "dfA", type: "uint256" },
        { name: "dfB", type: "uint256" },
        { name: "expiryA", type: "uint256" },
        { name: "expiryB", type: "uint256" },
        { name: "timeLock", type: "uint256" },
        { name: "signatureHashOpenQuote", type: "bytes" },
        { name: "nonce", type: "uint256" },
      ],
    };
    const bOracleSignValue = {
      x: "0x20568a84796e6ade0446adfd2d8c4bba2c798c2af0e8375cc3b734f71b17f5fd",
      parity: 0,
      maxConfidence: ethers.parseUnits("1", 18),
      assetHex: convertToBytes32("forex.EURUSD/forex.USDCHF"),
      maxDelay: 600,
      precision: 5,
      imA: ethers.parseUnits("10", 16),
      imB: ethers.parseUnits("10", 16),
      dfA: ethers.parseUnits("25", 15),
      dfB: ethers.parseUnits("25", 15),
      expiryA: 129600,
      expiryB: 129600,
      timeLock: 129600,
      signatureHashOpenQuote: openQuoteSignature,
      nonce: 123,
    };

    const signaturebOracleSign = await addr1.signTypedData(
      domainWrapper,
      bOracleSignType,
      bOracleSignValue
    );

    const _acceptPrice = ethers.parseUnits("50", 18);

    // After the wrapperOpenQuoteMM call
    const tx = await pionerV1Wrapper
      .connect(addr2)
      .wrapperOpenQuoteMM(
        bOracleSignValue,
        signaturebOracleSign,
        openQuoteSignValue,
        openQuoteSignature,
        _acceptPrice
      );

    if (acceptQuoteEvent) {
      console.log("acceptQuoteEvent emitted:");
      console.log("  openQuoteSignature:", acceptQuoteEvent.args[0]);
      console.log("  bContractId:", acceptQuoteEvent.args[1].toString());
    } else {
      console.log("acceptQuoteEvent not found in transaction logs");
    }

    // Print the openQuoteSignValue (input for openQuoteSign)
    console.log("openQuoteSign input:");
    console.log(openQuoteSignature);
    console.log(ethers.keccak256(openQuoteSignature));

    const bContractLength = await pionerV1.getBContractLength();
    const _bContractId = bContractLength - BigInt(1);
    const bOracleLength = await pionerV1.getBOracleLength();
    await network.provider.send("evm_increaseTime", [1 * 24 * 60 * 60]);
    await network.provider.send("evm_mine");

    const domainClose = {
      name: "PionerV1Close",
      version: "1.0",
      chainId: 31337,
      verifyingContract: pionerV1Close.target,
    };

    const OpenCloseQuoteType = {
      OpenCloseQuote: [
        { name: "bContractId", type: "uint256" },
        { name: "price", type: "uint256" },
        { name: "amount", type: "uint256" },
        { name: "limitOrStop", type: "uint256" },
        { name: "expiry", type: "uint256" },
        { name: "authorized", type: "address" },
        { name: "nonce", type: "uint256" },
      ],
    };

    const openCloseQuoteValue = {
      bContractId: _bContractId,
      price: ethers.parseUnits("12", 17),
      amount: ethers.parseUnits("100", 18),
      limitOrStop: ethers.parseUnits("12", 17),
      expiry: "60000000000",
      authorized: addr2.address,
      nonce: 123,
    };

    const signCloseQuote = await addr1.signTypedData(
      domainClose,
      OpenCloseQuoteType,
      openCloseQuoteValue
    );

    await pionerV1Wrapper
      .connect(addr2)
      .wrapperCloseLimitMM(openCloseQuoteValue, signCloseQuote);

    await printBalances(pionerV1, addr1, addr2, addr3, owner);
  });
});

/*
 cd .\PionerV1\    
npx hardhat test test/pionerV1Wrapper.js 
*/
