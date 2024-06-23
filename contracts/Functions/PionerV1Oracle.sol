// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;
// LICENSE.txt at : https://www.pioner.io/license

import "./PionerV1.sol";
import "hardhat/console.sol";
import "../Libs/MuonClientBase.sol";
import "../Libs/SchnorrSECP256K1VerifierV2.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";


/**
 * @title PionerV1 Oracle
 * @dev This contract manage oracle initialization and price update. Working with Pyth Network and Pion Network.
 * @notice This contract is not audited
 * @author Microderiv
 */
contract PionerV1Oracle {
    PionerV1 private pio;
    SchnorrSECP256K1VerifierV2 public verifier;

    event deployBContract(uint256 bContractId);
    
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
        uint256 _timeLock,
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
        bO.timeLock = _timeLock;
        bO.cType = _cType;
        emit deployBContract(pio.getBOracleLength());
        pio.setBOracle(pio.getBOracleLength(), bO);
        pio.addBOracleLength();
    }



    function deployBOraclePion(
        uint256 x,
        uint8 parity,
        uint256 _maxConfidence,
        bytes32 _assetHex,
        uint256 _maxDelay,
        uint256 _precision,
        uint256 _imA,
        uint256 _imB,
        uint256 _dfA,
        uint256 _dfB,
        uint256 _expiryA,
        uint256 _expiryB,
        uint256 _timeLock,
        uint256 _cType 
    ) public {
        utils.bOracle memory bO = pio.getBOracle(pio.getBOracleLength());
        bO.x = x;
        bO.parity = parity;
        bO.maxDelay = _maxDelay;
        bO.assetHex = _assetHex;
        bO.oracleType = 4;
        bO.maxConfidence = _maxConfidence;
        bO.precision = _precision;
        bO.imA = _imA;
        bO.imB = _imB;
        bO.dfA = _dfA;
        bO.dfB = _dfB;
        bO.expiryA = _expiryA;
        bO.expiryB = _expiryB;
        bO.timeLock = _timeLock;
        bO.cType = _cType;
        bO.forceCloseType = 1;
        
        bO.lastPriceUpdateTime = block.timestamp;
        emit deployBContract(pio.getBOracleLength());
        pio.setBOracle(pio.getBOracleLength(), bO);
        pio.addBOracleLength();
    }


    function updatePricePion(utils.pionSign memory priceSignature, uint256 bOracleId ) public{
        utils.bOracle memory bO = pio.getBOracle(bOracleId);

        bytes32 hash = keccak256(
            abi.encodePacked(
                priceSignature.appId,
                priceSignature.reqId,
                priceSignature.requestassetHex,
                priceSignature.requestPairBid,
                priceSignature.requestPairAsk,
                priceSignature.requestConfidence,
                priceSignature.requestSignTime,
                priceSignature.requestPrecision
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
            bO.lastPriceUpdateTime < priceSignature.requestSignTime, "or10");
        require( 
            bO.oracleType == 4, "or11");
        require( 
            bO.assetHex == priceSignature.requestassetHex , "or12");
        require( 
            priceSignature.requestSignTime + bO.maxDelay>= block.timestamp, "or13");
        require( 
            priceSignature.requestConfidence <= bO.maxConfidence, "or14");

        bO.lastBid = priceSignature.requestPairBid;
        bO.lastAsk = priceSignature.requestPairAsk;
        bO.lastPrice = ( bO.lastBid + bO.lastAsk )/2 ;
        bO.lastPriceUpdateTime = priceSignature.requestSignTime;
        pio.setBOracle(bOracleId, bO);
    }

    function twoWaybOracleChange( uint256 bContractId ,  uint256 oracleChangeId) public {
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bContractUpdate memory bCU = pio.getBContractUpdate(bContractId);

        if (bCU.oracleChangeInitializer == address(0) &&
            (msg.sender == bC.pA || msg.sender == bC.pB)){ // init
                bCU.oracleChangeInitializer = msg.sender;
                bCU.oracleChangeId = oracleChangeId;
            }
        else if (( bCU.oracleChangeInitializer == bC.pA || bCU.oracleChangeInitializer == bC.pB ) 
            && msg.sender == bCU.oracleChangeInitializer ) { // cancel
            bCU.oracleChangeInitializer == address(0);
        }   
        else if (( bCU.oracleChangeInitializer == bC.pA && msg.sender == bC.pB ) 
            &&  bCU.oracleChangeInitializer == bC.pB && msg.sender == bC.pA ){
                bC.oracleId = bCU.oracleChangeId;
                bCU.oracleChangeInitializer == address(0);
        }
        pio.setBContract(bContractId, bC);
    }


    function updatePriceDummy(uint256 bOracleId, uint256 price, uint256 time) public {
        utils.bOracle memory bO = pio.getBOracle(bOracleId);
        bO.lastPrice = price;
        bO.lastPriceUpdateTime = time;
        require(bO.oracleType == 3, "or20");
        pio.setBOracle(bOracleId, bO);
    }


}