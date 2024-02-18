// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import "hardhat/console.sol";


library PionerV1Utils {
    /*
    enum cState {1: Quote, 2: Open, 3: Closed, 4: Canceled, 5: Liquidated}
    enum cType { 1: Swap, 2: Call, 3: Put, 4: SwapBidAsk}
    enum forceCloseType{ 1: Market, 2: TOT}
    // two side only when both party of a trade mustkyced 
	// oneWay when anyone can subscribe // twoWay whenkyc need a confirmation
	// mint is a oneWayOneSide
    // trusted is against a single party without settlement obligations.
    enum kycType {0: unasigned, , 1: self, 2: oneWayOneSide, 3: twoWayOneSide, 4: oneWayTwoSide, 5: twoWayTwoSide, 6: mint, 7: fundOneWay, 8: fundTwoWay, 9: fundManager, 10 : trusted}   
    enum bOrType {1 : Pyth, 2: Chainlink, 3: Dummy, 4 : Pion}
*/
    struct upnlSig {
        int256 appId;
        bytes reqId;
        bytes32 asset1;
        bytes32 asset2;
        uint256 lastBid;
        uint256 lastAsk;
        uint256 confidence;
        uint256 signTime;
        // SchnorrSign
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

    //Struct for Close Quote ( Limit Close )
    struct bCloseQuote { // exit quote
        uint256[] bContractIds;
        uint256[] price;
        uint256[] amount;
        uint256[] limitOrStop; // if non 0, quotePrice
        uint256[] expiry;
        address initiator; 
        uint256 cancelTime;
        uint256 openTime; 
        uint256 state;
    } 

    //Struct for Oracle
    struct bOracle{
        bytes32 asset1;
        bytes32 asset2;
        uint256 oracleType;
        // Pyth
        address priceFeedAddress;
        bytes32 pythAddress1;
        bytes32 pythAddress2;
        // Pion
        uint256 lastBid;
        uint256 lastAsk;
        address publicOracleAddress;
        uint256 maxConfidence;
        uint256 x;
        uint8 parity;
        uint256 maxDelay;

        uint256 lastPrice;
        uint256 lastPriceUpdateTime; 
        uint256 imA;
        uint256 imB;
        uint256 dfA;
        uint256 dfB;
        uint256 expiryA;
        uint256 expiryB;
        uint256 timeLockA; 
        uint256 timeLockB;
        uint256 cType;
        uint256 forceCloseType;
        address kycAddress; 
        bool isPaused;
        uint256 deployTime;
        uint256 marketCloseFee;
        /*
        // CCP
        address ccpDAO;
        uint256 longamount;
        uint256 shortamount;
        uint256 avgLongOpenPrice;
        uint256 avgShortOpenPrice;
        uint256 maxLongOI;
        uint256 maxShortOI;
        uint256 ir;
        uint256 volatilityThreshold; // not add to owed if pass that threshold
        */
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

    struct AcceptQuoteSign {
        uint256 bContractId;
        uint256 acceptPrice;
        address backendAffiliate;
        uint256 amount;
        uint256 nonce; 
    }

    struct CancelRequestSign {
        bytes orderHash; 
        uint256 nonce;
    }

    struct OpenCloseQuote {
        uint256 bContractId;
        uint256 price;
        uint256 amount;
        uint256 limitOrStop;
        uint256 expiry;
        address authorized;
        uint256 nonce;
    }

    struct CloseQuoteSignature {
        uint256 bCloseQuoteId;
        uint256 index;
        uint256 nonce;
    }

    struct CancelCloseRequest {
        bytes targetHash;
        uint256 nonce;
    }

    struct OracleSwapWithSignature {
        uint256 x;
        uint8 parity;
        uint256 maxConfidence;
        bytes32 asset1;
        bytes32 asset2;
        uint256 maxDelay;
        uint256 imA;
        uint256 imB;
        uint256 dfA;
        uint256 dfB;
        uint256 expiryA;
        uint256 expiryB;
        uint256 timeLockA;
        bytes signatureHashOpenQuote;
        uint256 nonce;
    }

    struct bContractIr {
        uint256 flatRateA;
        uint256 flatRateB;
        uint256 payementFrequency;
        uint256 caps;
        uint256 floor;
    }

    struct boracleIr {
        bytes32 assetA;
        bytes32 assetB;
        bytes32 irA;
        bytes32 irB;
        uint256 benchMarkMethod;
    }

    function int64ToUint256(int64 value) public pure returns (uint256) {
        require(value >= 0, "Cannot cast negative int64 to uint256");

        int256 intermediate = int256(value);
        uint256 convertedValue = uint256(intermediate);

        return convertedValue;
    }


    function bytesToUint256(bytes memory b) public pure returns (uint256 result) {
    require(b.length >= 32, "Input too short");
    
    assembly {
        result := mload(add(b, 32)) 
    }
}


    function dynamicIm(uint256 price, uint256 lastPrice, uint256 amount, uint256 im, uint256 df) public pure returns(uint256)  { 
        if( price >= lastPrice ){
            return( ( price - lastPrice )  * amount /1e18 * ( im + df ) /1e18);
        }
        else {
            return( ( lastPrice - price )  * amount /1e18 * ( im + df ) /1e18);
        }
    }

    // return true if negative
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

    // getNotional(_bOracle, _bContract, true);
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