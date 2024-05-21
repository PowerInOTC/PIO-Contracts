// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.20;

import "./PionerV1.sol";
import "./PionerV1Compliance.sol";
import "./PionerV1Open.sol";
import "./PionerV1Close.sol";
import "./PionerV1Default.sol";
import "./PionerV1Oracle.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";

/**
 * @title PionerV1 wrapper
 * @dev This contract manage wrappers function for UX purposes.
 * @notice This contract is not audited
 * @author Microderiv
 */
contract PionerV1Wrapper is EIP712 {
    PionerV1 private pio;
    PionerV1Compliance private compliance;
    PionerV1Open private open;
    PionerV1Close private close;
    PionerV1Default private settle;
    PionerV1Oracle private oracle;

        event acceptQuoteEvent(bytes indexed signatureHashOpenQuote);


    constructor (
            address pionerV1Address
            , address pionerV1ComplianceAddress
            , address pionerV1OpenAddress
            , address pionerV1CloseAddress
            , address pionerV1DefaultAddress
            , address pionerV1OracleAddress 
            )  EIP712("PionerV1Wrapper", "1.0"){
        pio = PionerV1(pionerV1Address);
        compliance = PionerV1Compliance(pionerV1ComplianceAddress);
        open = PionerV1Open(pionerV1OpenAddress);
        close = PionerV1Close(pionerV1CloseAddress);
        settle = PionerV1Default(pionerV1DefaultAddress);
        oracle = PionerV1Oracle(pionerV1OracleAddress);
    }

    function wrapperUpdatePriceAndDefault( utils.pionSign memory priceSignature,uint256 bOracleId,uint256 bContractId ) public {
        oracle.updatePricePion(priceSignature, bOracleId );
        settle.settleAndLiquidate( bContractId);
    }

    function wrapperUpdatePriceAndCloseMarket( utils.pionSign memory priceSignature,uint256 bOracleId,uint256 bCloseQuoteId,uint256 index ) public {
        oracle.updatePricePion( priceSignature, bOracleId );
        close.closeMarket(bCloseQuoteId, index);
    }

    function wrapperCloseLimitMM( utils.OpenCloseQuoteSign calldata quote, bytes calldata signHash ) public {
        close.openCloseQuoteSigned( quote, signHash, msg.sender ); 
        close.acceptCloseQuotewrapper(pio.getBCloseQuoteLength() - 1, 0 , quote.amount, msg.sender );
    }
    

    function wrapperOpenTPSLOracleSwap(
        bool isLong,
        uint256 price,
        uint256 amount,
        uint256 interestRate, 
        bool isAPayingAPR, 
        address frontEnd, 
        address affiliate,
        bytes32 _assetHex,
        uint256 _x,
        uint8 _parity,
        uint256 _maxConfidence,
        uint256 _maxDelay,
        uint256 precision,
        uint256 _imA,
        uint256 _imB,
        uint256 _dfA,
        uint256 _dfB,
        uint256 _expiryA,
        uint256 _expiryB,
        uint256 _timeLock,
        uint256[] memory bContractIdsTP,
        uint256[] memory priceTP, 
        uint256[] memory amountTP, 
        uint256[] memory limitOrStopTP, 
        uint256[] memory expiryTP,
        uint256[] memory bContractIdsSL,
        uint256[] memory priceSL, 
        uint256[] memory amountSL, 
        uint256[] memory limitOrStopSL, 
        uint256[] memory expirySL
        ) public {

        oracle.deployBOraclePion( 
            _x,
            _parity,
            _maxConfidence,
            _assetHex,
            _maxDelay,
            precision,
            _imA,
            _imB,
            _dfA,
            _dfB,
            _expiryA,
            _expiryB,
            _timeLock,
            1
            );
        open.openQuote(isLong, pio.getBOracleLength() - 1, price, amount, interestRate, isAPayingAPR, frontEnd, affiliate);
        if (bContractIdsTP.length > 0 ) {
            close.openCloseQuote(bContractIdsTP, priceTP, amountTP, limitOrStopTP, expiryTP);
        }
        if (bContractIdsSL.length > 0 ) {
            close.openCloseQuote(bContractIdsSL, priceSL, amountSL, limitOrStopSL, expirySL);
        }
    }
    

    /// @dev This function is used by hedging bots to open a quote and deploy a Pion Oracle
    function wrapperOpenQuoteMM(
        utils.bOracleSign calldata bOracleSign,
        bytes calldata signaturebOracleSign,
        utils.OpenQuoteSign calldata openQuoteSign,
        bytes calldata openQuoteSignature,
        uint256 _acceptPrice) public {

       require( keccak256(openQuoteSignature) == keccak256(bOracleSign.signatureHashOpenQuote), "Signature hash mismatch" );
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("bOracleSign(uint256 x,uint8 parity,uint256 maxConfidence,bytes32 assetHex,uint256 maxDelay,uint256 precision,uint256 imA,uint256 imB,uint256 dfA,uint256 dfB,uint256 expiryA,uint256 expiryB,uint256 timeLock,bytes signatureHashOpenQuote,uint256 nonce)"),
                bOracleSign.x,
                bOracleSign.parity,
                bOracleSign.maxConfidence,
                bOracleSign.assetHex,
                bOracleSign.maxDelay,
                bOracleSign.precision,
                bOracleSign.imA,
                bOracleSign.imB,
                bOracleSign.dfA,
                bOracleSign.dfB,
                bOracleSign.expiryA,
                bOracleSign.expiryB,
                bOracleSign.timeLock,
                keccak256(abi.encodePacked(bOracleSign.signatureHashOpenQuote)),
                bOracleSign.nonce
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signaturebOracleSign);

        oracle.deployBOraclePion(
            bOracleSign.x, bOracleSign.parity, bOracleSign.maxConfidence, bOracleSign.assetHex, bOracleSign.maxDelay, bOracleSign.precision, 
            bOracleSign.imA, bOracleSign.imB, bOracleSign.dfA, bOracleSign.dfB, 
            bOracleSign.expiryA, bOracleSign.expiryB, bOracleSign.timeLock, 1 
        );
        open.openQuoteSigned(openQuoteSign, openQuoteSignature, signer, pio.getBOracleLength() - 1, msg.sender);
        open.acceptQuotewrapper(pio.getBContractLength() - 1, _acceptPrice, msg.sender);
        emit acceptQuoteEvent(bOracleSign.signatureHashOpenQuote);

    }

