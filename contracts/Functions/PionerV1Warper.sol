// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.20;

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";
import "./PionerV1Open.sol";
import "./PionerV1Close.sol";
import "./PionerV1Default.sol";
import "./PionerV1Oracle.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title PionerV1 Warper
 * @dev This contract manage warpers function for UX purposes.
 * @notice This contract is not audited
 * @author Microderiv
 */
contract PionerV1Warper is EIP712 {
    PionerV1 private pio;
    PionerV1Compliance private compliance;
    PionerV1Open private open;
    PionerV1Close private close;
    PionerV1Default private settle;
    PionerV1Oracle private oracle;

    constructor (
            address pionerV1Address
            , address pionerV1ComplianceAddress
            , address pionerV1OpenAddress
            , address pionerV1CloseAddress
            , address pionerV1DefaultAddress
            , address pionerV1OracleAddress 
            )  EIP712("PionerV1Warper", "1.0"){
        pio = PionerV1(pionerV1Address);
        compliance = PionerV1Compliance(pionerV1ComplianceAddress);
        open = PionerV1Open(pionerV1OpenAddress);
        close = PionerV1Close(pionerV1CloseAddress);
        settle = PionerV1Default(pionerV1DefaultAddress);
        oracle = PionerV1Oracle(pionerV1OracleAddress);
    }

    function wrapperUpdatePriceAndDefault( utils.upnlSig memory priceSignature,uint256 bOracleId,uint256 bContractId ) public {
        oracle.updatePricePion(priceSignature, bOracleId );
        settle.settleAndLiquidate( bContractId);
    }

    function wrapperUpdatePriceAndCloseMarket( utils.upnlSig memory priceSignature,uint256 bOracleId,uint256 bCloseQuoteId,uint256 index ) public {
        oracle.updatePricePion( priceSignature, bOracleId );
        close.closeMarket(bCloseQuoteId, index);
    }

    function warperCloseQuoteSignedAndAcceptClose( utils.OpenCloseQuote calldata quote, bytes calldata signHash ) public {
        close.openCloseQuoteSigned( quote, signHash ); 
        close.acceptCloseQuote(pio.getBCloseQuoteLength() - 1, 0 , quote.amount );
    }
    

    function wrapperOpenTPSLOracleSwap(
        bool isLong,
        uint256 price,
        uint256 amount,
        uint256 interestRate, 
        bool isAPayingAPR, 
        address frontEnd, 
        address affiliate,
        bytes32 _asset1,
        bytes32 _asset2,
        uint256 _x,
        uint8 _parity,
        uint256 _maxConfidence,
        uint256 _maxDelay,
        uint256 _imA,
        uint256 _imB,
        uint256 _dfA,
        uint256 _dfB,
        uint256 _expiryA,
        uint256 _expiryB,
        uint256 _timeLockA,
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
            _asset1,
            _asset2,
            _maxDelay,
            _imA,
            _imB,
            _dfA,
            _dfB,
            _expiryA,
            _expiryB,
            _timeLockA,
            _timeLockA,
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

    function wrapperOpenQuoteAndDeployPionOracleSigned(
        utils.OracleSwapWithSignature calldata oracleSwapWithSignature,
        bytes calldata signatureOracleSwapWithSignature,
        utils.OpenQuoteSign calldata openQuoteSign,
        bytes calldata openQuoteSignature
    ) public {
        require( keccak256(openQuoteSignature) == keccak256(oracleSwapWithSignature.signatureHashOpenQuote), "Signature hash mismatch" );
        bytes32 structHash = keccak256(abi.encode(
            keccak256("OracleSwapWithSignature(uint256 x,uint8 parity,uint256 maxConfidence,uint256 maxDelay,uint256 imA,uint256 imB,uint256 dfA,uint256 dfB,uint256 expiryA,uint256 expiryB,uint256 timeLockA,bytes32 signatureHashOpenQuote,uint256 nonce)"),
            oracleSwapWithSignature.x,
            oracleSwapWithSignature.parity,
            oracleSwapWithSignature.maxConfidence,
            oracleSwapWithSignature.maxDelay,
            oracleSwapWithSignature.imA,
            oracleSwapWithSignature.imB,
            oracleSwapWithSignature.dfA,
            oracleSwapWithSignature.dfB,
            oracleSwapWithSignature.expiryA,
            oracleSwapWithSignature.expiryB,
            oracleSwapWithSignature.timeLockA,
            oracleSwapWithSignature.signatureHashOpenQuote,
            oracleSwapWithSignature.nonce
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signatureOracleSwapWithSignature);

        oracle.deployBOraclePion(
            oracleSwapWithSignature.x, oracleSwapWithSignature.parity, oracleSwapWithSignature.maxConfidence, oracleSwapWithSignature.asset1, oracleSwapWithSignature.asset2, oracleSwapWithSignature.maxDelay, 
            oracleSwapWithSignature.imA, oracleSwapWithSignature.imB, oracleSwapWithSignature.dfA, oracleSwapWithSignature.dfB, 
            oracleSwapWithSignature.expiryA, oracleSwapWithSignature.expiryB, oracleSwapWithSignature.timeLockA, oracleSwapWithSignature.timeLockA, 1 
        );

        open.openQuoteSigned(openQuoteSign, openQuoteSignature, signer);
    }


    function warperOpenQuoteDeployOracleAndAcceptQuoteMM( 
        utils.OracleSwapWithSignature calldata oracleSwapWithSignature,
        bytes calldata signatureOracleSwapWithSignature,
        utils.OpenQuoteSign calldata openQuoteSign,
        bytes calldata openQuoteSignature,
        uint256 bContractId, uint256 _acceptPrice, address backendAffiliate) public {
        wrapperOpenQuoteAndDeployPionOracleSigned( oracleSwapWithSignature, signatureOracleSwapWithSignature, openQuoteSign, openQuoteSignature); 
        open.acceptQuote(bContractId, _acceptPrice, backendAffiliate);
    }
    
    function warperOpenQuoteDeployOracleAndAcceptQuoteAPI( 
        utils.OracleSwapWithSignature calldata oracleSwapWithSignature,
        bytes calldata signatureOracleSwapWithSignature,
        utils.OpenQuoteSign calldata openQuoteSign,
        bytes calldata openQuoteSignature,
        utils.AcceptQuoteSign calldata acceptQuoteSign, bytes calldata signHash) public {
        wrapperOpenQuoteAndDeployPionOracleSigned( oracleSwapWithSignature, signatureOracleSwapWithSignature, openQuoteSign, openQuoteSignature); 
        open.acceptQuoteSigned(acceptQuoteSign, signHash);
    }

    
}