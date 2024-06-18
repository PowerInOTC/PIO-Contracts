// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.20;

import "./PionerV1.sol";
import "./PionerV1Compliance.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";


import "hardhat/console.sol";

/**
 * @title PionerV1 Open
 * @dev This contract manage contract opening functions.
 * @notice This contract is not audited
 * @author Microderiv
 */
contract PionerV1Open  is EIP712  {
    PionerV1 private pio;
    PionerV1Compliance private kyc;

    event openQuoteEvent( uint256 indexed bContractId); 
    event openQuoteSignedEvent( uint256 indexed bContractId,bytes indexed fillAPIEventId); 
    event cancelSignedMessageOpenEvent(address indexed sender, bytes indexed messageHash);

    event acceptQuoteEvent( uint256 indexed bContractId); 
    event cancelOpenQuoteEvent( uint256 indexed bContractId);

    constructor(address _pionerV1, address _pionerV1Compliance) EIP712("PionerV1Open", "1.0") {
        pio = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
    }


    function cancelSignedMessageOpen(
        utils.CancelRequestSign calldata cancelRequest,
        bytes calldata signature
    ) public {  
        bytes32 structHash = keccak256(abi.encode(
            keccak256("CancelRequestSign(bytes orderHash,uint256 nonce)"),
            keccak256(abi.encodePacked(cancelRequest.targetHash)), 
            cancelRequest.nonce
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        pio.setCancelledOpenQuotes(cancelRequest.targetHash, signer, block.timestamp);
        emit cancelSignedMessageOpenEvent(signer, cancelRequest.targetHash);
    }

    function openQuoteSigned( 
        utils.OpenQuoteSign calldata openQuoteSign,
        bytes calldata signHash,
        address wrapperSigner,
        uint256 bOracleId,
        address sender
        ) public {

        bytes32 structHash = keccak256(abi.encode(
            keccak256("Quote(bool isLong,uint256 bOracleId,uint256 price,uint256 amount,uint256 interestRate,bool isAPayingAPR,address frontEnd,address affiliate,address authorized,uint256 nonce)"),
            openQuoteSign.isLong,
            openQuoteSign.bOracleId,
            openQuoteSign.price,
            openQuoteSign.amount,
            openQuoteSign.interestRate,  
            openQuoteSign.isAPayingAPR,
            openQuoteSign.frontEnd,
            openQuoteSign.affiliate,
            openQuoteSign.authorized,
            openQuoteSign.nonce
            ));

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signHash);
        require((pio.getCancelledOpenQuotes(signHash, signer)  + pio.getCancelTimeBuffer()) >= block.timestamp || pio.getCancelledOpenQuotes(signHash, signer)  == 0, "Quote expired");
        pio.setCancelledOpenQuotes(signHash, signer, 1) ;

        require(openQuoteSign.authorized == address(0) || sender == openQuoteSign.authorized, "Invalid signature or unauthorized");
        require(wrapperSigner == signer, "signers mismatch");
        require(msg.sender == pio.getPIONERV1WRAPPERADDRESS(), "Invalid sender");

        openQuote(openQuoteSign.isLong, bOracleId, openQuoteSign.price, openQuoteSign.amount, openQuoteSign.interestRate, openQuoteSign.isAPayingAPR, openQuoteSign.frontEnd, openQuoteSign.affiliate, signer);
        emit openQuoteSignedEvent( pio.getBContractLength(), signHash);
    }


    function openQuoteSigned( 
        utils.OpenQuoteSign calldata openQuoteSign,
        bytes calldata signHash
        ) public {

        bytes32 structHash = keccak256(abi.encode(
            keccak256("Quote(bool isLong,uint256 bOracleId,uint256 price,uint256 amount,uint256 interestRate,bool isAPayingAPR,address frontEnd,address affiliate,address authorized,uint256 nonce)"),
            openQuoteSign.isLong,
            openQuoteSign.bOracleId,
            openQuoteSign.price,
            openQuoteSign.amount,
            openQuoteSign.interestRate,
            openQuoteSign.isAPayingAPR,
            openQuoteSign.frontEnd,
            openQuoteSign.affiliate,
            openQuoteSign.authorized,
            openQuoteSign.nonce
            ));

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signHash);
        require((pio.getCancelledOpenQuotes(signHash, signer)  + pio.getCancelTimeBuffer()) >= block.timestamp || pio.getCancelledOpenQuotes(signHash, signer)  == 0, "Quote expired");
        pio.setCancelledOpenQuotes(signHash, signer, 1) ;
        require(openQuoteSign.authorized == address(0) || signer == openQuoteSign.authorized, "Invalid signature or unauthorized");
        require(msg.sender == pio.getPIONERV1WRAPPERADDRESS(), "Invalid sender");

        openQuote(openQuoteSign.isLong, openQuoteSign.bOracleId, openQuoteSign.price, openQuoteSign.amount, openQuoteSign.interestRate, openQuoteSign.isAPayingAPR, openQuoteSign.frontEnd, openQuoteSign.affiliate, signer);
        emit openQuoteSignedEvent( pio.getBContractLength(), signHash);
    }

    function openQuote(
        bool isLong,
        uint256 bOracleId,
        uint256 price,
        uint256 amount,
        uint256 interestRate, 
        bool isAPayingAPR, 
        address frontEnd, 
        address affiliate
    ) public {
        openQuote(isLong, bOracleId, price, amount, interestRate, isAPayingAPR, frontEnd, affiliate, msg.sender);
    }

    function openQuote( 
        bool isLong,
        uint256 bOracleId,
        uint256 price,
        uint256 amount,
        uint256 interestRate, 
        bool isAPayingAPR, 
        address frontEnd, 
        address affiliate,
        address target
    ) internal {
        utils.bContract memory bC = pio.getBContract(pio.getBContractLength());
        utils.bOracle memory bO = pio.getBOracle(bOracleId);

        require( pio.getOpenPositionNumber(target) <= pio.getMaxOpenPositions(), "Open11" ); 
        require(amount * price / 1e18 >= pio.getMinNotional(), "Open12");
        require(kyc.kycCheck(target , address(0)), "Open12b");

        bC.initiator = target;
        bC.price = price;
        bC.amount = amount;
        bC.interestRate = interestRate;
        bC.isAPayingAPR = isAPayingAPR;
        bC.oracleId = bOracleId;
        bC.state = 1;
        bC.frontEnd = frontEnd;
        bC.affiliate = affiliate;
        
        if(isLong){
            pio.setBalance( (bO.imA + bO.dfA) * amount / 1e18 * price / 1e18, target, address(0), false, true);
            bC.pA = target;
        }
        else{
            pio.setBalance( (bO.imB + bO.dfB) * amount / 1e18 * price / 1e18 , target, address(0), false, true);
            bC.pB = target;
        }   

        emit openQuoteEvent( pio.getBContractLength());
        pio.setBContract(pio.getBContractLength(), bC);
        pio.addBContractLength();
        pio.addOpenPositionNumber(target);
        pio.updateCumIm(bO, bC, pio.getBContractLength() - 1);
    }



    function acceptQuoteSigned(utils.AcceptOpenQuoteSign calldata AcceptOpenQuoteSign, bytes calldata signHash) public {
        bytes32 structHash = keccak256(abi.encode(
            keccak256("AcceptQuote(uint256 bContractId,uint256 acceptPrice,address backendAffiliate,uint256 amount,uint256 nonce)"),
            AcceptOpenQuoteSign.bContractId,
            AcceptOpenQuoteSign.acceptPrice,
            AcceptOpenQuoteSign.backendAffiliate,
            AcceptOpenQuoteSign.amount,
            AcceptOpenQuoteSign.nonce
        ));
         bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signHash);
        require((pio.getCancelledOpenQuotes(signHash, signer)  + pio.getCancelTimeBuffer()) <= block.timestamp || pio.getCancelledOpenQuotes(signHash, signer)  == 0, "Quote expired");
        pio.setCancelledOpenQuotes(signHash, signer, block.timestamp - pio.getCancelTimeBuffer() -1);
        acceptQuote(AcceptOpenQuoteSign.bContractId, AcceptOpenQuoteSign.acceptPrice, signer);
    }

    function acceptQuotewrapper( uint256 bContractId, uint256 acceptPrice,address target) public {
        require(msg.sender == pio.getPIONERV1WRAPPERADDRESS());
        acceptQuote(bContractId, acceptPrice, target);
    }

    function acceptQuote( uint256 bContractId, uint256 acceptPrice) public {
        acceptQuote(bContractId, acceptPrice, msg.sender);
    }

    function acceptQuote(uint256 bContractId, uint256 acceptPrice, address target) internal {
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);

        require( pio.getOpenPositionNumber(target) < pio.getMaxOpenPositions(), "Open21" );
        require(kyc.kycCheck(target , bC.initiator), "Open21b");  

        if (bC.state == 1){
            if (bC.initiator == bC.pA){
                bC.price = acceptPrice;
                bC.pB = target;
                require(acceptPrice <= bC.price, "Open26");
                pio.setBalance( ( bO.imB + bO.dfB) * acceptPrice / 1e18 * bC.amount / 1e18 , bC.pB, address(0), false, true);
                pio.addCumImBalances(target, bO.imB * bC.amount / 1e18 * acceptPrice / 1e18 ); // @mint
                pio.setBalance( (bO.imA + bO.dfA) * (acceptPrice - bC.price) / 1e18 * bC.amount / 1e18  , bC.pA, address(0), true, false);
                pio.removeCumImBalances(target, bO.imA * bC.amount / 1e18 * (acceptPrice - bC.price) / 1e18 ); // @mint
            }
            else if (bC.initiator == bC.pB){
                bC.price = acceptPrice;
                bC.pA = target;
                uint256 notional = bC.amount / 1e18 * acceptPrice / 1e18;
                require(acceptPrice >= bC.price, "Open28");
                pio.setBalance( ( bO.imA + bO.dfA) * notional , bC.pA, address(0), false, false);
                pio.addCumImBalances(target, bO.imA * notional); // @mint
                pio.setBalance( ((bO.imB + bO.dfB) * (acceptPrice - bC.price) / 1e18 * bC.amount / 1e18) , bC.pB, address(0), true, true);
                pio.removeCumImBalances(target, bO.imA * bC.amount / 1e18 * (acceptPrice - bC.price) / 1e18 ); // @mint
            }
            bC.openTime = block.timestamp;
            bC.state = 2;
            pio.addOpenPositionNumber(target);
            pio.setBContract(bContractId, bC);

            pio.updateCumIm(bO, bC, bContractId);
            emit acceptQuoteEvent(bContractId);
        }
    }

    function cancelOpenQuote( uint256 bContractId) public{
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        require( bC.state == 1, "Open31");
        if( msg.sender == bC.pA ){
            pio.setBalance( ( bO.imA + bO.dfA ) * bC.amount   / 1e18 * bC.price / 1e18 , msg.sender, address(0), true, false);
            pio.decreaseOpenPositionNumber(msg.sender);
            bC.state = 3; 
            pio.removeCumImBalances(msg.sender, bO.imA * bC.amount / 1e18 * bC.price / 1e18 ); // @mintyy
        }
        else{
        require( msg.sender == bC.pB, "Open32" );
            pio.setBalance( (bO.imB + bO.dfB) * bC.amount  / 1e18 * bC.price  / 1e18 , msg.sender, address(0), true, false);
            pio.decreaseOpenPositionNumber(msg.sender);
            bC.state = 3;
            pio.removeCumImBalances(msg.sender, bO.imA * bC.amount / 1e18 * bC.price / 1e18 ); // @mint
        }
        pio.setBContract(bContractId, bC);
        pio.updateCumIm(bO, bC, bContractId);
        emit cancelOpenQuoteEvent(bContractId );
    }


}   