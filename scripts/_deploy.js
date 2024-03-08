const hre = require("hardhat");

const { ethers } = require("hardhat");


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


  const SchnorrSECP256K1VerifierV2 = await hre.ethers.getContractFactory("SchnorrSECP256K1VerifierV2");
  const schnorrSECP256K1VerifierV2 = await SchnorrSECP256K1VerifierV2.deploy();
  await schnorrSECP256K1VerifierV2.waitForDeployment();

  // Deploy MuonClientBase
  const MuonClientBase = await hre.ethers.getContractFactory("MuonClientBase");
  const muonClientBase = await MuonClientBase.deploy();
  await muonClientBase.waitForDeployment();

  // Deploy PionerV1Utils
  const PionerV1Utils = await hre.ethers.getContractFactory("PionerV1Utils");
  const pionerV1Utils = await PionerV1Utils.deploy();
  await pionerV1Utils.waitForDeployment();

  // Deploy FakeUSD
  const FakeUSD = await hre.ethers.getContractFactory("fakeUSD");
  const fakeUSD = await FakeUSD.deploy();
  await fakeUSD.waitForDeployment();

  // Deploy PionerV1
  const PionerV1 = await hre.ethers.getContractFactory("PionerV1", {libraries: {PionerV1Utils: pionerV1Utils.target,},});
  const pionerV1 = await PionerV1.deploy();
  await pionerV1.waitForDeployment();
  // Deploy PionerV1Compliance
  const PionerV1Compliance = await hre.ethers.getContractFactory("PionerV1Compliance");
  const pionerV1Compliance = await PionerV1Compliance.deploy(pionerV1.target);
  await pionerV1Compliance.waitForDeployment();
  // Deploy PionerV1Open
  const PionerV1Open = await hre.ethers.getContractFactory("PionerV1Open");

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

  // Deploy PionerV1View
  const PionerV1View = await hre.ethers.getContractFactory("PionerV1View");
  const pionerV1View = await PionerV1View.deploy(pionerV1.target, pionerV1Compliance.target);
  await pionerV1View.waitForDeployment();

  // Deploy PionerV1Oracle
  const PionerV1Oracle = await hre.ethers.getContractFactory("PionerV1Oracle");
  const pionerV1Oracle = await PionerV1Oracle.deploy(pionerV1.target, pionerV1Compliance.target);
  await pionerV1Oracle.waitForDeployment();

  // Deploy PionerV1Default
  const PionerV1Warper = await hre.ethers.getContractFactory("PionerV1Warper");
  const pionerV1Warper = await PionerV1Warper.deploy(pionerV1.target, pionerV1Compliance.target, pionerV1Open.target ,pionerV1Close.target ,pionerV1Default.target, pionerV1Oracle.target);
  await pionerV1Warper.waitForDeployment();

  _daiAddress = fakeUSD.target ;
  _min_notional = ethers.parseUnits("25", 18) ;
  _frontend_share = ethers.parseUnits("3", 17) ;
  _affiliation_share = ethers.parseUnits("3", 17) ;
  _hedger_share = ethers.parseUnits("5", 16) ;
  _pioner_dao_share = ethers.parseUnits("4", 17) ;
  _total_share = ethers.parseUnits("3", 17) ;
  _default_auction_period = 30 ;
  _cancel_time_buffer = 30 ;
  _max_open_positions = 100 ;
  _grace_period = 300 ; 
  _pioner_dao = owner.address ;
  _admin = owner.address ;

  await verifyContract(pionerV1Utils.target, []);
  await verifyContract(fakeUSD.target, []);
  await verifyContract(pionerV1.target, []);
  await verifyContract(pionerV1Compliance.target, [pionerV1.target]);
  await verifyContract(pionerV1Open.target, [pionerV1.target, pionerV1Compliance.target]);
  await verifyContract(pionerV1Close.target, [pionerV1.target, pionerV1Compliance.target]);
  await verifyContract(pionerV1Default.target, [pionerV1.target, pionerV1Compliance.target]);
  await verifyContract(pionerV1View.target, [pionerV1.target, pionerV1Compliance.target]);
  await verifyContract(pionerV1Oracle.target, [pionerV1.target, pionerV1Compliance.target]);
  await verifyContract(pionerV1Warper.target, [pionerV1.target, pionerV1Compliance.target, pionerV1Open.target ,pionerV1Close.target ,pionerV1Default.target, pionerV1Oracle.target]);


  // Set contract addresses in PionerV1
  await pionerV1.setContactAddress(
    _daiAddress ,
    _min_notional ,
    _frontend_share ,
    _affiliation_share ,
    _hedger_share,
    _pioner_dao_share,
    _total_share,
    _default_auction_period,
    _cancel_time_buffer,
    _max_open_positions,
    _grace_period,
    owner.address,
    owner.address,
    pionerV1Open.target,
    pionerV1Close.target,
    pionerV1Default.target,
    pionerV1Compliance.target,
    pionerV1Oracle.target, 
    pionerV1Warper.target
  );

  console.log("const FakeUSDAddress = ^", fakeUSD.target, "^");
  console.log("const PionerV1Address = ^", pionerV1.target, "^");
  console.log("const PionerV1ComplianceAddress = ^", pionerV1Compliance.target, "^");
  console.log("const PionerV1OpenAddress = ^", pionerV1Open.target, "^");
  console.log("const PionerV1CloseAddress = ^", pionerV1Close.target, "^");
  console.log("const PionerV1DefaultAddress = ^", pionerV1Default.target, "^");
  console.log("const PionerV1ViewAddress = ^", pionerV1View.target, "^"); 
  console.log("const PionerV1OracleAddress = ^", pionerV1Oracle.target, "^"); 
  console.log("const PionerV1WarperAddress = ^", pionerV1Warper.target, "^"); 

  /*
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

  await pionerV1Compliance.connect(addr1).deposit(ethers.parseUnits("10000", 18), 1, addr1);
  await pionerV1Compliance.connect(addr2).deposit(ethers.parseUnits("10000", 18), 1, addr2);
  await pionerV1Compliance.connect(addr3).deposit(ethers.parseUnits("10000", 18), 1, addr3);
  await pionerV1Compliance.connect(owner).deposit(ethers.parseUnits("10000", 18), 1, owner);
*/

  console.log("Deployement completed !");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
