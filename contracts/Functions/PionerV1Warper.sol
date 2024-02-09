// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";
import "./PionerV1Open.sol";
import "./PionerV1Close.sol";
import "./PionerV1Default.sol";
import "./PionerV1Oracle.sol";

import "hardhat/console.sol";


/**
 * @title PionerV1 Warper
 * @dev This contract manage warpers function for UX purposes.
 * @notice This contract is not audited
 * @author Microderiv
 */
contract PionerV1Warper {
    PionerV1 private pio;
    PionerV1Compliance private compliance;
    PionerV1Open private open;
    PionerV1Close private close;
    PionerV1Default private settle;
    PionerV1Oracle private oracle;

    constructor(
            address pionerV1Address
            , address pionerV1ComplianceAddress
            , address pionerV1OpenAddress
            , address pionerV1CloseAddress
            , address pionerV1DefaultAddress
            , address pionerV1OracleAddress 
            ) {
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

    

    function wrapperOpenTPSLOracleSwap(
        bool isLong,
        uint256 price,
        uint256 qty,
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
        uint256[] memory qtyTP, 
        uint256[] memory limitOrStopTP, 
        uint256[] memory expiryTP,
        uint256[] memory bContractIdsSL,
        uint256[] memory priceSL, 
        uint256[] memory qtySL, 
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
        open.openQuote(isLong, pio.getBOracleLength() - 1, price, qty, interestRate, isAPayingAPR, frontEnd, affiliate);
        if (bContractIdsTP.length > 0 ) {
            close.openCloseQuote(bContractIdsTP, priceTP, qtyTP, limitOrStopTP, expiryTP);
        }
        if (bContractIdsSL.length > 0 ) {
            close.openCloseQuote(bContractIdsSL, priceSL, qtySL, limitOrStopSL, expirySL);
        }
    }

    function wrapperOpenTPSLOracleSwap(
        bool isLong,
        uint256 price,
        uint256 qty,
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

        address authorized,
        bytes memory signatureOpen,
        bytes32 signHashOpen,

        bytes32 signHash,
        bytes memory signature
        ) public {

        bytes32 paramsHash = keccak256(abi.encodePacked( block.chainid, address(this), signHashOpen, _x, _parity, _maxConfidence, _asset1, _asset2, _maxDelay, _imA, _imB, _dfA, _dfB, _expiryA, _expiryB, _timeLockA, _timeLockA ));
        require(signHash == paramsHash, "Hash mismatch");
        require( utils.verifySignature(signHash, signature) == utils.verifySignature(signHashOpen, signatureOpen));

        oracle.deployBOraclePion( _x, _parity, _maxConfidence, _asset1, _asset2, _maxDelay, _imA, _imB, _dfA, _dfB, _expiryA, _expiryB, _timeLockA, _timeLockA, 1 );
        open.openQuoteSigned(isLong, pio.getBOracleLength() - 1, price, qty, interestRate, isAPayingAPR, frontEnd, affiliate, authorized, signHashOpen, signatureOpen);
    }


    
}