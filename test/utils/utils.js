const Web3 = require('web3');

function convertToBytes32(str) {
  const hex = Web3.utils.toHex(str);
  return Web3.utils.padRight(hex, 64);
}

module.exports = {
  convertToBytes32,
};