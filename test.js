const ethers = require("ethers");
const fs = require("fs");
const { configs, getAllEvents } = require('./config');

async function signAndOpenQuote(pionerChainId, signer1, signer2, openQuoteSignValue, bOracleSignValue) {
  const config = configs[pionerChainId];
  const pionerV1Open = config.contracts.pionerV1Open.instance;
  const pionerV1Warper = config.contracts.pionerV1Warper.instance;

  const domainOpen = {
    name: 'PionerV1Open',
    version: '1.0',
    chainId: config.network.chainId,
    verifyingContract: pionerV1Open.address
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
      { name: 'nonce', type: 'uint256' }
    ]
  };

  const openQuoteSignature = await ethers.utils._signTypedData(
    signer1._signingKey(),
    { data: domainOpen },
    openQuoteSignType,
    openQuoteSignValue
  );

  const domainWarper = {
    name: 'PionerV1Warper',
    version: '1.0',
    chainId: config.network.chainId,
    verifyingContract: pionerV1Warper.address
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
      { name: 'nonce', type: 'uint256' }
    ]
  };

  const signaturebOracleSign = await ethers.utils._signTypedData(
    signer1._signingKey(),
    { data: domainWarper },
    bOracleSignType,
    bOracleSignValue
  );

  const _acceptPrice = ethers.parseUnits("50", 18);

  await pionerV1Warper.connect(signer2).warperOpenQuoteMM(
    bOracleSignValue,
    signaturebOracleSign,
    openQuoteSignValue,
    openQuoteSignature,
    _acceptPrice
  );
}


async function main() {



  // Input parameters for signAndOpenQuote function
  const pionerChainId = 'sonic';
  const signer1 = configs.sonic.signers[0];
  const signer2 = configs.sonic.signers[1];

  const openQuoteSignValue = {
    isLong: true,
    bOracleId: 0,
    price: ethers.parseUnits("50", 18),
    amount: ethers.parseUnits("10", 18),
    interestRate: ethers.parseUnits("1", 17),
    isAPayingAPR: true,
    frontEnd: signer1.address,
    affiliate: signer1.address,
    authorized: signer2.address,
    nonce: 0
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
    signatureHashOpenQuote: "", // Leave empty, will be filled in by the function
    nonce: 0
  };

  // Call the signAndOpenQuote function with the provided parameters
  await signAndOpenQuote(pionerChainId, signer1, signer2, openQuoteSignValue, bOracleSignValue);

  const allEvents = await getAllEvents(['sonic'], 0, 'latest');
  console.log('All Events:', allEvents.sonic.pionerV1Compliance.DepositEvent);

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});