const ethers = require("ethers");
const fs = require("fs");
/*

export interface QuoteArgs {
  isLong: boolean;
  bOracleId: number;
  price: ethers.BigNumber;
  amount: ethers.BigNumber;
  interestRate: ethers.BigNumber;
  isAPayingAPR: boolean;
  frontEnd: string;
  affiliate: string;
  authorized: string;
  nonce: number;
}

export interface BOracleSignArgs {
  x: string;
  parity: number;
  maxConfidence: ethers.BigNumber;
  assetHex: string;
  maxDelay: number;
  precision: number;
  imA: ethers.BigNumber;
  imB: ethers.BigNumber;
  dfA: ethers.BigNumber;
  dfB: ethers.BigNumber;
  expiryA: number;
  expiryB: number;
  timeLock: number;
  nonce: number;
}

export interface OpenQuoteSignValue {
  isLong: boolean;
  bOracleId: number;
  price: ethers.BigNumber;
  amount: ethers.BigNumber;
  interestRate: ethers.BigNumber;
  isAPayingAPR: boolean;
  frontEnd: string;
  affiliate: string;
  authorized: string;
  nonce: number;
}

export interface BOracleSignValue {
  x: string;
  parity: number;
  maxConfidence: ethers.BigNumber;
  assetHex: string;
  maxDelay: number;
  precision: number;
  imA: ethers.BigNumber;
  imB: ethers.BigNumber;
  dfA: ethers.BigNumber;
  dfB: ethers.BigNumber;
  expiryA: number;
  expiryB: number;
  timeLock: number;
  signatureHashOpenQuote: string;
  nonce: number;
}

export interface OpenCloseQuoteValue {
  bContractId: ethers.BigNumber;
  price: ethers.BigNumber;
  amount: ethers.BigNumber;
  limitOrStop: number;
  expiry: number;
  authorized: string;
  nonce: number;
}

export interface SDKFunctions {
  signQuote(
    signer: ethers.Signer,
    isLong: boolean,
    bOracleId: number,
    price: ethers.BigNumber,
    amount: ethers.BigNumber,
    interestRate: ethers.BigNumber,
    isAPayingAPR: boolean,
    frontEnd: string,
    affiliate: string,
    authorized: string,
    nonce: number
  ): Promise<string>;

  signBOracleSign(
    signer: ethers.Signer,
    x: string,
    parity: number,
    maxConfidence: ethers.BigNumber,
    assetHex: string,
    maxDelay: number,
    precision: number,
    imA: ethers.BigNumber,
    imB: ethers.BigNumber,
    dfA: ethers.BigNumber,
    dfB: ethers.BigNumber,
    expiryA: number,
    expiryB: number,
    timeLock: number,
    signatureHashOpenQuote: string,
    nonce: number
  ): Promise<string>;

  signCloseQuote(
    signer: ethers.Signer,
    bContractId: ethers.BigNumber,
    price: ethers.BigNumber,
    amount: ethers.BigNumber,
    limitOrStop: number,
    expiry: number,
    authorized: string,
    nonce: number
  ): Promise<string>;

  warperOpenQuoteMM(
    signer: ethers.Signer,
    quoteArgs: QuoteArgs,
    bOracleSignArgs: BOracleSignArgs,
    acceptPrice: ethers.BigNumber
  ): Promise<ethers.ContractTransaction>;

  warperCloseLimitMM(
    signer: ethers.Signer,
    bContractId: ethers.BigNumber,
    price: ethers.BigNumber,
    amount: ethers.BigNumber,
    limitOrStop: number,
    expiry: number,
    authorized: string,
    nonce: number
  ): Promise<ethers.ContractTransaction>;
}*/

const FakeUSDAddress = "0x60a75B099Fe78Cb7Fad097bF2C082c467686ecd5";
const PionerV1Address = "0xEA0224877722d59aef9c16aafD83d132634bDaC1";
const PionerV1ComplianceAddress = "0xD6C07Ed68941B2B75c7A42008C446DDf67795ecf";
const PionerV1OpenAddress = "0x4549500cb81DDA59fF8cB21b7b77C630181cDFA5";
const PionerV1CloseAddress = "0x8Fe0bcCAFA648b093C448ed8Bb732F65Cef734c2";
const PionerV1DefaultAddress = "0x91570188747272F90DFF014def0109B399b7d63f";
const PionerV1ViewAddress = "0xc11f825fF2A7Ac7bD4F4B28bDEdbbFA5BaeEC0D9";
const PionerV1OracleAddress = "0xf447AbDcADC871EF6E366f26DBA663bACE45dD5d";
const PionerV1WarperAddress = "0x3941DdF936ffe2de5Cd3648ac5ee2c0F8C171A67";

