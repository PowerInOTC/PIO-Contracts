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

  const PionerV1Compliance = await hre.ethers.getContractFactory("PionerV1Compliance");
  const pionerV1Compliance = PionerV1Compliance.attach(PionerV1ComplianceAddress);

  const FakeUSD = await hre.ethers.getContractFactory("fakeUSD");
  const fakeUSD = FakeUSD.attach(FakeUSDAddress);

  await fakeUSD.connect(owner).mint(ethers.parseUnits("10000", 18));
  await fakeUSD.connect(addr1).mint(ethers.parseUnits("10000", 18));
  await fakeUSD.connect(addr2).mint(ethers.parseUnits("10000", 18));
  await fakeUSD.connect(addr3).mint(ethers.parseUnits("10000", 18));
  console.log("FakeUSD minted to addresses");

  await fakeUSD.connect(addr1).approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));
  await fakeUSD.connect(addr2).approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));
  await fakeUSD.connect(addr3).approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));
  await fakeUSD.connect(owner).approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));

  for (let addr of [owner, addr1, addr2, addr3]) {
    const balance = await fakeUSD.balanceOf(addr);
    const formattedBalance = hre.ethers.formatUnits(balance, 18);
    console.log(`Balance of ${addr.address}: ${formattedBalance} FakeUSD`);

    const allowance = await fakeUSD.allowance(addr.address, PionerV1ComplianceAddress);
    const formattedAllowance = hre.ethers.formatUnits(allowance, 18);
    console.log(`Allowance of ${PionerV1ComplianceAddress} from ${addr.address}: ${formattedAllowance} FakeUSD`);
  }

  /*await pionerV1Compliance.connect(owner).deposit(hre.ethers.parseUnits("10000", 18), 9, owner);
  await pionerV1Compliance.connect(addr2).deposit(hre.ethers.parseUnits("10000", 18), 9, addr2);
  await pionerV1Compliance.connect(addr3).deposit(hre.ethers.parseUnits("10000", 18), 9, addr3);
  await pionerV1Compliance.connect(addr1).deposit(hre.ethers.parseUnits("10000", 18), 9, addr1);*/
  await pionerV1Compliance.connect(owner).deposit(hre.ethers.parseUnits("10000", 18));
  await pionerV1Compliance.connect(addr2).deposit(hre.ethers.parseUnits("10000", 18));
  await pionerV1Compliance.connect(addr3).deposit(hre.ethers.parseUnits("10000", 18));
  await pionerV1Compliance.connect(addr1).deposit(hre.ethers.parseUnits("10000", 18));

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
