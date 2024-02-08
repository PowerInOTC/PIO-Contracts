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
        uint256 qty;
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
        uint256[] qty;
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
        /*
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
        */
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
        return( rate * time * price / 1e18 * qty / 1e18) / 31536000;
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
        if( bO.cType == 1){
            if( isA ){
                return( bO.imA );
            } else {
                return( bO.imB );
            }
        }
    }

    function verifySignatureCloseQuote(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        if (signature.length != 65) {
            return false;
        }

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            return false;
        }
        return ecrecover(messageHash, v, r, s) == signer;
    }

}