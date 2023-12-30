// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";

import "hardhat/console.sol";


contract PionerV1Open {
    PionerV1 private pnr;
    PionerV1Compliance private kyc;

    event openQuoteEvent( address indexed target,uint256 indexed bContractId, bool isLong, uint256 bOracleId, uint256 price, uint256 qty, uint256 interestRate, bool isAPayingAPR); 
    event acceptQuoteEvent( address indexed target, uint256 indexed bContractId, uint256 price); 
    event cancelOpenQuoteEvent( uint256 indexed bContractId );
    event deployBContract(uint256 indexed bOracleId);

    constructor(address _pionerV1, address _pionerV1Compliance) {
        pnr = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
    }

    function deployBOracle(
        address _priceFeedAddress,
        bytes32 _pythAddress1,
        bytes32 _pythAddress2,
        uint256 _maxDelay,
        utils.bOrType _oracleType,
        uint256 _imA,
        uint256 _imB,
        uint256 _dfA,
        uint256 _dfB,
        uint256 _expiryA,
        uint256 _expiryB,
        uint256 _timeLockA,
        uint256 _timeLockB,
        utils.cType _cType 
    ) public {
        utils.bOracle memory bO = pnr.getBOracle(pnr.getBOracleLength());
        bO.priceFeedAddress = _priceFeedAddress;
        bO.maxDelay = _maxDelay;
        bO.pythAddress1 = _pythAddress1;
        bO.pythAddress2 = _pythAddress2;
        bO.oracleType = _oracleType;
        bO.imA = _imA;
        bO.imB = _imB;
        bO.dfA = _dfA;
        bO.dfB = _dfB;
        bO.expiryA = _expiryA;
        bO.expiryB = _expiryB;
        bO.timeLockA = _timeLockA;
        bO.timeLockB = _timeLockB;
        bO.cType = _cType;
        emit deployBContract(pnr.getBOracleLength());
        pnr.setBOracle(pnr.getBOracleLength(), bO);
        pnr.addBOracleLength();
    }


    function wrapperOpenQuoteSwap(bool isLong,
        uint256 price,
        uint256 qty,
        uint256 interestRate, 
        bool isAPayingAPR, 
        address frontEnd, 
        address affiliate,
        address _priceFeedAddress,
        bytes32 _pythAddress1,
        bytes32 _pythAddress2,
        uint256 _maxDelay,
        uint256 _imA,
        uint256 _imB,
        uint256 _dfA,
        uint256 _dfB,
        uint256 _expiryA,
        uint256 _expiryB,
        uint256 _timeLockA
        ) public{
        deployBOracle(_priceFeedAddress, _pythAddress1, _pythAddress2, _maxDelay, utils.bOrType.Dummy, _imA,
        _imB, _dfA, _dfB, _expiryA,  _expiryB, _timeLockA, _timeLockA, utils.cType.Swap); 
        openQuote(isLong, pnr.getBOracleLength() - 1, price, qty, interestRate, isAPayingAPR, frontEnd, affiliate);
    }

    function openQuote( 
        bool isLong,
        uint256 bOracleId,
        uint256 price,
        uint256 qty,
        uint256 interestRate, 
        bool isAPayingAPR, 
        address frontEnd, 
        address affiliate
    ) public {
        
        utils.bContract memory bC = pnr.getBContract(pnr.getBContractLength());
        utils.bOracle memory bO = pnr.getBOracle(bOracleId);

        require( pnr.getOpenPositionNumber(msg.sender) <= pnr.getMaxOpenPositions(), "Open11" );
        require(qty * price / 1e18 >= pnr.getMinNotional(), "Open12");
        require(kyc.kycCheck(msg.sender , address(0)), "Open12b");

        bC.initiator = msg.sender;
        bC.price = price;
        bC.qty = qty;
        bC.interestRate = interestRate;
        bC.isAPayingAPR = isAPayingAPR;
        bC.oracleId = bOracleId;
        bC.state = utils.cState.Quote;
        bC.frontEnd = frontEnd;
        bC.affiliate = affiliate;
        
        if(isLong){
            console.log("test2");

            pnr.setBalance( (bO.imA + bO.dfA) * qty / 1e18 * price / 1e18, msg.sender, address(0), false, true);
            bC.pA = msg.sender;
        }
        else{
            console.log("test1");

            pnr.setBalance( (bO.imB + bO.dfB) * qty / 1e18 * price / 1e18 , msg.sender, address(0), false, true);
            bC.pB = msg.sender;
        }   

        emit openQuoteEvent( msg.sender, pnr.getBContractLength(), isLong, bOracleId, price, qty, interestRate, isAPayingAPR);
        pnr.setBContract(pnr.getBContractLength(), bC);
        pnr.addBContractLength();
        pnr.addOpenPositionNumber(msg.sender);
        pnr.updateCumIm(bO, bC, pnr.getBContractLength() - 1);
    }


    function acceptQuote(uint256 bContractId, uint256 _acceptPrice, address backendAffiliate) public {
        console.log("accept Quote");
        require( pnr.getOpenPositionNumber(msg.sender) < pnr.getMaxOpenPositions(), "Open21" );
        utils.bContract memory bC = pnr.getBContract(bContractId);
        utils.bOracle memory bO = pnr.getBOracle(bC.oracleId);
        require(kyc.kycCheck(msg.sender , bC.initiator), "Open21b");    
        if(bC.openTime == block.timestamp && bC.state == utils.cState.Open) {
            if(bC.initiator == bC.pA && _acceptPrice < bC.price) { 
                pnr.setBalance( utils.getNotional(bO, bC, false) , bC.pB, address(0), true, false);
                pnr.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * bC.price / 1e18 ); // @mint
                pnr.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.qty / 1e18  , msg.sender, bC.pB, false, true);
                
                pnr.setBalance( ((1e18+(bO.imA + bO.dfA)) * ( _acceptPrice - bC.price ) / 1e18 * bC.qty / 1e18) , bC.pA, address(0), true, false);
                pnr.decreaseOpenPositionNumber(bC.pB);
                bC.pB = msg.sender;
                bC.price = _acceptPrice;
                }
            else if(bC.initiator == bC.pB && _acceptPrice > bC.price) { 
                pnr.setBalance( utils.getNotional(bO, bC, true) , bC.pA, bC.pB, true, true);
                pnr.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * bC.price / 1e18 ); // @mint
                pnr.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.qty / 1e18  , msg.sender, bC.pB, false, true);
                pnr.setBalance( ((1e18+(bO.imB + bO.dfB)) * (bC.price - _acceptPrice ) / 1e18 * bC.qty / 1e18 ) , bC.pB, bC.pA, false, true);
                pnr.decreaseOpenPositionNumber(bC.pA);
                bC.pA = msg.sender;
                bC.price = _acceptPrice;
                

                }
            emit acceptQuoteEvent(msg.sender, bContractId, _acceptPrice);
        } else if (bC.state == utils.cState.Quote){
            if (bC.initiator == bC.pA){
                bC.price = _acceptPrice;
                bC.pB = msg.sender;
                require(_acceptPrice <= bC.price, "Open26");
                pnr.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.qty / 1e18 , msg.sender, bC.pB, false, true);
                pnr.addCumImBalances(msg.sender, bO.imB * bC.qty / 1e18 * _acceptPrice / 1e18 ); // @mint
                pnr.setBalance( (bO.imA + bO.dfA) * (_acceptPrice - bC.price) / 1e18 * bC.qty / 1e18  , bC.pA, address(0), true, false);
                pnr.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * (_acceptPrice - bC.price) / 1e18 ); // @mint
            }
            else if (bC.initiator == bC.pB){
                bC.price = _acceptPrice;
                bC.pA = msg.sender;
                require(_acceptPrice >= bC.price, "Open28");
                pnr.setBalance( ( bO.imA + bO.dfA) * _acceptPrice / 1e18 * bC.qty / 1e18  , bC.pB, address(0), false, false);
                pnr.addCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * _acceptPrice / 1e18 ); // @mint
                pnr.setBalance( ((bO.imB + bO.dfB) * (_acceptPrice - bC.price) / 1e18 * bC.qty / 1e18) , msg.sender, bC.pB, true, true);
                pnr.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * (_acceptPrice - bC.price) / 1e18 ); // @mint
            }
            bC.openTime = block.timestamp;
            bC.hedger = backendAffiliate;
            bC.state = utils.cState.Open;
            pnr.addOpenPositionNumber(msg.sender);
            pnr.setBContract(bContractId, bC);
            pnr.updateCumIm(bO, bC, bContractId);
            emit acceptQuoteEvent(msg.sender, bContractId, _acceptPrice);
        }
    }
    


    function cancelOpenQuote( uint256 bContractId) public{
        utils.bContract memory bC = pnr.getBContract(bContractId);
        utils.bOracle memory bO = pnr.getBOracle(bC.oracleId);
        require( bC.state == utils.cState.Open, "Open31");
        if( msg.sender == bC.pA ){
            pnr.setBalance( bO.imA * bO.dfA * bC.qty * bC.price , msg.sender, address(0), true, false);
            pnr.decreaseOpenPositionNumber(msg.sender);
            bC.state == utils.cState.Closed; 
            pnr.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * bC.price / 1e18 ); // @mint
        }
        else{
        require( msg.sender == bC.pB, "Open32" );
            pnr.setBalance( bO.imB * bO.dfB * bC.qty * bC.price , msg.sender, address(0), true, false);
            pnr.decreaseOpenPositionNumber(msg.sender);
            bC.state == utils.cState.Closed;
            pnr.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * bC.price / 1e18 ); // @mint
        }
        pnr.setBContract(bContractId, bC);
        pnr.updateCumIm(bO, bC, bContractId);
        emit cancelOpenQuoteEvent(bContractId );
    }

}