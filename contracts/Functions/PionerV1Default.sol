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

/*  /// @dev Buyback a default positions against defaulting party DF for getDefaultAuctionPeriod() after liquidation
    function flashDefaultAuction(uint256 bContractId) public {
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);

        require(bC.cancelTime + pio.getDefaultAuctionPeriod() > block.timestamp, "Default11");
        require(bC.state == 4, "Default12");
        require(kyc.kycCheck(msg.sender , bC.initiator), "Default12b");
        uint256 notional = bC.price / 1e18 * bC.amount / 1e18;
        
        if (bC.initiator == bC.pA) {
            // inherit debts
            uint256 owedAmount = pio.getOwedAmount(bC.pA,bC.pB);
            pio.setOwedAmount(bC.pA, bC.pB, 0);
            pio.setOwedAmount(bC.pA, msg.sender, owedAmount);

            pio.setBalance( bO.dfA * notional , msg.sender, address(0), true, false);
            pio.setBalance( bO.dfA * notional , msg.sender, address(0), false, true);

            pio.setBalance( owedAmount , bC.pA, bC.pB, true, false);
                        

            bC.price = ((1e18 - pio.getTotalShare()) * ( bO.dfA ) / 1e18 * bC.price / 1e18  );
            pio.setBalance( utils.getNotional(bO, bC, true) + owedAmount , msg.sender, bC.pB, false, true);
            
            pio.setBalance( utils.getNotional(bO, bC, false) , bC.pB, bC.pA, false, true);
            
            bC.pA = msg.sender; 
            pio.addOpenPositionNumber(bC.pA);
            pio.addOpenPositionNumber(bC.pB);
        } else {
            uint256 owedAmount = pio.getOwedAmount(bC.pB,bC.pA);
            require(pio.getBalance(msg.sender) > owedAmount, "Default14");
            pio.setBalance( owedAmount , bC.pB, bC.pA, true, false);
            
            pio.decreaseTotalOwedAmountPaid(bC.pB, owedAmount);
            pio.setOwedAmount(bC.pB, bC.pA, 0);

            bC.price = ((1e18 - pio.getTotalShare()) * ( bO.dfB ) / 1e18 * bC.price / 1e18 * bC.amount / 1e18 ) / bC.amount / 1e18 ;
            pio.setBalance( utils.getNotional(bO, bC, true) + owedAmount , msg.sender, bC.pA, false, true);
            
            pio.setBalance( utils.getNotional(bO, bC, false) , bC.pB, bC.pA, false, true);
            
            bC.pA = msg.sender; 
            pio.addOpenPositionNumber(bC.pA);
            pio.addOpenPositionNumber(bC.pB);
        }
        pio.updateCumIm(bO, bC, bContractId);
        emit flashAuctionBuyBackEvent(bContractId);
    } */
                 
    function settleAndLiquidate(uint256 bContractId) public{
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        require(kyc.getKycType(msg.sender) != 6, "Default21a");
        require(bC.state == 2, "Default21b");
        require( bO.lastPriceUpdateTime + bO.maxDelay >=  block.timestamp, "Default22");
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, bO.lastPrice, bC.amount, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR );
        uint256 ir = utils.calculateIr(bC.interestRate, (block.timestamp - bO.lastPriceUpdateTime), bO.lastPrice, bC.amount);
        uint256 deltaImA = utils.dynamicIm( bC.price, bO.lastPrice, bC.amount, bO.imA, bO.dfA);
        uint256 deltaImB = utils.dynamicIm( bC.price, bO.lastPrice, bC.amount, bO.imB, bO.dfB); 
        uint256 notional = bC.price / 1e18 * bC.amount / 1e18;
        uint256 paid;
        bool liquidated;
            
        if (isNegative){ // deltaIm down
            if( uPnl > deltaImA){
                paid = pio.setBalance( uPnl - deltaImA, bC.pA, bC.pB, false, false);
                if( paid != uPnl - deltaImA){ liquidated = true; }
            } else {
                paid = pio.setBalance( deltaImA - uPnl, bC.pA, address(0), true, false);
            }
            if( liquidated ){ // liquidate
                paid += bO.imA * notional;
                if ( paid > uPnl){ pio.addBalance(bC.pA, paid - uPnl );} else { pio.addToOwed( uPnl - paid, bC.pA, bC.pB);}
                pio.setBalance( paid + (bO.dfB + bO.imB + (bO.dfA * ( 1e18 - pio.getTotalShare())) / 1e18 ) * notional , bC.pB, address(0), true, false);
                pio.payLiquidationShare(( bO.dfA * notional ) * pio.getTotalShare() );

                bC.initiator = bC.pA;
                bC.state = 4;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pio.decreaseOpenPositionNumber(bC.pB);
                pio.decreaseOpenPositionNumber(bC.pA);
                emit liquidatedEvent(bContractId);
            } else { // settle
                pio.payLiquidationShare(( bO.dfA * notional ) * pio.getTotalShare() );
                pio.setBalance( uPnl + deltaImB , bC.pB, address(0), true, false);
                pio.paySponsor(msg.sender, bC.pA, bC.price, bO.lastPrice, bO.imA, false);
                bC.price = bO.lastPrice ;
                bC.openTime = bO.lastPriceUpdateTime ;
                emit settledEvent(bContractId);
            }
        } else { // deltaIm up
            paid = pio.setBalance( uPnl + deltaImB, bC.pB, bC.pA, false, false);
            if( paid != uPnl + deltaImB ){ // liquidate
                if( paid > uPnl ){ paid += bO.imB * notional + paid - uPnl; } else { paid += bO.imB * notional; }
                if ( paid > uPnl){ pio.addBalance(bC.pB, paid - uPnl );} else { pio.addToOwed( uPnl - paid, bC.pB, bC.pA);}
                pio.setBalance( paid + (bO.dfA + bO.imA + (bO.dfB * ( 1e18 - pio.getTotalShare())) / 1e18 ) * notional , bC.pA, address(0), true, false);
                pio.payLiquidationShare(( bO.dfA * notional ) * pio.getTotalShare() );


                bC.initiator = bC.pB;
                bC.state = 4;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pio.decreaseOpenPositionNumber(bC.pA);
                pio.decreaseOpenPositionNumber(bC.pB);
                emit liquidatedEvent(bContractId);
            } else { // settle
                pio.payLiquidationShare(( bO.dfA * notional ) * pio.getTotalShare() );
                pio.setBalance( uPnl - deltaImA , bC.pA, address(0), true, false);
                pio.paySponsor(msg.sender, bC.pB, bC.price, bO.lastPrice, bO.imB, false);
                bC.price = bO.lastPrice ;
                bC.openTime = bO.lastPriceUpdateTime ;
                emit settledEvent(bContractId);
            }
        }
        pio.updateCumIm(bO, bC, bContractId);
    }
    
}