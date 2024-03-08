const hre = require("hardhat");

async function main() {
  const [owner, addr1, addr2, addr3] = await hre.ethers.getSigners();
  
  const PionerV1UtilsAddress = "0xb400785D741F8815c657A03Eebb04944eb7D7b9C"
  const FakeUSDAddress = "0x60a75B099Fe78Cb7Fad097bF2C082c467686ecd5"
  const PionerV1Address = "0xEA0224877722d59aef9c16aafD83d132634bDaC1"
  const PionerV1ComplianceAddress = "0xD6C07Ed68941B2B75c7A42008C446DDf67795ecf"
  const PionerV1OpenAddress = "0x4549500cb81DDA59fF8cB21b7b77C630181cDFA5"
  const PionerV1CloseAddress = "0x8Fe0bcCAFA648b093C448ed8Bb732F65Cef734c2"
  const PionerV1DefaultAddress = "0x91570188747272F90DFF014def0109B399b7d63f"
  const PionerV1ViewAddress = "0xc11f825fF2A7Ac7bD4F4B28bDEdbbFA5BaeEC0D9"
  const PionerV1OracleAddress = "0xf447AbDcADC871EF6E366f26DBA663bACE45dD5d"
  const PionerV1WarperAddress = "0x3941DdF936ffe2de5Cd3648ac5ee2c0F8C171A67"

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
