const hre = require("hardhat");

async function main() {
  const [owner, addr1, addr2, addr3] = await hre.ethers.getSigners();

  const FakeUSDAddress = "0x9B9Ad3ee47E83F3A8DdAC46D572C7EccC44Dd366";
  const PionerV1ComplianceAddress =
    "0x537CFf880B0c2217f7fdE823A3560f908543fE8D";
  const PionerV1Compliance = await hre.ethers.getContractFactory(
    "PionerV1Compliance"
  );
  const pionerV1Compliance = PionerV1Compliance.attach(
    PionerV1ComplianceAddress
  );

  const FakeUSD = await hre.ethers.getContractFactory("fakeUSD");
  const fakeUSD = FakeUSD.attach(FakeUSDAddress);

  await fakeUSD.connect(owner).mint(ethers.parseUnits("10000", 18));
  await fakeUSD.connect(addr1).mint(ethers.parseUnits("10000", 18));
  await fakeUSD.connect(addr2).mint(ethers.parseUnits("10000", 18));
  console.log("FakeUSD minted to addresses");

  await fakeUSD
    .connect(addr1)
    .approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));
  await fakeUSD
    .connect(addr2)
    .approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));
  await fakeUSD
    .connect(owner)
    .approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));

  for (let addr of [owner, addr1, addr2]) {
    const balance = await fakeUSD.balanceOf(addr);
    const formattedBalance = hre.ethers.formatUnits(balance, 18);
    console.log(`Balance of ${addr.address}: ${formattedBalance} FakeUSD`);

    const allowance = await fakeUSD.allowance(
      addr.address,
      PionerV1ComplianceAddress
    );
    const formattedAllowance = hre.ethers.formatUnits(allowance, 18);
    console.log(
      `Allowance of ${PionerV1ComplianceAddress} from ${addr.address}: ${formattedAllowance} FakeUSD`
    );
  }

  await pionerV1Compliance
    .connect(owner)
    .deposit(hre.ethers.parseUnits("1000000", 18));
  await pionerV1Compliance
    .connect(addr2)
    .deposit(hre.ethers.parseUnits("1000000", 18));
  await pionerV1Compliance
    .connect(addr1)
    .deposit(hre.ethers.parseUnits("1000000", 18));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
