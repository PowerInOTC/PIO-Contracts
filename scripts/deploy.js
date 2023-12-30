const hre = require("hardhat");

async function main() {
  const [owner, addr1, addr2, addr3] = await hre.ethers.getSigners();

  async function verifyContract(address, constructorArguments) {
    console.log(`Verifying contract at address ${address}...`);
    try {
      await hre.run("verify:verify", {
        address: address,
        constructorArguments: constructorArguments,
      });
      console.log(`Verified contract at ${address}`);
    } catch (error) {
      console.error(`Error verifying contract at ${address}:`, error);
    }
  }

  console.log("Deploying contracts with the account:", owner.address);

  // Deploy PionerV1Utils
  const PionerV1Utils = await hre.ethers.getContractFactory("PionerV1Utils");
  const pionerV1Utils = await PionerV1Utils.deploy();
  await pionerV1Utils.waitForDeployment();

  // Deploy FakeUSD
  const FakeUSD = await hre.ethers.getContractFactory("fakeUSD");
  const fakeUSD = await FakeUSD.deploy();
  await fakeUSD.waitForDeployment();

  // Deploy PionerV1
  const PionerV1 = await hre.ethers.getContractFactory("PionerV1", {
    libraries: {
      PionerV1Utils: pionerV1Utils.target,
    },
  });
  const pionerV1 = await PionerV1.deploy(
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
  await pionerV1.waitForDeployment();
  // Deploy PionerV1Compliance
  const PionerV1Compliance = await hre.ethers.getContractFactory("PionerV1Compliance");
  const pionerV1Compliance = await PionerV1Compliance.deploy(pionerV1.target);
  await pionerV1Compliance.waitForDeployment();
  // Deploy PionerV1Open
  const PionerV1Open = await hre.ethers.getContractFactory("PionerV1Open", {
    libraries: {
      PionerV1Utils: pionerV1Utils.target,
    },
  });

  const pionerV1Open = await PionerV1Open.deploy(pionerV1.target, pionerV1Compliance.target);
  await pionerV1Open.waitForDeployment();

  // Deploy PionerV1Close
  const PionerV1Close = await hre.ethers.getContractFactory("PionerV1Close", {
    libraries: {
      PionerV1Utils: pionerV1Utils.target,
    },
  });


  const pionerV1Close = await PionerV1Close.deploy(pionerV1.target, pionerV1Compliance.target);
  await pionerV1Close.waitForDeployment();
  // Deploy PionerV1Default
  const PionerV1Default = await hre.ethers.getContractFactory("PionerV1Default", {
    libraries: {
      PionerV1Utils: pionerV1Utils.target,
    },
  });
  const pionerV1Default = await PionerV1Default.deploy(pionerV1.target, pionerV1Compliance.target);
  await pionerV1Default.waitForDeployment();

  // Deploy PionerV1Stable
  const PionerV1Stable = await hre.ethers.getContractFactory("PionerV1Stable");
  const pionerV1Stable = await PionerV1Stable.deploy(pionerV1.target, pionerV1Compliance.target);
  await pionerV1Stable.waitForDeployment();

  // Deploy PionerV1Stable
  const PionerV1View = await hre.ethers.getContractFactory("PionerV1View");
  const pionerV1View = await PionerV1View.deploy(pionerV1.target, pionerV1Compliance.target);
  await pionerV1View.waitForDeployment();

  await verifyContract(pionerV1Utils.target, []);
  await verifyContract(fakeUSD.target, []);
  await verifyContract(pionerV1.target, [
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
  ]);
  await verifyContract(pionerV1Compliance.target, [pionerV1.target]);
  await verifyContract(pionerV1Open.target, [pionerV1.target, pionerV1Compliance.target]);
  await verifyContract(pionerV1Close.target, [pionerV1.target, pionerV1Compliance.target]);
  await verifyContract(pionerV1Default.target, [pionerV1.target, pionerV1Compliance.target]);
  await verifyContract(pionerV1Stable.target, [pionerV1.target, pionerV1Compliance.target]);
  await verifyContract(pionerV1View.target, [pionerV1.target, pionerV1Compliance.target]);


  // Set contract addresses in PionerV1
  await pionerV1.setContactAddress(
    pionerV1Open.target,
    pionerV1Close.target,
    pionerV1Default.target,
    pionerV1Stable.target,
    pionerV1Compliance.target
  );

  console.log("const PionerV1UtilsAddress = ^", pionerV1Utils.target, "^");
  console.log("const FakeUSDAddress = ^", fakeUSD.target, "^");
  console.log("const PionerV1Address = ^", pionerV1.target, "^");
  console.log("const PionerV1ComplianceAddress = ^", pionerV1Compliance.target, "^");
  console.log("const PionerV1OpenAddress = ^", pionerV1Open.target, "^");
  console.log("const PionerV1CloseAddress = ^", pionerV1Close.target, "^");
  console.log("const PionerV1DefaultAddress = ^", pionerV1Default.target, "^");
  console.log("const PionerV1StableAddress = ^", pionerV1Stable.target, "^");
  console.log("const PionerV1ViewAddress = ^", pionerV1View.target, "^"); 

  // Mint FakeUSD tokens to addr1, addr2, and addr3
  await fakeUSD.mint(ethers.parseUnits("10000", 18));
  await fakeUSD.mint(ethers.parseUnits("10000", 18));
  await fakeUSD.mint(ethers.parseUnits("10000", 18));
  await fakeUSD.mint(ethers.parseUnits("10000", 18));
  console.log("FakeUSD minted to addresses");

  // Approve and deposit FakeUSD to PionerV1Compliance for addr1, addr2, and addr3
  await fakeUSD.connect(addr1).approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));
  await fakeUSD.connect(addr2).approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));
  await fakeUSD.connect(addr3).approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));
  await fakeUSD.connect(owner).approve(pionerV1Compliance.target, ethers.parseUnits("10000", 18));

  await pionerV1Compliance.connect(addr1).deposit(ethers.parseUnits("10000", 18), 9, addr1);
  await pionerV1Compliance.connect(addr2).deposit(ethers.parseUnits("10000", 18), 9, addr2);
  await pionerV1Compliance.connect(addr3).deposit(ethers.parseUnits("10000", 18), 9, addr3);
  await pionerV1Compliance.connect(owner).deposit(ethers.parseUnits("10000", 18), 9, owner);
  
  await pionerV1Open.connect(addr1).deployBOracle(
    "0xFC6bd9F9f0c6481c6Af3A7Eb46b296A5B85ed379", "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43", "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a",
    20, 0, ethers.parseUnits("10", 16), ethers.parseUnits("10", 16), ethers.parseUnits("25", 15), ethers.parseUnits("25", 15),
    60, 1440 * 30 * 3, 1440 * 30 * 3, 1440 * 30 * 3 , 0); 

  await pionerV1Open.connect(addr1).deployBOracle(
    "0xFC6bd9F9f0c6481c6Af3A7Eb46b296A5B85ed379", "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a", "0x26e4f737fde0263a9eea10ae63ac36dcedab2aaf629261a994e1eeb6ee0afe53",
    20, 2, ethers.parseUnits("10", 16), ethers.parseUnits("10", 16), ethers.parseUnits("25", 15), ethers.parseUnits("25", 15),
    60, 1440 * 30 * 3, 1440 * 30 * 3, 1440 * 30 * 3 , 0); 

  await pionerV1Open.connect(addr1).openQuote( true,0, ethers.parseUnits("50", 18), ethers.parseUnits("10", 18), ethers.parseUnits("50", 16),
    true, owner,owner ); 
  await pionerV1Open.connect(addr1).openQuote( true,1, ethers.parseUnits("50", 18), ethers.parseUnits("10", 18), ethers.parseUnits("50", 16),
    true, owner,owner ); 

  await pionerV1Open.connect(addr2).acceptQuote(0, ethers.parseUnits("50", 18), owner);
  await pionerV1Open.connect(addr3).acceptQuote(0, ethers.parseUnits("50", 18), owner); 

  console.log("Deposits completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
