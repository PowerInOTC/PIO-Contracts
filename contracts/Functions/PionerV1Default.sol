// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.20;

import "./PionerV1.sol";
import "./PionerV1Compliance.sol";

import "hardhat/console.sol";

import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";



/**
 * @title PionerV1 Default
 * @dev This contract manage liquidations and settlement function
 * @notice This contract is not audited
 * @author Microderiv
 */


contract PionerV1Default {
    PionerV1 private pio;
    PionerV1Compliance private kyc;

    event settledEvent(uint256 bContractId);
    event liquidatedEvent(uint256 bContractId);
    event flashAuctionBuyBackEvent(uint256 bContractId);

    constructor(address _pionerV1, address _pionerV1Compliance) {
        pio = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
    }



    function settleAndLiquidate(uint256 bContractId) public {
        uint256 paid;bool liquidated;uint256 balance;
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        require(kyc.getKycType(msg.sender) != 6, "Default21a");
        require(bC.state == 2, "Default21b");
        require(bO.lastPriceUpdateTime + bO.maxDelay >= block.timestamp, "Default22");
        
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl(bC.price, bO.lastPrice, bC.amount, bC.interestRate, bC.openTime, bC.isAPayingAPR);
        // loser is the one paying sponsor since trade haven't been settled on his side
        uPnl += pio.paySponsor(msg.sender, bC.pA, bC.price, bO.lastPrice, bO.imA);
        uint256 deltaImA = utils.dynamicIm(bC.price, bO.lastPrice, bC.amount, bO.imA, bO.dfA);
        uint256 deltaImB = utils.dynamicIm(bC.price, bO.lastPrice, bC.amount, bO.imB, bO.dfB); 
        require(bC.price * bC.amount >= 1e18, "Default:UnderflowCheck2");
        uint256 notional = bC.price * bC.amount / 1e18;

        
        if (isNegative) { // deltaIm down      
            balance = pio.getBalance(bC.pA);
            if (uPnl > deltaImA) {
                balance = pio.getBalance(bC.pA);
                if (balance < uPnl - deltaImA) {
                    paid = pio.setBalance(uPnl, bC.pA, bC.pB, false, false);
                    liquidated = true;
                }
                else if ( balance > uPnl - deltaImA) {
                    paid = pio.setBalance(uPnl - deltaImA, bC.pA, bC.pB, false, false);
                    if (paid != uPnl - deltaImA) { liquidated = true; }
                 } else {
                    paid = pio.setBalance(balance, bC.pA, bC.pB, false, false);
                    if (paid != uPnl - deltaImA) { liquidated = true; }
                 }
            } else {
                paid = pio.setBalance(deltaImA - uPnl, bC.pA, address(0), true, false);
            }
            if (liquidated) { // liquidate
                // distribute defaulter df
                pio.payLiquidationShare(bO.dfA * notional /1e18, bC.pB);
                uint256 availableFunds = paid + (bO.imA * notional / 1e18);
                if (availableFunds >= uPnl) {
                    uint256 toBParty = uPnl + (bO.dfB + bO.imB ) * notional / 1e18 ;
                    pio.setBalance(toBParty, bC.pB, address(0), true, false);
                    pio.addBalance(bC.pA, availableFunds - uPnl);
                } else {
                    uint256 toBParty = availableFunds +  (bO.dfB + bO.imB ) * notional / 1e18 ;
                    pio.setBalance(toBParty, bC.pB, address(0), true, false);
                    pio.addToOwed(uPnl - availableFunds, bC.pA, bC.pB);
                }
                bC.initiator = bC.pA;
                bC.state = 4;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pio.decreaseOpenPositionNumber(bC.pB);
                pio.decreaseOpenPositionNumber(bC.pA);
                emit liquidatedEvent(bContractId);
            } else { // settle
                pio.setBalance(uPnl + deltaImB, bC.pB, address(0), true, false);
                bC.price = bO.lastPrice;
                bC.openTime = bO.lastPriceUpdateTime;
                emit settledEvent(bContractId);
            }
        } else { // deltaIm up
            balance = pio.getBalance(bC.pB);
            if (balance < uPnl + deltaImB) {
                paid = pio.setBalance(uPnl, bC.pB, bC.pA, false, false);
                liquidated = true;
            }
            else {
                paid = pio.setBalance(uPnl + deltaImB, bC.pB, bC.pA, false, false);
            } 
            if (liquidated) { // liquidate
                // distribute defaulter df
                pio.payLiquidationShare(bO.dfB * notional /1e18, bC.pA);
                uint256 availableFunds = paid + (bO.imB * notional / 1e18);
                if (availableFunds >= uPnl) {
                    uint256 toAParty = uPnl + (bO.dfA + bO.imA ) * notional / 1e18 ;
                    pio.setBalance(toAParty, bC.pA, address(0), true, false);
                    pio.addBalance(bC.pB, availableFunds - uPnl);
                } else {
                    uint256 toAParty = availableFunds +  (bO.dfB + bO.imB ) * notional / 1e18 ;
                    pio.setBalance(toAParty, bC.pA, address(0), true, false);
                    pio.addToOwed(uPnl - availableFunds, bC.pB, bC.pA);
                }

                bC.initiator = bC.pB;
                bC.state = 4;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pio.decreaseOpenPositionNumber(bC.pB);
                pio.decreaseOpenPositionNumber(bC.pA);
                emit liquidatedEvent(bContractId);
            } else { // settle
                require(uPnl >= deltaImA, "Default:UnderflowCheck12");
                pio.setBalance(uPnl - deltaImA, bC.pA, address(0), true, false);
                bC.price = bO.lastPrice;
                bC.openTime = bO.lastPriceUpdateTime;
                emit settledEvent(bContractId);
            }
        }
        pio.updateCumIm(bO, bC, bContractId);
        pio.setBContract(bContractId, bC);

    }

  
}