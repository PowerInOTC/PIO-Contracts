const Web3 = require("web3");

function convertToBytes32(str) {
  const hex = Web3.utils.toHex(str);
  return Web3.utils.padRight(hex, 64);
}

function reverseConvertToBytes32(hexStr) {
  const hex = Web3.utils.padLeft(hexStr, 64);
  const str = Web3.utils.hexToUtf8(hex);
  return str;
}

async function printBalances(pionerV1, addr1, addr2, addr3, owner) {
  const initialBalanceAddr1 = await pionerV1.getBalance(addr1);
  const initialBalanceAddr2 = await pionerV1.getBalance(addr2);
  const initialBalanceAddr3 = await pionerV1.getBalance(addr3);
  const initialBalanceAddrOwner = await pionerV1.getBalance(owner);
  const owedAmountA = await pionerV1.getOwedAmount(addr1, addr2);
  const owedAmountB = await pionerV1.getOwedAmount(addr2, addr1);
  console.log(
    "balances : ",
    BigInt(initialBalanceAddr1) / BigInt(1e18),
    BigInt(initialBalanceAddr2) / BigInt(1e18),
    BigInt(initialBalanceAddr3) / BigInt(1e18),
    BigInt(owedAmountA) / BigInt(1e18),
    BigInt(owedAmountB) / BigInt(1e18)
  );
}

module.exports = {
  convertToBytes32,
  reverseConvertToBytes32,
  printBalances,
};
