const hre = require("hardhat");

async function main() {
  const accounts = await hre.ethers.getSigners();


    // Deploy FakeUSD
    const FakeUSD = await ethers.getContractFactory("fakeUSD", accounts[0]);
    const fakeUSD = await FakeUSD.deploy();
    await fakeUSD.deployed();
    console.log("FakeUSD deployed to:", fakeUSD.address);

    // Deploy PionerV1 with constructor arguments
    const PionerV1 = await ethers.getContractFactory("PionerV1", accounts[0]);
    const pionerV1 = await PionerV1.deploy(
        fakeUSD.address, // Assuming 'target' should be the contract address
        ethers.utils.parseUnits("25", 18),
        ethers.utils.parseUnits("3", 17),
        ethers.utils.parseUnits("2", 17),
        ethers.utils.parseUnits("1", 17),
        ethers.utils.parseUnits("4", 17),
        ethers.utils.parseUnits("2", 17),
        20,
        20,
        100,
        300,
        owner.address,
        owner.address
    );
    await pionerV1.deployed();
    console.log("PionerV1 deployed to:", pionerV1.address);

    // Deposit tokens for addr3
    const mintAmount = ethers.utils.parseUnits("10000", 18);
    await depositTokens(fakeUSD, pionerV1, accounts[0], mintAmount);
    await depositTokens(fakeUSD, pionerV1, accounts[1], mintAmount);
    await depositTokens(fakeUSD, pionerV1, accounts[2], mintAmount);
    await depositTokens(fakeUSD, pionerV1, accounts[3], mintAmount);

    console.log("Deployment and initialization complete");
}


async function depositTokens(token, contract, account, amount) {
    await token.mint(account.address, amount);
    await token.connect(account).approve(contract.address, amount);
    await contract.connect(account).deposit(amount);
}

// Handle async/await and errors
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});