const privateKeys = [
  'b63a221a15a6e40e2a79449c0d05b9a1750440f383b0a41b4d6719d7611607b4',
  '578c436136413ec3626d3451e89ce5e633b249677851954dff6b56fad50ac6fe',
  'ceed6376f9371cd316329c401d99ddcd3b1e3ab0792d4275ff18f6589a2e24af',
  '379693e320ae33a8e6b3efdce70dc9f86b9da505115862b20d31947e0b5e9a9d'
];

const FakeUSDArtifact = JSON.parse(fs.readFileSync("./abis/FakeUSD.sol/fakeUSD.json"));
const FakeUSDABI = FakeUSDArtifact.abi;
const PionerV1Artifact = JSON.parse(fs.readFileSync("./abis/Functions/PionerV1.sol/PionerV1.json"));
const PionerV1ABI = PionerV1Artifact.abi;
const PionerV1ComplianceArtifact = JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Compliance.sol/PionerV1Compliance.json"));
const PionerV1ComplianceABI = PionerV1ComplianceArtifact.abi;
const PionerV1OpenArtifact = JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Open.sol/PionerV1Open.json"));
const PionerV1OpenABI = PionerV1OpenArtifact.abi;
const PionerV1CloseArtifact = JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Close.sol/PionerV1Close.json"));
const PionerV1CloseABI = PionerV1CloseArtifact.abi;
const PionerV1DefaultArtifact = JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Default.sol/PionerV1Default.json"));
const PionerV1DefaultABI = PionerV1DefaultArtifact.abi;
const PionerV1ViewArtifact = JSON.parse(fs.readFileSync("./abis/Libs/PionerV1View.sol/PionerV1View.json"));
const PionerV1ViewABI = PionerV1ViewArtifact.abi;
const PionerV1OracleArtifact = JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Oracle.sol/PionerV1Oracle.json"));
const PionerV1OracleABI = PionerV1OracleArtifact.abi;
const PionerV1WarperArtifact = JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Warper.sol/PionerV1Warper.json"));
const PionerV1WarperABI = PionerV1WarperArtifact.abi;

const provider = new ethers.JsonRpcProvider("https://rpcapi.sonic.fantom.network/");
const signers = privateKeys.map(privateKey => new ethers.Wallet(privateKey, provider));

const fakeUSD = new ethers.Contract(FakeUSDAddress, FakeUSDABI, signers[0]);

const pionerV1 = new ethers.Contract(PionerV1Address, PionerV1ABI, signers[0]);
const pionerV1Compliance = new ethers.Contract(PionerV1ComplianceAddress, PionerV1ComplianceABI, signers[0]);
const pionerV1Open = new ethers.Contract(PionerV1OpenAddress, PionerV1OpenABI, signers[0]);
const pionerV1Close = new ethers.Contract(PionerV1CloseAddress, PionerV1CloseABI, signers[0]);
const pionerV1Default = new ethers.Contract(PionerV1DefaultAddress, PionerV1DefaultABI, signers[0]);
const pionerV1View = new ethers.Contract(PionerV1ViewAddress, PionerV1ViewABI, signers[0]);
const pionerV1Oracle = new ethers.Contract(PionerV1OracleAddress, PionerV1OracleABI, signers[0]);
const pionerV1Warper = new ethers.Contract(PionerV1WarperAddress, PionerV1WarperABI, signers[0]);

async function signQuote(signer, isLong, bOracleId, price, amount, interestRate, isAPayingAPR, frontEnd, affiliate, authorized, nonce) {
  const domainOpen = {
    name: 'PionerV1Open',
    version: '1.0',
    chainId: 31337,
    verifyingContract: pionerV1Open.target,
  };

  const openQuoteSignType = {
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
      { name: 'nonce', type: 'uint256' },
    ],
  };

  const openQuoteSignValue = {
    isLong,
    bOracleId,
    price,
    amount,
    interestRate,
    isAPayingAPR,
    frontEnd,
    affiliate,
    authorized,
    nonce,
  };

  const openQuoteSignature = await signer.signTypedData(domainOpen, openQuoteSignType, openQuoteSignValue);

  return openQuoteSignature;
}

