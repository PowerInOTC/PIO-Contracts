// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";

import "hardhat/console.sol";


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


    function flashDefaultAuction(uint256 bContractId) public {
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);

        require(bC.cancelTime + pio.getDefaultAuctionPeriod() > block.timestamp, "Default11");
        require(bC.state == 4, "Default12");
        require(kyc.kycCheck(msg.sender , bC.initiator), "Default12b");

        if (bC.initiator == bC.pA) {
            uint256 owedAmount = pio.getOwedAmount(bC.pA,bC.pB);
            require(pio.getBalance(msg.sender) > owedAmount, "Default13");
            pio.setBalance( owedAmount , bC.pA, bC.pB, true, false);
            
            pio.decreaseTotalOwedAmountPaid(bC.pA, owedAmount);
            pio.setOwedAmount(bC.pA, bC.pB, 0);

            bC.price = ((1e18 - pio.getTotalShare()) * ( bO.dfA ) / 1e18 * bC.price / 1e18 * bC.qty / 1e18 ) / bC.qty / 1e18 ;
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

            bC.price = ((1e18 - pio.getTotalShare()) * ( bO.dfB ) / 1e18 * bC.price / 1e18 * bC.qty / 1e18 ) / bC.qty / 1e18 ;
            pio.setBalance( utils.getNotional(bO, bC, true) + owedAmount , msg.sender, bC.pA, false, true);
            
            pio.setBalance( utils.getNotional(bO, bC, false) , bC.pB, bC.pA, false, true);
            
            bC.pA = msg.sender; 
            pio.addOpenPositionNumber(bC.pA);
            pio.addOpenPositionNumber(bC.pB);
        }
        pio.updateCumIm(bO, bC, bContractId);
        emit flashAuctionBuyBackEvent(bContractId);
    }
                 
    function settleAndLiquidate(uint256 bContractId) public{
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        require(kyc.getKycType(msg.sender) != 6, "Default21a");
        require(bC.state == 2, "Default21b");
        require( bO.lastPriceUpdateTime <= bO.maxDelay + block.timestamp, "Default22");
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, bO.lastPrice, bC.qty, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR );
        uint256 ir = utils.calculateIr(bC.interestRate, (block.timestamp - bO.lastPriceUpdateTime), bO.lastPrice, bC.qty);
        uint256 deltaImA = utils.dynamicIm( bC.price, bO.lastPrice, bC.qty, bO.imA, bO.dfA);
        uint256 deltaImB = utils.dynamicIm( bC.price, bO.lastPrice, bC.qty, bO.imB, bO.dfB); 
        uint256 owedAmount;
            
        if (isNegative){
            console.log(1);
            owedAmount = pio.getTotalOwedAmount(bC.pA);
            pio.setBalance( uPnl , bC.pA, bC.pB, false, false);
            if( owedAmount != pio.getTotalOwedAmount(bC.pA) ){ // liquidate
                if (pio.getOwedAmount(bC.pA,bC.pB) >= bO.imA * bO.lastPrice / 1e18 * bC.qty / 1e18){
                    console.log(2);
                    pio.decreaseTotalOwedAmount(bC.pA, bO.imA * bO.lastPrice / 1e18 * bC.qty / 1e18);
                    pio.removeOwedAmount(bC.pB, bC.pA, bO.imA * bO.lastPrice / 1e18 * bC.qty / 1e18);
                } else {
                    console.log(3);
                    pio.setBalance( bO.imA * bO.lastPrice / 1e18 * bC.qty / 1e18 - pio.getOwedAmount(bC.pA,bC.pB) , bC.pA, bC.pB, true, false);
                    pio.decreaseTotalOwedAmount(bC.pA, pio.getOwedAmount(bC.pA,bC.pB));
                    pio.setOwedAmount(bC.pA, bC.pB, 0);
                }
                pio.setBalance( uPnl - (bO.dfB + bO.imB + (bO.dfA * ( 1 - pio.getTotalShare())) / 1e18 ) * bO.lastPrice / 1e18 * bC.qty / 1e18, bC.pB, bC.pA, true, false);
                pio.payAffiliates(( bO.dfA / 1e18 * bO.lastPrice / 1e18 * bC.qty / 1e18 + ir ) * pio.getTotalShare() , bC.frontEnd, bC.affiliate, bC.hedger);

                bC.initiator = bC.pA;
                bC.state = 4;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pio.decreaseOpenPositionNumber(bC.pA);
                pio.decreaseOpenPositionNumber(bC.pB);
                emit liquidatedEvent(bContractId);
            } else { //settle
                console.log(4);
                pio.payAffiliates((ir) * pio.getTotalShare() / 1e18, bC.frontEnd, bC.affiliate, bC.hedger);
                pio.setBalance( deltaImA , bC.pA, bC.pB, true, false);
                pio.setBalance( uPnl + deltaImB , bC.pB, bC.pA, true, false);
                pio.paySponsor(msg.sender, bC.pA, bC.price, bO.lastPrice, bO.imA, true);
                bC.price = bO.lastPrice ;
                bC.openTime = bO.lastPriceUpdateTime ;
                emit settledEvent(bContractId);
            }
        } else {
            owedAmount = pio.getTotalOwedAmount(bC.pB);
            pio.setBalance( uPnl + deltaImB , bC.pB, bC.pA, false, false);
            if( owedAmount != pio.getTotalOwedAmount(bC.pB) || deltaImB > pio.getBalance(bC.pB) ){ // liquidate
                if (pio.getOwedAmount(bC.pB,bC.pA) >= bO.imB * bO.lastPrice / 1e18 * bC.qty / 1e18){
                    console.log(5);
                    pio.decreaseTotalOwedAmount(bC.pB, bO.imB * bO.lastPrice / 1e18 * bC.qty / 1e18);
                    pio.removeOwedAmount(bC.pB, bC.pA, bO.imB * bO.lastPrice / 1e18 * bC.qty / 1e18);
                } else {
                    console.log(6);
                    pio.setBalance( bO.imB * bO.lastPrice / 1e18 * bC.qty / 1e18 - pio.getOwedAmount(bC.pB,bC.pA) , bC.pB, address(0), true, false);
                    pio.decreaseTotalOwedAmount(bC.pB, pio.getOwedAmount(bC.pB,bC.pA));
                    pio.setOwedAmount(bC.pB, bC.pA, 0);
                }
                pio.setBalance( (bO.dfA + bO.imA + (bO.dfB * ( 1e18 - pio.getTotalShare())) / 1e18 ) * bO.lastPrice / 1e18 * bC.qty / 1e18, bC.pA, address(0), true, false);
                pio.payAffiliates(( bO.dfB / 1e18 * bO.lastPrice / 1e18 * bC.qty / 1e18 + ir ) * pio.getTotalShare() , bC.frontEnd, bC.affiliate, bC.hedger);

                bC.initiator = bC.pB;
                bC.state = 4;
                bC.cancelTime = block.timestamp;
                bC.price = bO.lastPrice;
                pio.decreaseOpenPositionNumber(bC.pA);
                pio.decreaseOpenPositionNumber(bC.pB);
                emit liquidatedEvent(bContractId);
            } else {
                console.log(7);
                pio.payAffiliates((ir) * pio.getTotalShare() / 1e18, bC.frontEnd, bC.affiliate, bC.hedger);
                pio.setBalance( deltaImB , bC.pA, bC.pB, false, false);
                pio.setBalance( uPnl - deltaImA , bC.pA, bC.pB, true, false);
                pio.paySponsor(msg.sender, bC.pB, bC.price, bO.lastPrice, bO.imB, false);
                bC.price = bO.lastPrice ;
                bC.openTime = bO.lastPriceUpdateTime ;
                emit settledEvent(bContractId);
            }
        }
        pio.updateCumIm(bO, bC, bContractId);
    }
/*
    function settleAndLiquidateMint() public{
        //require(pio.getKycType(msg.sender) == 6, "Default21a");
        uint bob = pio.getBalance(msg.sender);
    } */

    
    
}