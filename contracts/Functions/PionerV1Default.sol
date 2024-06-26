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

    function settleAndLiquidate1(uint256 bContractId) public{
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        console.log("bC.state", bC.oracleId);
        console.log("bO.lastPriceUpdateTime", bO.lastPrice);  
        console.log("bO.lastPriceUpdateTime", pio.getTotalShare());  
        require(kyc.getKycType(msg.sender) != 6, "Default21a");
        require(bC.state == 2, "Default21b");
        require(bO.lastPriceUpdateTime + bO.maxDelay >= block.timestamp, "Default22");
        
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl(bC.price, bO.lastPrice, bC.amount, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR);
        uint256 ir = utils.calculateIr(bC.interestRate, (block.timestamp - bO.lastPriceUpdateTime), bO.lastPrice, bC.amount);
        uPnl += ir;
        require(block.timestamp >= bO.lastPriceUpdateTime, "Default:UnderflowCheck1");
        
        uint256 deltaImA = utils.dynamicIm(bC.price, bO.lastPrice, bC.amount, bO.imA, bO.dfA);
        uint256 deltaImB = utils.dynamicIm(bC.price, bO.lastPrice, bC.amount, bO.imB, bO.dfB); 
        
        require(bC.price * bC.amount >= 1e18, "Default:UnderflowCheck2");
        uint256 notional = bC.price * bC.amount / 1e18;
        
        uint256 paid;
        bool liquidated;
            
        if (isNegative) { // deltaIm down
            if (uPnl > deltaImA) {
                require(uPnl >= deltaImA, "Default:UnderflowCheck3");
                paid = pio.setBalance(uPnl - deltaImA, bC.pA, bC.pB, false, false);
                if (paid != uPnl - deltaImA) { liquidated = true; }
            } else {
                require(deltaImA >= uPnl, "Default:UnderflowCheck4");
                paid = pio.setBalance(deltaImA - uPnl, bC.pA, address(0), true, false);
            }
            if (liquidated) { // liquidate
                paid += bO.imA * notional / 1e18;
                if (paid > uPnl) {
                    require(paid >= uPnl, "Default:UnderflowCheck5");
                    pio.addBalance(bC.pA, paid - uPnl);
                } else {
                    require(uPnl >= paid, "Default:UnderflowCheck6");
                    pio.addToOwed(uPnl - paid, bC.pA, bC.pB);
                }
                require(1e18 >= pio.getTotalShare(), "Default:UnderflowCheck7");
                uint256 liquidationAmount = paid + (bO.dfB + bO.imB + (bO.dfA * (1e18 - pio.getTotalShare())) / 1e18) * notional / 1e18;
                pio.setBalance(liquidationAmount, bC.pB, address(0), true, false);
                pio.payLiquidationShare((bO.dfA * notional / 1e18) * pio.getTotalShare());
                bC.initiator = bC.pA;
                bC.state = 4;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pio.decreaseOpenPositionNumber(bC.pB);
                pio.decreaseOpenPositionNumber(bC.pA);
                emit liquidatedEvent(bContractId);
            } else { // settle
                pio.payLiquidationShare((bO.dfA * notional / 1e18) * pio.getTotalShare());
                pio.setBalance(uPnl + deltaImB, bC.pB, address(0), true, false);
                pio.paySponsor(msg.sender, bC.pA, bC.price, bO.lastPrice, bO.imA, false);
                bC.price = bO.lastPrice;
                bC.openTime = bO.lastPriceUpdateTime;
                emit settledEvent(bContractId);
            }
        } 
    }


    function settleAndLiquidate2(uint256 bContractId) public{
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        console.log("bC.state", bC.oracleId);
        console.log("bO.lastPriceUpdateTime", bO.lastPrice);  
        console.log("bO.lastPriceUpdateTime", pio.getTotalShare());  
        require(kyc.getKycType(msg.sender) != 6, "Default21a");
        require(bC.state == 2, "Default21b");
        require(bO.lastPriceUpdateTime + bO.maxDelay >= block.timestamp, "Default22");
        
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl(bC.price, bO.lastPrice, bC.amount, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR);
        uint256 ir = utils.calculateIr(bC.interestRate, (block.timestamp - bO.lastPriceUpdateTime), bO.lastPrice, bC.amount);
        uPnl += ir;
        require(block.timestamp >= bO.lastPriceUpdateTime, "Default:UnderflowCheck1");
        
        uint256 deltaImA = utils.dynamicIm(bC.price, bO.lastPrice, bC.amount, bO.imA, bO.dfA);
        uint256 deltaImB = utils.dynamicIm(bC.price, bO.lastPrice, bC.amount, bO.imB, bO.dfB); 
        
        require(bC.price * bC.amount >= 1e18, "Default:UnderflowCheck2");
        uint256 notional = bC.price * bC.amount / 1e18;
        
        uint256 paid;
        bool liquidated;
            
       
    }

    
    function settleAndLiquidate3(uint256 bContractId) public{
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        console.log("bC.state", bC.oracleId);
        console.log("bO.lastPriceUpdateTime", bO.lastPrice);  
        console.log("bO.lastPriceUpdateTime", pio.getTotalShare());  
        require(kyc.getKycType(msg.sender) != 6, "Default21a");
        require(bC.state == 2, "Default21b");
        require(bO.lastPriceUpdateTime + bO.maxDelay >= block.timestamp, "Default22");
     
        bool liquidated;
            
       
    }

    function settleAndLiquidate(uint256 bContractId) public{
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        console.log("bC.state", bC.oracleId);
        console.log("bO.lastPriceUpdateTime", bO.lastPrice);  
        console.log("bO.lastPriceUpdateTime", pio.getTotalShare());  
        require(kyc.getKycType(msg.sender) != 6, "Default21a");
        require(bC.state == 2, "Default21b");
        require(bO.lastPriceUpdateTime + bO.maxDelay >= block.timestamp, "Default22");
        
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl(bC.price, bO.lastPrice, bC.amount, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR);
        uint256 ir = utils.calculateIr(bC.interestRate, (block.timestamp - bO.lastPriceUpdateTime), bO.lastPrice, bC.amount);
        uPnl += ir;
        require(block.timestamp >= bO.lastPriceUpdateTime, "Default:UnderflowCheck1");
        
        uint256 deltaImA = utils.dynamicIm(bC.price, bO.lastPrice, bC.amount, bO.imA, bO.dfA);
        uint256 deltaImB = utils.dynamicIm(bC.price, bO.lastPrice, bC.amount, bO.imB, bO.dfB); 
        
        require(bC.price * bC.amount >= 1e18, "Default:UnderflowCheck2");
        uint256 notional = bC.price * bC.amount / 1e18;
        
        uint256 paid;
        bool liquidated;
            
        if (isNegative) { // deltaIm down
            if (uPnl > deltaImA) {
                require(uPnl >= deltaImA, "Default:UnderflowCheck3");
                paid = pio.setBalance(uPnl - deltaImA, bC.pA, bC.pB, false, false);
                if (paid != uPnl - deltaImA) { liquidated = true; }
            } else {
                require(deltaImA >= uPnl, "Default:UnderflowCheck4");
                paid = pio.setBalance(deltaImA - uPnl, bC.pA, address(0), true, false);
            }
            if (liquidated) { // liquidate
                paid += bO.imA * notional / 1e18;
                if (paid > uPnl) {
                    require(paid >= uPnl, "Default:UnderflowCheck5");
                    pio.addBalance(bC.pA, paid - uPnl);
                } else {
                    require(uPnl >= paid, "Default:UnderflowCheck6");
                    pio.addToOwed(uPnl - paid, bC.pA, bC.pB);
                }
                require(1e18 >= pio.getTotalShare(), "Default:UnderflowCheck7");
                uint256 liquidationAmount = paid + (bO.dfB + bO.imB + (bO.dfA * (1e18 - pio.getTotalShare())) / 1e18) * notional / 1e18;
                pio.setBalance(liquidationAmount, bC.pB, address(0), true, false);
                pio.payLiquidationShare((bO.dfA * notional / 1e18) * pio.getTotalShare());
                bC.initiator = bC.pA;
                bC.state = 4;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pio.decreaseOpenPositionNumber(bC.pB);
                pio.decreaseOpenPositionNumber(bC.pA);
                emit liquidatedEvent(bContractId);
            } else { // settle
                pio.payLiquidationShare((bO.dfA * notional / 1e18) * pio.getTotalShare());
                pio.setBalance(uPnl + deltaImB, bC.pB, address(0), true, false);
                pio.paySponsor(msg.sender, bC.pA, bC.price, bO.lastPrice, bO.imA, false);
                bC.price = bO.lastPrice;
                bC.openTime = bO.lastPriceUpdateTime;
                emit settledEvent(bContractId);
            }
        } else { // deltaIm up
            paid = pio.setBalance(uPnl + deltaImB, bC.pB, bC.pA, false, false);
            if (paid != uPnl + deltaImB) { // liquidate
                if (paid > uPnl) {
                    require(paid >= uPnl, "Default:UnderflowCheck8");
                    paid += (bO.imB * notional / 1e18) + paid - uPnl;
                } else {
                    paid += bO.imB * notional / 1e18;
                }
                if (paid > uPnl) {
                    require(paid >= uPnl, "Default:UnderflowCheck9");
                    pio.addBalance(bC.pB, paid - uPnl);
                } else {
                    require(uPnl >= paid, "Default:UnderflowCheck10");
                    pio.addToOwed(uPnl - paid, bC.pB, bC.pA);
                }
                require(1e18 >= pio.getTotalShare(), "Default:UnderflowCheck11");
                uint256 liquidationAmount = paid + (bO.dfA + bO.imA + (bO.dfB * (1e18 - pio.getTotalShare())) / 1e18) * notional / 1e18;
                pio.setBalance(liquidationAmount, bC.pA, address(0), true, false);
                pio.payLiquidationShare((bO.dfA * notional / 1e18) * pio.getTotalShare());

                bC.initiator = bC.pB;
                bC.state = 4;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pio.decreaseOpenPositionNumber(bC.pA);
                pio.decreaseOpenPositionNumber(bC.pB);
                emit liquidatedEvent(bContractId);
            } else { // settle
                pio.payLiquidationShare((bO.dfA * notional / 1e18) * pio.getTotalShare());
                require(uPnl >= deltaImA, "Default:UnderflowCheck12");
                pio.setBalance(uPnl - deltaImA, bC.pA, address(0), true, false);
                pio.paySponsor(msg.sender, bC.pB, bC.price, bO.lastPrice, bO.imB, false);
                bC.price = bO.lastPrice;
                bC.openTime = bO.lastPriceUpdateTime;
                emit settledEvent(bContractId);
            }
        }
        pio.updateCumIm(bO, bC, bContractId);
    }

    event BContractValues(
    uint256 bContractId,
    uint256 oracleId,
    uint256 price,
    uint256 amount,
    uint256 interestRate,
    bool isAPayingAPR,
    address pA,
    address pB,
    uint256 state,
    uint256 openTime
);

event BOracleValues(
    uint256 oracleId,
    uint256 lastPrice,
    uint256 lastPriceUpdateTime,
    uint256 maxDelay,
    uint256 imA,
    uint256 imB,
    uint256 dfA,
    uint256 dfB
);

event AdditionalValues(
    uint256 currentTimestamp,
    uint256 totalShare
);

function emitAllValues(uint256 bContractId) public {
    utils.bContract memory bC = pio.getBContract(bContractId);
    utils.bOracle memory bO = pio.getBOracle(bC.oracleId);

    // Emit bContract values
    emit BContractValues(
        bContractId,
        bC.oracleId,
        bC.price,
        bC.amount,
        bC.interestRate,
        bC.isAPayingAPR,
        bC.pA,
        bC.pB,
        bC.state,
        bC.openTime
    );

    // Emit bOracle values
    emit BOracleValues(
        bC.oracleId,
        bO.lastPrice,
        bO.lastPriceUpdateTime,
        bO.maxDelay,
        bO.imA,
        bO.imB,
        bO.dfA,
        bO.dfB
    );

    // Emit additional values
    emit AdditionalValues(
        block.timestamp,
        pio.getTotalShare()
    );
}
}