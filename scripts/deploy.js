const hre = require("hardhat");
const { ethers } = require("hardhat");
const { sendMessage } = require("./telegram");

async function deployContract(
  contractName,
  deployer,
  nonce,
  args = [],
  libraries = {}
) {
  const ContractFactory = await hre.ethers.getContractFactory(contractName, {
    libraries,
  });
  const contract = await ContractFactory.connect(deployer).deploy(...args, {
    nonce,
  });
  await contract.waitForDeployment();
  console.log(`${contractName} deployed to:`, contract.target);
  return contract;
}

async function main() {
  const [owner, addr1, addr2, addr3] = await hre.ethers.getSigners();
  let nonce = await owner.getNonce();

  const schnorrSECP256K1VerifierV2 = await deployContract(
    "SchnorrSECP256K1VerifierV2",
    owner,
    nonce++
  );
  const muonClientBase = await deployContract("MuonClientBase", owner, nonce++);
  const pionerV1Utils = await deployContract("PionerV1Utils", owner, nonce++);
  const fakeUSD = await deployContract("fakeUSD", owner, nonce++);

  const pionerV1 = await deployContract("PionerV1", owner, nonce++, [], {
    PionerV1Utils: pionerV1Utils.target,
  });
  const pionerV1Compliance = await deployContract(
    "PionerV1Compliance",
    owner,
    nonce++,
    [pionerV1.target]
  );
  const pionerV1Open = await deployContract("PionerV1Open", owner, nonce++, [
    pionerV1.target,
    pionerV1Compliance.target,
  ]);
  const pionerV1Close = await deployContract(
    "PionerV1Close",
    owner,
    nonce++,
    [pionerV1.target, pionerV1Compliance.target],
    { PionerV1Utils: pionerV1Utils.target }
  );
  const pionerV1Default = await deployContract(
    "PionerV1Default",
    owner,
    nonce++,
    [pionerV1.target, pionerV1Compliance.target],
    { PionerV1Utils: pionerV1Utils.target }
  );
  const pionerV1View = await deployContract("PionerV1View", owner, nonce++, [
    pionerV1.target,
    pionerV1Compliance.target,
  ]);
  const pionerV1Oracle = await deployContract(
    "PionerV1Oracle",
    owner,
    nonce++,
    [pionerV1.target, pionerV1Compliance.target]
  );
  const pionerV1Wrapper = await deployContract(
    "PionerV1Wrapper",
    owner,
    nonce++,
    [
      pionerV1.target,
      pionerV1Compliance.target,
      pionerV1Open.target,
      pionerV1Close.target,
      pionerV1Default.target,
      pionerV1Oracle.target,
    ]
  );

  const _daiAddress = fakeUSD.target;
  const _min_notional = ethers.parseUnits("25", 10);
  const _frontend_share = ethers.parseUnits("3", 17);
  const _affiliation_share = ethers.parseUnits("3", 17);
  const _hedger_share = ethers.parseUnits("5", 16);
  const _pioner_dao_share = ethers.parseUnits("4", 17);
  const _total_share = ethers.parseUnits("3", 17);
  const _default_auction_period = 30;
  const _cancel_time_buffer = 30;
  const _max_open_positions = 100000;
  const _grace_period = 300;
  const _pioner_dao = owner.address;
  const _admin = owner.address;

  // Set contract addresses in PionerV1
  await pionerV1.setContactAddress(
    _daiAddress,
    _min_notional,
    _frontend_share,
    _affiliation_share,
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
    pionerV1Wrapper.target,
    { nonce: nonce++ }
  );
  console.log("PionerV1 contract addresses set");

  console.log(`"contracts": {"FakeUSD" : "${fakeUSD.target}",
    "PionerV1": "${pionerV1.target}", 
    "PionerV1Compliance": "${pionerV1Compliance.target}", 
    "PionerV1Open": "${pionerV1Open.target}", 
    "PionerV1Close": "${pionerV1Close.target}", 
    "PionerV1Default": "${pionerV1Default.target}", 
    "PionerV1View": "${pionerV1View.target}", 
    "PionerV1Oracle": "${pionerV1Oracle.target}", 
    "PionerV1Wrapper": "${pionerV1Wrapper.target}"}`);

  sendMessage(`contracts: {
    FakeUSD : '${fakeUSD.target}',
    PionerV1: '${pionerV1.target}', 
    PionerV1Compliance: '${pionerV1Compliance.target}', 
    PionerV1Open: '${pionerV1Open.target}', 
    PionerV1Close: '${pionerV1Close.target}', 
    PionerV1Default: '${pionerV1Default.target}', 
    PionerV1View: '${pionerV1View.target}', 
    PionerV1Oracle: '${pionerV1Oracle.target}', 
    PionerV1Wrapper: '${pionerV1Wrapper.target}'
  }`);

  console.log("Deployment completed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
