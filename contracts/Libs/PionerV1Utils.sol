// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.20;

import "hardhat/console.sol";


library PionerV1Utils {

    struct pionSign {
        int256 appId;
        bytes reqId;
        bytes32 requestassetHex;
        uint256 requestPairBid;
        uint256 requestPairAsk;
        uint256 requestConfidence;
        uint256 requestSignTime;
        uint256 requestPrecision;
        uint256 signature; 
        address owner;
        address nonce;
    }

    struct bContract { 
        address pA; 
        address pB; 
        uint256 oracleId;
        address initiator;
        uint256 price;
        uint256 amount;
        uint256 interestRate; 
        bool isAPayingAPR;
        uint256 openTime;
        uint256 state;
        address frontEnd;
        address hedger;
        address affiliate;
        uint256 cancelTime;
    }

    struct bContractUpdate {
        address oracleChangeInitializer;
        uint256 oracleChangeId;
        bool isTranferAInit;
        bool isTranferBInit;
        address targetTransferA; 
        address targetTransferB;
        uint256 transferBribeA;
        uint256 transferBribeB;
    }

    struct bContractTransferQuote {
        uint256 transferOffer; 
        uint256 transferOfferBribe;
        uint256 transferMethod;
        uint256 transferQuoteExpiry;
        bool transferSide;
    }

    struct bCloseQuote { 
        uint256 bContractId;
        uint256 price;
        uint256 amount;
        uint256 limitOrStop; 
        uint256 expiry;
        address initiator; 
        uint256 cancelTime;
        uint256 openTime; 
        uint256 state;
}


  


    struct bOracle{
        bytes32 assetHex;
        uint256 oracleType;
        address priceFeedAddress;
        bytes32 pythAddress1;
        bytes32 pythAddress2;
        uint256 lastBid;
        uint256 lastAsk;
        address publicOracleAddress;
        uint256 maxConfidence;
        uint256 x;
        uint8 parity;
        uint256 maxDelay;
        uint256 precision;

        uint256 lastPrice;
        uint256 lastPriceUpdateTime; 
        uint256 imA;
        uint256 imB;
        uint256 dfA;
        uint256 dfB;
        uint256 expiryA;
        uint256 expiryB;
        uint256 timeLock; 
        uint256 cType;
        uint256 forceCloseType;
        address kycAddress; 
        bool isPaused;
        uint256 deployTime;
        uint256 marketCloseFee;
    }

    struct  OpenQuoteSign {
        bool isLong;
        uint256 bOracleId;
        uint256 price;
        uint256 amount;
        uint256 interestRate;
        bool isAPayingAPR;
        address frontEnd;
        address affiliate;
        address authorized;
        uint256 nonce; 
    }

    struct AcceptOpenQuoteSign {
        uint256 bContractId;
        uint256 acceptPrice;
        address backendAffiliate;
        uint256 amount;
        uint256 nonce; 
    }

    struct CancelRequestSign {
        bytes targetHash; 
        uint256 nonce;
    }

    struct OpenCloseQuoteSign {
        uint256 bContractId;
        uint256 price;
        uint256 amount;
        uint256 limitOrStop;
        uint256 expiry;
        address authorized;
        uint256 nonce;
    }

    struct CloseQuoteSign {
        uint256 bCloseQuoteId;
        uint256 index;
        uint256 nonce;
    }

    struct bOracleSign {
        uint256 x;
        uint8 parity;
        uint256 maxConfidence;
        bytes32 assetHex;
        uint256 maxDelay;
        uint256 precision;
        uint256 imA;
        uint256 imB;
        uint256 dfA;
        uint256 dfB;
        uint256 expiryA;
        uint256 expiryB;
        uint256 timeLock;
        bytes signatureHashOpenQuote;
        uint256 nonce;
    }

    function dynamicIm(uint256 price, uint256 lastPrice, uint256 amount, uint256 im, uint256 df) public pure returns(uint256)  { 
        if( price >= lastPrice ){
            return( ( price - lastPrice )  * amount /1e18 * ( im + df ) /1e18);
        }
        else {
            return( ( lastPrice - price )  * amount /1e18 * ( im + df ) /1e18);
        }
    }

    function calculateuPnl(uint256 price, uint256 lastPrice, uint256 amount, uint256 interestRate, uint256 lastPriceUpdateTime, bool isPayingIr) public view returns (uint256, bool) {
        uint256 ir = calculateIr(interestRate, (block.timestamp - lastPriceUpdateTime), lastPrice, amount);

        uint256 pnl;
        if (lastPrice >= price) {
            pnl = ((lastPrice - price) * amount) / 1e18;

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
            pnl = ((price - lastPrice) * amount) / 1e18;

            if (isPayingIr) {
                return (pnl - ir, true);
            } else {
                return (pnl + ir, true);
            }
        }
    }

    function calculateIr( uint256 rate, uint256 time, uint256 price, uint256 amount) public pure returns(uint256){
        return( rate * time * price / 1e18 * amount / 1e18) / 31536000;
    }

    function getNotional(bOracle memory bO, bContract memory bC, bool isA) public pure returns(uint256) {
        if (isA){
            return(( bO.imA + bO.dfA) * bC.price / 1e18 * bC.amount / 1e18 );
        } else{
            return(( bO.imB + bO.dfB) * bC.price / 1e18 * bC.amount / 1e18 );
        }
    }

    function getIm(bOracle memory bO, bool isA) internal pure returns(uint256 im) {
        if( bO.cType == 1){
            if( isA ){
                return( bO.imA );
            } else {
                return( bO.imB );
            }
        }
    }
    
    
}