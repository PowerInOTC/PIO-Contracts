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
    PionerV1Warper = await ethers.getContractFactory("PionerV1Warper", {libraries: {PionerV1Utils: pionerV1Utils.target,},});
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
    OracleSwapWithSignature: [
      { name: 'x', type: 'uint256' },
      { name: 'parity', type: 'uint8' },
      { name: 'maxConfidence', type: 'uint256' },
      { name: 'asset1', type: 'bytes32' },
      { name: 'asset2', type: 'bytes32' },
      { name: 'maxDelay', type: 'uint256' },
      { name: 'imA', type: 'uint256' },
      { name: 'imB', type: 'uint256' },
      { name: 'dfA', type: 'uint256' },
      { name: 'dfB', type: 'uint256' },
      { name: 'expiryA', type: 'uint256' },
      { name: 'expiryB', type: 'uint256' },
      { name: 'timeLockA', type: 'uint256' },
      { name: 'signatureHashOpenQuote', type: 'bytes32' }, // Adjusted for EIP-712 compatibility
      { name: 'nonce', type: 'uint256' }
  ]
  
  const oracleSwapWithSignatureValue = {
    x: 0, // Assuming a placeholder value
    parity: 0, // Assuming a placeholder or default value
    maxConfidence: 0, // Assuming a placeholder value
    asset1: ethers.utils.formatBytes32String(""), // Placeholder asset identifier
    asset2: ethers.utils.formatBytes32String(""), // Placeholder asset identifier
    maxDelay: 0, // Assuming a placeholder value
    imA: ethers.BigNumber.from("0"), // Default to 0
    imB: ethers.BigNumber.from("0"), // Default to 0
    dfA: ethers.BigNumber.from("0"), // Default to 0
    dfB: ethers.BigNumber.from("0"), // Default to 0
    expiryA: 0, // Assuming a placeholder value
    expiryB: 0, // Assuming a placeholder value
    timeLockA: 0, // Assuming a placeholder value
    signatureHashOpenQuote: "0x", // Assuming an empty hash or signature
    nonce: 0
  };
  
    const bContractLength = await pionerV1.getBContractLength();
    const _bContractId = bContractLength - BigInt(1);
    const bOracleLength = await pionerV1.getBOracleLength();
    const _bOracleId = bOracleLength - BigInt(1);
    const value = {
      isLong: true,
      bOracleId: bOracleLength - BigInt(1),
      price: ethers.parseUnits("46", 18),
      qty: ethers.parseUnits("10", 18),
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
      value,signOpenQuote
    )).to.emit(pionerV1Open, "openQuoteSignedEvent");

    const _acceptPrice = ethers.parseUnits("50", 18);
    const _backendAffiliate = owner.address;

    const newbContractLength = await pionerV1.getBContractLength();
    const _newbContractId = newbContractLength - BigInt(1);
    await pionerV1Open.connect(addr2).acceptQuote(_newbContractId, _acceptPrice, _backendAffiliate);

    const finalBalanceAddr1 = await pionerV1.getBalance(addr1);
    const finalBalanceAddr2 = await pionerV1.getBalance(addr2);
    const owedAmount1 = await pionerV1.getOwedAmount(addr1,addr2);
    const owedAmount2 = await pionerV1.getOwedAmount(addr2,addr1);
    console.log("balances : ",BigInt(finalBalanceAddr1)/BigInt(1e18),BigInt(finalBalanceAddr2)/BigInt(1e18), BigInt(owedAmount1)/BigInt(1e18), BigInt(owedAmount2)/BigInt(1e18));
  });

 

});

