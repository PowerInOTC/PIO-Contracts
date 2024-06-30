const { expect } = require("chai");
const { ethers } = require("hardhat");
const Web3 = require("web3");
const { printBalances } = require("./utils/utils.js");

const {
  reverseConvertToBytes32,
  convertToBytes32,
} = require("./utils/utils.js");

describe("PionerV1Default", function () {
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
      price: ethers.parseUnits("1", 18),
      amount: ethers.parseUnits("20", 18),
      interestRate: ethers.parseUnits("1", 16),
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

    const _acceptPrice = ethers.parseUnits("1", 18);

    // After the wrapperOpenQuoteMM call
    await pionerV1Wrapper
      .connect(addr2)
      .wrapperOpenQuoteMM(
        bOracleSignValue,
        signaturebOracleSign,
        openQuoteSignValue,
        openQuoteSignature,
        _acceptPrice
      );

    const bContractLength = await pionerV1.getBContractLength();
    const _bContractId = bContractLength - BigInt(1);
    const bOracleLength = await pionerV1.getBOracleLength();
    await network.provider.send("evm_increaseTime", [1 * 24 * 60 * 60]);
    await network.provider.send("evm_mine");
    //get block timestamp
    const block = await network.provider.send("eth_getBlockByNumber", [
      "latest",
      false,
    ]);

    const priceSignature = {
      appId:
        "8819953379267741478318858059556381531978766925841974117591953483223779600878",
      reqId:
        "0x522d370b6bf8694319f89582909be8639c73bae0ea880d602227520b69392bdf",
      requestassetHex: convertToBytes32("forex.EURUSD/forex.USDCHF"),
      requestPairBid: ethers.parseUnits("10000", 18),
      requestPairAsk: ethers.parseUnits("10000", 18),
      requestConfidence: "5",
      requestSignTime: block.timestamp,
      requestPrecision: "5",
      signature:
        "0x86dd8ea2b4bb2deceab9f24d029251d8d3aef5de4674abb07dd50ec5bc5a0020",
      owner: "0xC810Fc19d690E33f992d82e8f19229A0437a5BfA",
      nonce: "0xB069130Ef5ee44a82E3A670cD2b6b5cEB75b3B1A",
    };

    // Add an event listener for the settlementEvent
    const settlementEventPromise = new Promise((resolve) => {
      pionerV1Wrapper.once("settlementEvent", (bContractId) => {
        resolve(bContractId);
      });
    });

    // Call the wrapperUpdatePriceAndDefault function
    const tx = await pionerV1Wrapper
      .connect(addr1)
      .wrapperUpdatePriceAndDefault(priceSignature, bOracleLength - BigInt(1));

    // Wait for the transaction to be mined
    await tx.wait();

    // Get the emitted bContractId from the event
    const emittedBContractId = await settlementEventPromise;

    // Check if the emitted bContractId matches the expected value
    expect(emittedBContractId).to.equal(_bContractId);

    await printBalances(pionerV1, addr1, addr2, addr3, owner);

    const contract = await pionerV1View.connect(addr1).getContract(0);
  });
});

/*
 cd .\PionerV1\    
npx hardhat node
*/

/*
 cd .\PionerV1\    
npx hardhat test test/pionerV1Default.js 
*/
