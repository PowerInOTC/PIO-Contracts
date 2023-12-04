// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
// LICENSE.txt at : https://www.pioner.io/license

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";

import "hardhat/console.sol";


contract PionerV1ERC20 is ERC20, Ownable {
    using SafeERC20 for IERC20;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender)  {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}

// DF is not taken in collateral, but IM does

contract PionerV1Stable {
    PionerV1 private pnr;
    PionerV1Compliance private kyc;

    constructor(address _pionerV1, address _pionerV1Compliance) {
        pnr = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
    }
    event TokenCreated(address indexed tokenAddress);
    event LiquidationTriggered(address indexed account, uint256 amountBurned);


    function createToken(string memory name, string memory symbol, uint256 bOracleId) public {
        require( pnr.getAccountToToken(msg.sender) == address(0));
        PionerV1ERC20 newToken = new PionerV1ERC20(name, symbol);
        newToken.transferOwnership(address(this));
        pnr.setbOracleIdStable(msg.sender, bOracleId);
        pnr.setAccountToToken(msg.sender, address(newToken));
        emit TokenCreated(address(newToken));
    }


    function mintToken(uint256 amount) public {
        require(pnr.getBalance(msg.sender) + kyc.getMintValue(msg.sender) >= pnr.getMintedAmounts(msg.sender) + amount, "TokenFactory: Insufficient magic balance for minting");
        PionerV1ERC20 token = PionerV1ERC20(pnr.getAccountToToken(kyc.getKycAddress(msg.sender)));
        token.mint(msg.sender, amount);
        pnr.addMintedAmounts(msg.sender, amount);
    }


    function burnToken(uint256 amount) public {
        PionerV1ERC20 token = PionerV1ERC20(pnr.getAccountToToken(kyc.getKycAddress(msg.sender)));
        require( amount <= pnr.getMintedAmounts(msg.sender) );
        require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        token.burn(msg.sender, amount);
        pnr.removeMintedAmounts(msg.sender, amount);
    }

}

// balance + im - minted > 0 mint liquidation
// balance - minted > 0 position liquidation

// owed need stable to transform it in usd

// modify withdraw

// open quote im + balance

// settle/setbalance only balance