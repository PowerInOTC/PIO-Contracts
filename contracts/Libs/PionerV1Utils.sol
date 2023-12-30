// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import "hardhat/console.sol";


library PionerV1Utils {
    
    enum cState {Quote, Open, Closed, Canceled, Liquidated}
    enum cType { Swap, Call, Put}
    // two side only when both party of a trade mustkyced 
	// oneWay when anyone can subscribe // twoWay whenkyc need a confirmation
	// mint is a oneWayOneSide
    // trusted is against a single party without settlement obligations.
    enum kycType {unasigned, oneWayOneSide, twoWayOneSide, oneWayTwoSide, twoWayTwoSide, mint, fundOneWay, fundTwoWay, fundManager, pirate, trusted}   
    enum bOrType {Pyth, Chainlink, Dummy}

    struct bContract { 
        address pA; 
        address pB; 
        uint256 oracleId;
        address initiator;
        uint256 price;
        uint256 qty;
        uint256 interestRate; 
        bool isAPayingAPR;
        uint256 openTime;
        cState state;
        address frontEnd;
        address hedger;
        address affiliate;
        uint256 cancelTime;
    }

    //Struct for Close Quote ( Limit Close )
    struct bCloseQuote { // exit quote
        uint256[] bContractIds;
        uint256[] price;
        uint256[] qty;
        uint256[] limitOrStop; // if non 0, quotePrice
        uint256[] expiry;
        address initiator; 
        uint256 cancelTime;
        uint256 openTime; 
        cState state;
    } 

    //Struct for Oracle
    struct bOracle{
        uint256 lastPrice;
        uint256 lastPriceUpdateTime; 
        uint256 maxDelay;
        address priceFeedAddress;
        bytes32 pythAddress1;
        bytes32 pythAddress2;
        bOrType oracleType;
        uint256 imA;
        uint256 imB;
        uint256 dfA;
        uint256 dfB;
        uint256 expiryA; // time where position can be closed at last oracle price
        uint256 expiryB;
        uint256 timeLockA; 
        uint256 timeLockB;
        cType cType;
        address kycAddress; 
        bool isPaused;
        uint256 deployTime;
        // CCP
        address ccpDAO;
        uint256 longQty;
        uint256 shortQty;
        uint256 avgLongOpenPrice;
        uint256 avgShortOpenPrice;
        uint256 maxLongOI;
        uint256 maxShortOI;
        uint256 ir;
        uint256 volatilityThreshold; // not add to owed if pass that threshold
    }

    function int64ToUint256(int64 value) public pure returns (uint256) {
        require(value >= 0, "Cannot cast negative int64 to uint256");

        int256 intermediate = int256(value);
        uint256 convertedValue = uint256(intermediate);

        return convertedValue;
    }


    function dynamicIm(uint256 price, uint256 lastPrice, uint256 qty, uint256 im, uint256 df) public pure returns(uint256)  { 
        if( price >= lastPrice ){
            return( price * qty /1e18 * ( im + df ) /1e18 - lastPrice * qty /1e18 * ( im + df ) /1e18);
        }
        else {
            return( lastPrice * qty /1e18 * ( im + df ) /1e18 - price * qty  /1e18* ( im + df ) /1e18);
        }
    }

    // return true if negative
    function calculateuPnl(uint256 price, uint256 lastPrice, uint256 qty, uint256 interestRate, uint256 lastPriceUpdateTime, bool isPayingIr) public view returns (uint256, bool) {
        uint256 ir = calculateIr(interestRate, (block.timestamp - lastPriceUpdateTime), lastPrice, qty);
        uint256 pnl;
        if (lastPrice >= price) {
            pnl = ((lastPrice - price) * qty) / 1e18;
            if (isPayingIr) {
                if (pnl >= ir) {
                    return (pnl - ir, false);
                } else {
                    return (ir - pnl, true);
                }
            } else {
                return (pnl + ir, false);
            }
        } else {
            pnl = ((price - lastPrice) * qty) / 1e18;
            if (isPayingIr) {
                return (pnl - ir, true);
            } else {
                return (pnl + ir, true);
            }
        }
    }


    function calculateIr( uint256 rate, uint256 time, uint256 price, uint256 qty) public pure returns(uint256){
        return( rate * time /1e18 * price / 1e18 * qty / 1e18) / 31536000;
    }

    // getNotional(_bOracle, _bContract, true);
    function getNotional(bOracle memory bO, bContract memory bC, bool isA) public pure returns(uint256) {
        if (isA){
            return(( bO.imA + bO.dfA) * bC.price / 1e18 * bC.qty / 1e18 );
        } else{
            return(( bO.imB + bO.dfB) * bC.price / 1e18 * bC.qty / 1e18 );
        }
    }

    function getIm(bOracle memory bO, bool isA) internal pure returns(uint256 im) {
        if( bO.cType == cType.Swap){
            if( isA ){
                return( bO.imA );
            } else {
                return( bO.imB );
            }
        }
    }

    

}