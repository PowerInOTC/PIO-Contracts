// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;
// LICENSE.txt at : https://www.pioner.io/license

import "../PionerV1.sol";
import "hardhat/console.sol";
import "../Libs/MuonClientBase.sol";
import "../Libs/SchnorrSECP256K1VerifierV2.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";


contract PionerV1Oracle {
    PionerV1 private pio;
    SchnorrSECP256K1VerifierV2 public verifier;

    event deployBContract(uint256 indexed bOracleId);

    constructor(address _pionerV1, address _verifierAddress) {
        pio = PionerV1(_pionerV1);
        verifier = SchnorrSECP256K1VerifierV2(_verifierAddress);

    }

    function deployBOraclePyth(
        address _priceFeedAddress,
        bytes32 _pythAddress1,
        bytes32 _pythAddress2,
        uint256 _maxDelay,
        uint256 _oracleType,
        uint256 _imA,
        uint256 _imB,
        uint256 _dfA,
        uint256 _dfB,
        uint256 _expiryA,
        uint256 _expiryB,
        uint256 _timeLockA,
        uint256 _timeLockB,
        uint256 _cType 
    ) public {
        utils.bOracle memory bO = pio.getBOracle(pio.getBOracleLength());
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
        emit deployBContract(pio.getBOracleLength());
        pio.setBOracle(pio.getBOracleLength(), bO);
        pio.addBOracleLength();
    }
    
    function deployBOraclePion(
        uint256 x,
        uint8 parity,
        uint256 _maxConfidence,
        bytes32 _asset1,
        bytes32 _asset2,
        uint256 _maxDelay,
        uint256 _imA,
        uint256 _imB,
        uint256 _dfA,
        uint256 _dfB,
        uint256 _expiryA,
        uint256 _expiryB,
        uint256 _timeLockA,
        uint256 _timeLockB,
        uint256 _cType 
    ) public {
        utils.bOracle memory bO = pio.getBOracle(pio.getBOracleLength());
        bO.x = x;
        bO.parity = parity;
        bO.maxDelay = _maxDelay;
        bO.asset1 = _asset1;
        bO.asset2 = _asset2;
        bO.oracleType = 4;
        bO.maxConfidence = _maxConfidence;
        bO.imA = _imA;
        bO.imB = _imB;
        bO.dfA = _dfA;
        bO.dfB = _dfB;
        bO.expiryA = _expiryA;
        bO.expiryB = _expiryB;
        bO.timeLockA = _timeLockA;
        bO.timeLockB = _timeLockB;
        bO.cType = _cType;
        bO.lastPriceUpdateTime = block.timestamp;
        emit deployBContract(pio.getBOracleLength());
        pio.setBOracle(pio.getBOracleLength(), bO);
        pio.addBOracleLength();
    }


    function updatePricePion(utils.upnlSig memory priceSignature, uint256 bOracleId ) public{
        utils.bOracle memory bO = pio.getBOracle(bOracleId);

        bytes32 hash = keccak256(
            abi.encodePacked(
                priceSignature.appId,
                priceSignature.reqId,
                priceSignature.asset1,
                priceSignature.asset2,
                priceSignature.lastBid,
                priceSignature.lastBid,
                priceSignature.confidence,
                priceSignature.signTime
            )
        );
    /*
        bool verified = verifier.verifySignature(
            bO.x,
            bO.parity,
            priceSignature.signature,
            uint256(hash), 
            priceSignature.nonce
        );
        
        require(verified, "Invalid signature.");
*/
        require( 
            bO.lastPriceUpdateTime < priceSignature.signTime
            && bO.oracleType == 4
            && bO.asset1 == priceSignature.asset1 
            && bO.asset2 == priceSignature.asset2 
            && priceSignature.signTime + bO.maxDelay>= block.timestamp 
            && priceSignature.confidence <= bO.maxConfidence, "wrong signature parameter" );
 
        bO.lastBid = priceSignature.lastBid;
        bO.lastAsk = priceSignature.lastAsk;
        bO.lastPrice = ( bO.lastBid + bO.lastAsk )/2 ;
        bO.lastPriceUpdateTime = priceSignature.signTime;
        pio.setBOracle(bOracleId, bO);
    }

    function twoWaybOracleChange( uint256 bContractId ,  uint256 oracleChangeId) public {
        utils.bContract memory bC = pio.getBContract(bContractId);
        if (bC.oracleChangeInitializer == address(0) &&
            (msg.sender == bC.pA || msg.sender == bC.pB)){ // init
                bC.oracleChangeInitializer = msg.sender;
                bC.oracleChangeId = oracleChangeId;
            }
        else if (( bC.oracleChangeInitializer == bC.pA || bC.oracleChangeInitializer == bC.pB ) 
            && msg.sender == bC.oracleChangeInitializer ) { // cancel
            bC.oracleChangeInitializer == address(0);
        }   
        else if (( bC.oracleChangeInitializer == bC.pA && msg.sender == bC.pB ) 
            &&  bC.oracleChangeInitializer == bC.pB && msg.sender == bC.pA ){
                bC.oracleId = bC.oracleChangeId;
                bC.oracleChangeInitializer == address(0);
        }
        pio.setBContract(bContractId, bC);
    }


    function updatePriceDummy(uint256 bOracleId, uint256 price, uint256 time) public {
        utils.bOracle memory bO = pio.getBOracle(bOracleId);
        bO.lastPrice = price;
        bO.lastPriceUpdateTime = time;
        require(bO.oracleType == 3, "not dummy");
        pio.setBOracle(bOracleId, bO);
    }


}