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

module.exports = {
  convertToBytes32,
  reverseConvertToBytes32,
};
