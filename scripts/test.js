const hre = require("hardhat");
const { ethers } = require("hardhat");
/*
npx hardhat --network sonic run ./scripts/test.js
*/

const Web3 = require("web3");

function convertToBytes32(str) {
  const hex = Web3.utils.toHex(str);
  return Web3.utils.padRight(hex, 64);
}
async function main() {
  const [owner, addr1, addr2, addr3] = await hre.ethers.getSigners();

  // ... (Previous deployment code remains the same)
  const PionerV1UtilsAddress = "0xb400785D741F8815c657A03Eebb04944eb7D7b9C";
  const FakeUSDAddress = "0x6A744031609cfCef46AaC03F516550FB73Cc1390";
  const PionerV1Address = "0x0522ffEAE4Fd670f63482E969FD4B1dE8866F972";
  const PionerV1ComplianceAddress =
    "0xf82C9516268C6DE94d99d18706769377113861C3";
  const PionerV1OpenAddress = "0xF9d4DeD362a9C2728be18eE62A7E3076054b3279";
  const PionerV1CloseAddress = "0xb638b9d2390FF58a6Abf9aF33337F98071758D98";
  const PionerV1DefaultAddress = "0x874547948f91477848f2C36d8B06f52aB7AEfD47";
  const PionerV1ViewAddress = "0xc11f825fF2A7Ac7bD4F4B28bDEdbbFA5BaeEC0D9";
  const PionerV1OracleAddress = "0xf447AbDcADC871EF6E366f26DBA663bACE45dD5d";
  const PionerV1WarperAddress = "0x271990c7a1BDD612EC4c60492b24Dc693af67198";

  const FakeUSD = await hre.ethers.getContractFactory("fakeUSD");
  const fakeUSD = FakeUSD.attach(FakeUSDAddress);

  const PionerV1Wrapper = await hre.ethers.getContractFactory(
    "PionerV1Wrapper"
  );
  const pionerV1Wrapper = await PionerV1Wrapper.attach(PionerV1WarperAddress);

  const PionerV1Open = await hre.ethers.getContractFactory("PionerV1Open");
  const pionerV1Open = await PionerV1Open.attach(PionerV1OpenAddress);
  // Live testnet test

  const domainOpen = {
    name: "PionerV1Open",
    version: "1.0",
    chainId: 64165,
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
    isLong: true,
    bOracleId: 0,
    price: ethers.parseUnits("50", 18),
    amount: ethers.parseUnits("10", 18),
    interestRate: ethers.parseUnits("1", 17),
    isAPayingAPR: true,
    frontEnd: owner.address,
    affiliate: owner.address,
    authorized: addr2.address,
    nonce: 0,
  };

  const signatureOpenQuote = await addr1.signTypedData(
    domainOpen,
    openQuoteSignType,
    openQuoteSignValue
  );

  const domainWrapper = {
    name: "PionerV1Wrapper",
    version: "1.0",
    chainId: 64165,
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
    assetHex: convertToBytes32("forex.EURUSD/forex.GBPUSD"),
    maxDelay: 600,
    precision: 5,
    imA: ethers.parseUnits("10", 16),
    imB: ethers.parseUnits("10", 16),
    dfA: ethers.parseUnits("25", 15),
    dfB: ethers.parseUnits("25", 15),
    expiryA: 60,
    expiryB: 60,
    timeLock: 1440 * 30 * 3,
    signatureHashOpenQuote: signatureOpenQuote,
    nonce: 0,
  };

  const signatureBoracle = await addr1.signTypedData(
    domainWrapper,
    bOracleSignType,
    bOracleSignValue
  );

  const _acceptPrice = ethers.parseUnits("50", 18);

  console.log("signatureOpenQuote", ethers.hexlify(signatureOpenQuote));
  console.log("signatureBoracle", ethers.hexlify(signatureBoracle));
  console.log("addr1", addr1.address);
  console.log("addr2", addr2.address);
  await pionerV1Wrapper
    .connect(addr2)
    .wrapperOpenQuoteMM(
      bOracleSignValue,
      signatureBoracle,
      openQuoteSignValue,
      signatureOpenQuote,
      _acceptPrice
    );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
