const hre = require("hardhat");

async function main() {
  const [owner, addr1, addr2, addr3] = await hre.ethers.getSigners();
  
  const PionerV1UtilsAddress = "0x40F62fde4AfbD69Fa6bD88e5d9f81acc829F7fA3"
  const FakeUSDAddress = "0xbae8Aa70a95b01F65576777aB4a5347B1f2fAa54"
  const PionerV1Address = "0x6655165a06985be6affc4F9A296A8c7F68a79b66"
  const PionerV1ComplianceAddress = "0xF02C79B33975f4bf82FCbaAE1d0Cd36A19552DC9"
  const PionerV1OpenAddress = "0xd3209eC0f12486EC108Ed467E136330c227938D4"
  const PionerV1CloseAddress = "0x1Ef2D695bB0eE1c5889Ff3d867b69Cd1CaaA92df"
  const PionerV1DefaultAddress = "0x833bC52C336bB3F259c4043da9CA1CB66D7aD7ad"
  const PionerV1StableAddress = "0xFFeD4280bDD04941193EaFDf25b06f4aEC622cF6"
  const PionerV1ViewAddress = "0x80820c8cdd9aCdbE2f899308F61ecbeA1174524C"

  const PionerV1Utils = await hre.ethers.getContractFactory("PionerV1Utils");
  const pionerV1Utils = PionerV1Utils.attach(PionerV1UtilsAddress);

  const PionerV1 = await hre.ethers.getContractFactory("PionerV1", {libraries: {PionerV1Utils: pionerV1Utils.target,},});
  const pionerV1 = PionerV1.attach(PionerV1Address);

  const PionerV1Open = await hre.ethers.getContractFactory("PionerV1Open", {libraries: {PionerV1Utils: pionerV1Utils.target,},});
  const pionerV1Open = PionerV1Open.attach(PionerV1OpenAddress);

  const PionerV1Close = await hre.ethers.getContractFactory("PionerV1Close", {libraries: {PionerV1Utils: pionerV1Utils.target,},});
  const pionerV1Close = PionerV1Close.attach(PionerV1CloseAddress);

  await pionerV1Open.connect(addr1).wrapperOpenQuoteSwap( true, ethers.parseUnits("50", 18), ethers.parseUnits("10", 18), ethers.parseUnits("50", 16), true
  , "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C", "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C", "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C", "0x2167ece6ee3201b7b61f4cdc17bf2e874ca6ad850c390ba2c5a76d703a1b8cd2", "0xc2dec53d44e1fcc69b96f72c2d0a73080c328a0c6ac74bac9f575e7afbf6884b"
  , 60000, ethers.parseUnits("10", 16), ethers.parseUnits("10", 16), ethers.parseUnits("25", 15), ethers.parseUnits("25", 15), 1440 * 30 * 3, 1440 * 30 * 3, 1440 * 30 * 3 )
  await pionerV1Open.connect(addr2).acceptQuote(0, ethers.parseUnits("50", 18), "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C") 
  await pionerV1Close.connect(addr1).openCloseQuote( [0], [ethers.parseUnits("50", 18)], [ethers.parseUnits("10", 18)], [0], [60000000000] )


}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