async function signBOracleSign(signer, x, parity, maxConfidence, assetHex, maxDelay, precision, imA, imB, dfA, dfB, expiryA, expiryB, timeLock, signatureHashOpenQuote, nonce) {
  const domainWarper = {
    name: 'PionerV1Warper',
    version: '1.0',
    chainId: 31337,
    verifyingContract: pionerV1Warper.target,
  };

  const bOracleSignType = {
    bOracleSign: [
      { name: 'x', type: 'uint256' },
      { name: 'parity', type: 'uint8' },
      { name: 'maxConfidence', type: 'uint256' },
      { name: 'assetHex', type: 'bytes32' },
      { name: 'maxDelay', type: 'uint256' },
      { name: 'precision', type: 'uint256' },
      { name: 'imA', type: 'uint256' },
      { name: 'imB', type: 'uint256' },
      { name: 'dfA', type: 'uint256' },
      { name: 'dfB', type: 'uint256' },
      { name: 'expiryA', type: 'uint256' },
      { name: 'expiryB', type: 'uint256' },
      { name: 'timeLock', type: 'uint256' },
      { name: 'signatureHashOpenQuote', type: 'bytes' },
      { name: 'nonce', type: 'uint256' },
    ],
  };

  const bOracleSignValue = {
    x,
    parity,
    maxConfidence,
    assetHex,
    maxDelay,
    precision,
    imA,
    imB,
    dfA,
    dfB,
    expiryA,
    expiryB,
    timeLock,
    signatureHashOpenQuote,
    nonce,
  };

  const signaturebOracleSign = await signer.signTypedData(domainWarper, bOracleSignType, bOracleSignValue);

  return signaturebOracleSign;
}

async function signOpenAndBOracleSign(signer, quoteArgs, bOracleSignArgs) {
  const openQuoteSignature = await signQuote(signer, ...quoteArgs);
  const signaturebOracleSign = await signBOracleSign(signer, ...bOracleSignArgs, openQuoteSignature);

  return {
    openQuoteSignature,
    signaturebOracleSign,
  };
}

async function signCloseQuote(signer, bContractId, price, amount, limitOrStop, expiry, authorized, nonce) {
  const domainClose = {
    name: 'PionerV1Close',
    version: '1.0',
    chainId: 31337,
    verifyingContract: pionerV1Close.target,
  };

  const OpenCloseQuoteType = {
    OpenCloseQuote: [
      { name: 'bContractId', type: 'uint256' },
      { name: 'price', type: 'uint256' },
      { name: 'amount', type: 'uint256' },
      { name: 'limitOrStop', type: 'uint256' },
      { name: 'expiry', type: 'uint256' },
      { name: 'authorized', type: 'address' },
      { name: 'nonce', type: 'uint256' },
    ],
  };

  const openCloseQuoteValue = {
    bContractId,
    price,
    amount,
    limitOrStop,
    expiry,
    authorized,
    nonce,
  };

  const signCloseQuote = await signer.signTypedData(domainClose, OpenCloseQuoteType, openCloseQuoteValue);

  return signCloseQuote;
}

async function main() {
    const mintAmount = ethers.parseUnits("1000", 18); 

    await fakeUSD.mint(mintAmount);

    const balance = await fakeUSD.balanceOf(await signers[0].getAddress());
    console.log("FakeUSD balance:", ethers.formatUnits(balance, 18));
  

    const openQuoteSignValue = {
      isLong: true,
      bOracleId: 0,
      price: ethers.parseUnits("50", 18),
      amount: ethers.parseUnits("10", 18),
      interestRate: ethers.parseUnits("1", 17),
      isAPayingAPR: true,
      frontEnd: await signers[0].getAddress(),
      affiliate: await signers[0].getAddress(),
      authorized: await signers[1].getAddress(),
      nonce: 0
    };
    
    const bOracleSignValue = {
      x: "0x20568a84796e6ade0446adfd2d8c4bba2c798c2af0e8375cc3b734f71b17f5fd" ,
      parity: 0,
      maxConfidence: ethers.parseUnits("1", 18),
      assetHex : convertToBytes32("forex.EURUSD/forex.GBPUSD"),
      maxDelay: 600,
      precision: 5,
      imA: ethers.parseUnits("10", 16),
      imB: ethers.parseUnits("10", 16),
      dfA: ethers.parseUnits("25", 15),
      dfB: ethers.parseUnits("25", 15),
      expiryA: 60,
      expiryB: 60,
      timeLock:  1440 * 30 * 3 ,
      signatureHashOpenQuote: openQuoteSignature,
      nonce: 0
    };

    
    const sign = signQuote(
      await signers[0].getAddress(), 
      true, 
      0, 
      ethers.parseUnits("50", 18), 
      ethers.parseUnits("10", 18), 
      ethers.parseUnits("1", 17), 
      true, 
      await signers[1].getAddress(), await signers[1].getAddress(), 
      await signers[1].getAddress(), 0)
    await pionerV1Compliance.deposit(mintAmount, 1, await signers[1].getAddress());



    // Fetch all FakeUSD events
    const transferEvents = await fakeUSD.queryFilter("Transfer", -1);
    console.log("FakeUSD Transfer events:");
    transferEvents.forEach((event) => {
      console.log("From:", event.args.from);
      console.log("To:", event.args.to);
      console.log("Value:", ethers.formatUnits(event.args.value, 18));
      console.log("----");
    });

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});