/*
        /// @dev This functino is used to push a signed accept quote in case accepting counterparty does not do it
    function wrapperOpenQuoteAPI(
        utils.bOracleSign calldata bOracleSign,
        bytes calldata signaturebOracleSign,
        utils.OpenQuoteSign calldata openQuoteSign,
        bytes calldata openQuoteSignature,
         utils.AcceptOpenQuoteSign calldata acceptQuoteSign, bytes calldata signHash) public {

        require( keccak256(openQuoteSignature) == keccak256(bOracleSign.signatureHashOpenQuote), "Signature hash mismatch" );
        bytes32 structHash = keccak256(abi.encode(
            keccak256("bOracleSign(uint256 x,uint8 parity,uint256 maxConfidence,uint256 maxDelay,uint256 confidence, uint256 imA,uint256 imB,uint256 dfA,uint256 dfB,uint256 expiryA,uint256 expiryB,uint256 timeLock,bytes32 signatureHashOpenQuote,uint256 nonce)"),
            bOracleSign.x,
            bOracleSign.parity,
            bOracleSign.maxConfidence,
            bOracleSign.maxDelay,
            bOracleSign.precision,
            bOracleSign.imA,
            bOracleSign.imB,
            bOracleSign.dfA,
            bOracleSign.dfB,
            bOracleSign.expiryA,
            bOracleSign.expiryB,
            bOracleSign.timeLock,
            bOracleSign.signatureHashOpenQuote,
            bOracleSign.nonce
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signaturebOracleSign);

        oracle.deployBOraclePion(
            bOracleSign.x, bOracleSign.parity, bOracleSign.maxConfidence, bOracleSign.assetHex, bOracleSign.maxDelay, bOracleSign.precision, 
            bOracleSign.imA, bOracleSign.imB, bOracleSign.dfA, bOracleSign.dfB, 
            bOracleSign.expiryA, bOracleSign.expiryB, bOracleSign.timeLock, 1 
        );

        open.openQuoteSigned(openQuoteSign, openQuoteSignature, signer);
        open.acceptQuoteSigned(acceptQuoteSign, signHash);
    }
    */
}