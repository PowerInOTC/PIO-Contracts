// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";

import "hardhat/console.sol";



contract PionerV1Default {
    PionerV1 private pnr;
    PionerV1Compliance private kyc;

    event settledEvent(uint256 bContractId);
    event liquidatedEvent(uint256 bContractId);
    event flashAuctionBuyBackEvent(address target, uint256 bContractId);

    constructor(address _pionerV1, address _pionerV1Compliance) {
        pnr = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
    }


    function flashDefaultAuction(uint256 bContractId) public {
        utils.bContract memory bC = pnr.getBContract(bContractId);
        utils.bOracle memory bO = pnr.getBOracle(bC.oracleId);

        require(bC.cancelTime + pnr.getDefaultAuctionPeriod() > block.timestamp, "Default11");
        require(bC.state == utils.cState.Liquidated, "Default12");
        require(kyc.kycCheck(msg.sender , bC.initiator), "Default12b");

        if (bC.initiator == bC.pA) {
            uint256 owedAmount = pnr.getOwedAmount(bC.pA,bC.pB);
            require(pnr.getBalance(msg.sender) > owedAmount, "Default13");
            pnr.setBalance( owedAmount , bC.pA, bC.pB, true, false);
            
            pnr.decreaseTotalOwedAmountPaid(bC.pA, owedAmount);
            pnr.setOwedAmount(bC.pA, bC.pB, 0);

            bC.price = ((1e18 - pnr.getTotalShare()) * ( bO.dfA ) / 1e18 * bC.price / 1e18 * bC.qty / 1e18 ) / bC.qty / 1e18 ;
            pnr.setBalance( utils.getNotional(bO, bC, true) + owedAmount , msg.sender, bC.pB, false, true);
            
            pnr.setBalance( utils.getNotional(bO, bC, false) , bC.pB, bC.pA, false, true);
            
            bC.pA = msg.sender; 
            pnr.addOpenPositionNumber(bC.pA);
            pnr.addOpenPositionNumber(bC.pB);
        } else {
            uint256 owedAmount = pnr.getOwedAmount(bC.pB,bC.pA);
            require(pnr.getBalance(msg.sender) > owedAmount, "Default14");
            pnr.setBalance( owedAmount , bC.pB, bC.pA, true, false);
            
            pnr.decreaseTotalOwedAmountPaid(bC.pB, owedAmount);
            pnr.setOwedAmount(bC.pB, bC.pA, 0);

            bC.price = ((1e18 - pnr.getTotalShare()) * ( bO.dfB ) / 1e18 * bC.price / 1e18 * bC.qty / 1e18 ) / bC.qty / 1e18 ;
            pnr.setBalance( utils.getNotional(bO, bC, true) + owedAmount , msg.sender, bC.pA, false, true);
            
            pnr.setBalance( utils.getNotional(bO, bC, false) , bC.pB, bC.pA, false, true);
            
            bC.pA = msg.sender; 
            pnr.addOpenPositionNumber(bC.pA);
            pnr.addOpenPositionNumber(bC.pB);
        }
        pnr.updateCumIm(bO, bC, bContractId);
        emit flashAuctionBuyBackEvent(msg.sender, bContractId);
    }
                 
    function settleAndLiquidate(uint256 bContractId) public{
        utils.bContract memory bC = pnr.getBContract(bContractId);
        utils.bOracle memory bO = pnr.getBOracle(bC.oracleId);
        require(kyc.getKycType(msg.sender) != utils.kycType.mint, "Default21a");
        require(bC.state == utils.cState.Open, "Default21b");
        require( bO.lastPriceUpdateTime <= bO.maxDelay + block.timestamp, "Default22");
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, bO.lastPrice, bC.qty, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR );
        uint256 ir = utils.calculateIr(bC.interestRate, (block.timestamp - bO.lastPriceUpdateTime), bO.lastPrice, bC.qty);
        uint256 deltaImA = utils.dynamicIm( bC.price, bO.lastPrice, bC.qty, bO.imA, bO.dfA);
        uint256 deltaImB = utils.dynamicIm( bC.price, bO.lastPrice, bC.qty, bO.imB, bO.dfB); 
        uint256 owedAmount;
            
        if (isNegative){
            owedAmount = pnr.getTotalOwedAmount(bC.pA);
            pnr.setBalance( uPnl , bC.pA, bC.pB, false, false);
            if( owedAmount != pnr.getTotalOwedAmount(bC.pA) ){ // liquidate
                if (pnr.getOwedAmount(bC.pA,bC.pB) >= bO.imA * bO.lastPrice / 1e18 * bC.qty / 1e18){
                    pnr.decreaseTotalOwedAmount(bC.pA, bO.imA * bO.lastPrice / 1e18 * bC.qty / 1e18);
                    pnr.removeOwedAmount(bC.pB, bC.pA, bO.imA * bO.lastPrice / 1e18 * bC.qty / 1e18);
                } else {
                    pnr.setBalance( bO.imA * bO.lastPrice / 1e18 * bC.qty / 1e18 - pnr.getOwedAmount(bC.pA,bC.pB) , bC.pA, bC.pB, true, false);
                    pnr.decreaseTotalOwedAmount(bC.pA, pnr.getOwedAmount(bC.pA,bC.pB));
                    pnr.setOwedAmount(bC.pA, bC.pB, 0);
                }
                pnr.setBalance( uPnl - (bO.dfB + bO.imB + (bO.dfA * ( 1 - pnr.getTotalShare())) / 1e18 ) * bO.lastPrice / 1e18 * bC.qty / 1e18, bC.pB, bC.pA, true, false);
                pnr.payAffiliates(( bO.dfA / 1e18 * bO.lastPrice / 1e18 * bC.qty / 1e18 + ir ) * pnr.getTotalShare() , bC.frontEnd, bC.affiliate, bC.hedger);

                bC.initiator = bC.pA;
                bC.state = utils.cState.Liquidated;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pnr.decreaseOpenPositionNumber(bC.pA);
                pnr.decreaseOpenPositionNumber(bC.pB);
                emit liquidatedEvent(bContractId);
            } else { //settle
                pnr.payAffiliates((ir) * pnr.getTotalShare() / 1e18, bC.frontEnd, bC.affiliate, bC.hedger);
                pnr.setBalance( deltaImA , bC.pA, bC.pB, true, false);
                pnr.setBalance( uPnl + deltaImB , bC.pB, bC.pA, true, false);
                pnr.paySponsor(msg.sender, bC.pA, bC.price, bO.lastPrice, bO.imA, true);
                bC.price = bO.lastPrice ;
                bC.openTime = bO.lastPriceUpdateTime ;
                emit settledEvent(bContractId);
            }
        } else {
            owedAmount = pnr.getTotalOwedAmount(bC.pB);
            pnr.setBalance( uPnl + deltaImB , bC.pB, bC.pA, false, false);
            if( owedAmount != pnr.getTotalOwedAmount(bC.pB) || deltaImB > pnr.getBalance(bC.pB) ){ // liquidate
                if (pnr.getOwedAmount(bC.pB,bC.pA) >= bO.imB * bO.lastPrice / 1e18 * bC.qty / 1e18){
                    pnr.decreaseTotalOwedAmount(bC.pB, bO.imB * bO.lastPrice / 1e18 * bC.qty / 1e18);
                    pnr.removeOwedAmount(bC.pB, bC.pA, bO.imB * bO.lastPrice / 1e18 * bC.qty / 1e18);
                } else {
                    pnr.setBalance( bO.imB * bO.lastPrice / 1e18 * bC.qty / 1e18 - pnr.getOwedAmount(bC.pB,bC.pA) , bC.pB, bC.pA, true, false);
                    pnr.decreaseTotalOwedAmount(bC.pB, pnr.getOwedAmount(bC.pB,bC.pA));
                    pnr.setOwedAmount(bC.pB, bC.pA, 0);
                }
                pnr.setBalance( (bO.dfA + bO.imA + (bO.dfB * ( 1e18 - pnr.getTotalShare())) / 1e18 ) * bO.lastPrice / 1e18 * bC.qty / 1e18, bC.pA, bC.pB, true, false);
                pnr.payAffiliates(( bO.dfB / 1e18 * bO.lastPrice / 1e18 * bC.qty / 1e18 + ir ) * pnr.getTotalShare() , bC.frontEnd, bC.affiliate, bC.hedger);

                bC.initiator = bC.pB;
                bC.state = utils.cState.Liquidated;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pnr.decreaseOpenPositionNumber(bC.pA);
                pnr.decreaseOpenPositionNumber(bC.pB);
                emit liquidatedEvent(bContractId);
            } else {
                pnr.payAffiliates((ir) * pnr.getTotalShare() / 1e18, bC.frontEnd, bC.affiliate, bC.hedger);
                pnr.setBalance( deltaImB , bC.pA, bC.pB, false, false);
                pnr.setBalance( uPnl - deltaImA , bC.pA, bC.pB, true, false);
                pnr.paySponsor(msg.sender, bC.pB, bC.price, bO.lastPrice, bO.imB, false);
                bC.price = bO.lastPrice ;
                bC.openTime = bO.lastPriceUpdateTime ;
                emit settledEvent(bContractId);
            }
        }
        pnr.updateCumIm(bO, bC, bContractId);
    }
/*
    function settleAndLiquidateMint() public{
        //require(pnr.getKycType(msg.sender) == utils.kycType.mint, "Default21a");
        uint bob = pnr.getBalance(msg.sender);
    } */

    
    
}