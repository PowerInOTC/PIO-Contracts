const { configs, getAllEvents } = require("./config");
const ethers = require("ethers");

const domainOpen = {
  name: "PionerV1Open",
  version: "1.0",
  chainId: configs.sonic.network.chainId,
  verifyingContract: configs.sonic.contracts.pionerV1Open.address,
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

const domainWarper = {
  name: "PionerV1Warper",
  version: "1.0",
  chainId: configs.sonic.network.chainId,
  verifyingContract: configs.sonic.contracts.pionerV1Warper.address,
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

const domainClose = {
  name: "PionerV1Close",
  version: "1.0",
  chainId: configs.sonic.network.chainId,
  verifyingContract: configs.sonic.contracts.pionerV1Warper.address,
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

async function openQuoteSign(signer, openQuoteSignValue) {
  const openQuoteSignature = await signer.signTypedData(
    domainOpen,
    openQuoteSignType,
    openQuoteSignValue
  );
  return openQuoteSignature;
}

async function bOracleSign(signer, bOracleSignValue) {
  const signaturebOracleSign = await signer.signTypedData(
    domainWarper,
    bOracleSignType,
    bOracleSignValue
  );
  return signaturebOracleSign;
}

async function closeQuoteSign(signer, closeQuoteSign) {
  const signatureCloseQuoteSign = await signer.signTypedData(
    domainWarper,
    closeQuoteSign,
    acceptCloseQuoteValue
  );
  return signatureCloseQuoteSign;
}

const transactionQueue = [];

function addTx(chainId, signerIndex, functionName, ...args) {
  transactionQueue.push({ chainId, signerIndex, functionName, args });
}

async function sendTx() {
  const txPromises = transactionQueue.map(
    async ({ chainId, signerIndex, functionName, args }) => {
      const signer = configs[chainId].signers[signerIndex];
      const [namespace, func] = functionName.split(".");
      if (namespace === "v1") {
        const contractName = configs[chainId].functions[func];
        const contractInstance =
          configs[chainId].contracts[contractName].instance;
        return contractInstance.connect(signer)[func](...args);
      } else {
        return signer[functionName];
      }
    }
  );

  await Promise.all(txPromises);
  console.log("Transactions sent successfully");

  // Clear the transaction queue
  transactionQueue.length = 0;
}

const signers = {};
for (const chainId in configs) {
  signers[chainId] = configs[chainId].signers;
}

async function main() {
  const mintAmount = ethers.parseUnits("10000", 18);

  // Add mint, approve, and deposit transactions to the queue for the "sonic" chain
  addTx("sonic", 0, "v1.mint", mintAmount);
  addTx("sonic", 1, "v1.mint", mintAmount);
  await sendTx();

  addTx(
    "sonic",
    0,
    "v1.approve",
    configs.sonic.contracts.pionerV1Compliance.address,
    mintAmount
  );
  addTx(
    "sonic",
    1,
    "v1.approve",
    configs.sonic.contracts.pionerV1Compliance.address,
    mintAmount
  );
  await sendTx();

  addTx("sonic", 0, "v1.deposit", mintAmount, 1, signers["sonic"][0].address);
  addTx("sonic", 1, "v1.deposit", mintAmount, 1, signers["sonic"][1].address);
  await sendTx();

  const gasAmount = ethers.parseEther("1");
  addTx("sonic", 0, "sendTransaction", {
    to: signers["sonic"][1].address,
    value: gasAmount,
  });
  await sendTx();

  const openQuoteSignValue = {
    isLong: true,
    bOracleId: 0,
    price: ethers.parseUnits("50", 18),
    amount: ethers.parseUnits("10", 18),
    interestRate: ethers.parseUnits("1", 17),
    isAPayingAPR: true,
    frontEnd: signers["sonic"][1].address,
    affiliate: signers["sonic"][1].address,
    authorized: signers["sonic"][2].address,
    nonce: 0,
  };

  const bOracleSignValue = {
    x: "0x20568a84796e6ade0446adfd2d8c4bba2c798c2af0e8375cc3b734f71b17f5fd",
    parity: 0,
    maxConfidence: ethers.parseUnits("1", 18),
    assetHex: ethers.encodeBytes32String("forex.EURUSD/forex.GBPUSD"),
    maxDelay: 600,
    precision: 5,
    imA: ethers.parseUnits("10", 16),
    imB: ethers.parseUnits("10", 16),
    dfA: ethers.parseUnits("25", 15),
    dfB: ethers.parseUnits("25", 15),
    expiryA: 60,
    expiryB: 60,
    timeLock: 1440 * 30 * 3,
    signatureHashOpenQuote: "",
    nonce: 0,
  };

  // from API
  const openQuoteSignature = await openQuoteSign(
    signers["sonic"][1],
    openQuoteSignValue
  );
  bOracleSignValue.signatureHashOpenQuote = openQuoteSignature;
  const signaturebOracleSign = await bOracleSign(
    signers["sonic"][1],
    bOracleSignValue
  );

  //Hedger
  const _acceptPrice = ethers.parseUnits("50", 18);
  await configs.sonic.contracts.pionerV1Warper.instance
    .connect(signers["sonic"][2])
    .warperOpenQuoteMM(
      bOracleSignValue,
      signaturebOracleSign,
      openQuoteSignValue,
      openQuoteSignature,
      _acceptPrice
    );

  // User
  const closeQuoteValue = {
    bContractId: _bContractId,
    price: ethers.parseUnits("55", 18),
    amount: ethers.parseUnits("10", 18),
    limitOrStop: 0,
    expiry: 60000000000,
    authorized: signers["sonic"][2].address,
    nonce: 0,
  };

  const signatureCloseQuoteSign = await bOracleSign(
    signers["sonic"][1],
    closeQuoteValue
  );

  await configs.sonic.contracts.pionerV1Warper.instance
    .connect(signers["sonic"][2])
    .warperOpenQuoteMM(
      bOracleSignValue,
      signaturebOracleSign,
      openQuoteSignValue,
      openQuoteSignature,
      _acceptPrice
    );

  await configs.sonic.contracts.pionerV1Warper.instance
    .connect(signer2)
    .warperCloseLimitMM(closeQuoteValue, signatureCloseQuoteSign);
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
