// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


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
            keccak256(abi.encodePacked(cancelRequest.orderHash)), 
            cancelRequest.nonce
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        pio.setCancelledOpenQuotes(cancelRequest.orderHash, signer, block.timestamp);
        emit cancelSignedMessageOpenEvent(signer, cancelRequest.orderHash);
    }


    function openQuoteSigned( 
        utils.OpenQuoteSign calldata openQuoteSign,
        bytes calldata signHash,
        address warperSigner
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
        require((pio.getCancelledOpenQuotes(signHash, signer)  + pio.getCancelTimeBuffer()) <= block.timestamp || pio.getCancelledOpenQuotes(signHash, signer)  == 0, "Quote expired");
        pio.setCancelledOpenQuotes(signHash, signer, 1) ;
        require(openQuoteSign.authorized == address(0) || signer == openQuoteSign.authorized, "Invalid signature or unauthorized");

        utils.bContract memory bC = pio.getBContract(pio.getBContractLength());
        utils.bOracle memory bO = pio.getBOracle(openQuoteSign.bOracleId);

        require( pio.getOpenPositionNumber(signer) <= pio.getMaxOpenPositions(), "Open11" );
        require(openQuoteSign.amount * openQuoteSign.price / 1e18 >= pio.getMinNotional(), "Open12");
        require(kyc.kycCheck(signer , address(0)), "Open12b");

        bC.initiator = signer;
        bC.price = openQuoteSign.price;
        bC.amount = openQuoteSign.amount;
        bC.interestRate = openQuoteSign.interestRate;
        bC.isAPayingAPR = openQuoteSign.isAPayingAPR;
        bC.oracleId = openQuoteSign.bOracleId;
        bC.state = 1;
        bC.frontEnd = openQuoteSign.frontEnd;
        bC.affiliate = openQuoteSign.affiliate;
        
        if(openQuoteSign.isLong){
            pio.setBalance( (bO.imA + bO.dfA) * openQuoteSign.amount / 1e18 * openQuoteSign.price / 1e18, signer, address(0), false, true);
            bC.pA = signer;
        }
        else{
            pio.setBalance( (bO.imB + bO.dfB) * openQuoteSign.amount / 1e18 * openQuoteSign.price / 1e18 , signer, address(0), false, true);
            bC.pB = signer;
        }   

        if(warperSigner != address(0)){
            require(warperSigner == signer, "warperSigner missmatch");

        }

        emit openQuoteSignedEvent( pio.getBContractLength(), signHash);
        pio.setBContract(pio.getBContractLength(), bC);
        pio.addBContractLength();
        pio.addOpenPositionNumber(signer);
        pio.updateCumIm(bO, bC, pio.getBContractLength() - 1);
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
        utils.bContract memory bC = pio.getBContract(pio.getBContractLength());
        utils.bOracle memory bO = pio.getBOracle(bOracleId);

        require( pio.getOpenPositionNumber(msg.sender) <= pio.getMaxOpenPositions(), "Open11" );
        require(amount * price / 1e18 >= pio.getMinNotional(), "Open12");
        require(kyc.kycCheck(msg.sender , address(0)), "Open12b");

        bC.initiator = msg.sender;
        bC.price = price;
        bC.amount = amount;
        bC.interestRate = interestRate;
        bC.isAPayingAPR = isAPayingAPR;
        bC.oracleId = bOracleId;
        bC.state = 1;
        bC.frontEnd = frontEnd;
        bC.affiliate = affiliate;
        
        if(isLong){
            pio.setBalance( (bO.imA + bO.dfA) * amount / 1e18 * price / 1e18, msg.sender, address(0), false, true);
            bC.pA = msg.sender;
        }
        else{
            pio.setBalance( (bO.imB + bO.dfB) * amount / 1e18 * price / 1e18 , msg.sender, address(0), false, true);
            bC.pB = msg.sender;
        }   

        emit openQuoteEvent( pio.getBContractLength());
        pio.setBContract(pio.getBContractLength(), bC);
        pio.addBContractLength();
        pio.addOpenPositionNumber(msg.sender);
        pio.updateCumIm(bO, bC, pio.getBContractLength() - 1);
    }

    function acceptQuoteSigned(utils.AcceptQuoteSign calldata acceptQuoteSign, bytes calldata signHash) public {
        bytes32 structHash = keccak256(abi.encode(
            keccak256("AcceptQuote(uint256 bContractId,uint256 acceptPrice,address backendAffiliate,uint256 amount,uint256 nonce)"),
            acceptQuoteSign.bContractId,
            acceptQuoteSign.acceptPrice,
            acceptQuoteSign.backendAffiliate,
            acceptQuoteSign.amount,
            acceptQuoteSign.nonce
        ));
         bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signHash);
        require((pio.getCancelledOpenQuotes(signHash, signer)  + pio.getCancelTimeBuffer()) <= block.timestamp || pio.getCancelledOpenQuotes(signHash, signer)  == 0, "Quote expired");
        pio.setCancelledOpenQuotes(signHash, signer, block.timestamp - pio.getCancelTimeBuffer() -1);

        utils.bContract memory bC = pio.getBContract(acceptQuoteSign.bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);

        require( pio.getOpenPositionNumber(signer) < pio.getMaxOpenPositions(), "Open21" );
        require(kyc.kycCheck(signer , bC.initiator), "Open21b");   

        if (bC.state == 1){
            if (bC.initiator == bC.pA){
                bC.price = acceptQuoteSign.acceptPrice;
                bC.pB = signer;
                require(acceptQuoteSign.acceptPrice <= bC.price, "Open26");
                pio.setBalance( ( bO.imB + bO.dfB) * acceptQuoteSign.acceptPrice / 1e18 * bC.amount / 1e18 , bC.pB, address(0), false, true);
                pio.addCumImBalances(signer, bO.imB * bC.amount / 1e18 * acceptQuoteSign.acceptPrice / 1e18 ); // @mint
                pio.setBalance( (bO.imA + bO.dfA) * (acceptQuoteSign.acceptPrice - bC.price) / 1e18 * bC.amount / 1e18  , bC.pA, address(0), true, false);
                pio.removeCumImBalances(signer, bO.imA * bC.amount / 1e18 * (acceptQuoteSign.acceptPrice - bC.price) / 1e18 ); // @mint
            }
            else if (bC.initiator == bC.pB){
                bC.price = acceptQuoteSign.acceptPrice;
                bC.pA = signer;
                require(acceptQuoteSign.acceptPrice >= bC.price, "Open28");
                pio.setBalance( ( bO.imA + bO.dfA) * acceptQuoteSign.acceptPrice / 1e18 * bC.amount / 1e18  , bC.pA, address(0), false, false);
                pio.addCumImBalances(signer, bO.imA * bC.amount / 1e18 * acceptQuoteSign.acceptPrice / 1e18 ); // @mint
                pio.setBalance( ((bO.imB + bO.dfB) * (acceptQuoteSign.acceptPrice - bC.price) / 1e18 * bC.amount / 1e18) , bC.pB, address(0), true, true);
                pio.removeCumImBalances(signer, bO.imA * bC.amount / 1e18 * (acceptQuoteSign.acceptPrice - bC.price) / 1e18 ); // @mint
            }
            bC.openTime = block.timestamp;
            bC.hedger = acceptQuoteSign.backendAffiliate;
            bC.state = 2;
            pio.addOpenPositionNumber(signer);
            pio.setBContract(acceptQuoteSign.bContractId, bC);

            pio.updateCumIm(bO, bC, acceptQuoteSign.bContractId);
            emit acceptQuoteEvent(acceptQuoteSign.bContractId);
        }
    }

    function acceptQuote(uint256 bContractId, uint256 _acceptPrice, address backendAffiliate) public {
        require( pio.getOpenPositionNumber(msg.sender) < pio.getMaxOpenPositions(), "Open21" );
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        require(kyc.kycCheck(msg.sender , bC.initiator), "Open21b");   

        if(bC.openTime == block.timestamp && bC.state == 2) {
            if(bC.initiator == bC.pA && _acceptPrice < bC.price) { 
                pio.setBalance( utils.getNotional(bO, bC, false) , bC.pB, address(0), true, false);
                pio.removeCumImBalances(msg.sender, bO.imA * bC.amount / 1e18 * bC.price / 1e18 ); // @mint
                pio.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.amount / 1e18  , msg.sender, address(0), false, true);
                
                pio.setBalance( ((1e18+(bO.imA + bO.dfA)) * ( _acceptPrice - bC.price ) / 1e18 * bC.amount / 1e18) , bC.pA, address(0), true, false);
                pio.decreaseOpenPositionNumber(bC.pB);
                bC.pB = msg.sender;
                bC.price = _acceptPrice;
                }
            else if(bC.initiator == bC.pB && _acceptPrice > bC.price) { 
                pio.setBalance( utils.getNotional(bO, bC, true) , bC.pA, address(0), true, true);
                pio.removeCumImBalances(msg.sender, bO.imA * bC.amount / 1e18 * bC.price / 1e18 ); // @mint
                pio.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.amount / 1e18  , msg.sender, address(0), false, true);
                pio.setBalance( ((1e18+(bO.imB + bO.dfB)) * (bC.price - _acceptPrice ) / 1e18 * bC.amount / 1e18 ) , bC.pB, address(0), false, true);
                pio.decreaseOpenPositionNumber(bC.pA);
                bC.pA = msg.sender;
                bC.price = _acceptPrice;
                

                }
            emit acceptQuoteEvent(bContractId);
        } else if (bC.state == 1){
            if (bC.initiator == bC.pA){
                bC.price = _acceptPrice;
                bC.pB = msg.sender;
                require(_acceptPrice <= bC.price, "Open26");
                pio.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.amount / 1e18 , bC.pB, address(0), false, true);
                pio.addCumImBalances(msg.sender, bO.imB * bC.amount / 1e18 * _acceptPrice / 1e18 ); // @mint
                pio.setBalance( (bO.imA + bO.dfA) * (_acceptPrice - bC.price) / 1e18 * bC.amount / 1e18  , bC.pA, address(0), true, false);
                pio.removeCumImBalances(msg.sender, bO.imA * bC.amount / 1e18 * (_acceptPrice - bC.price) / 1e18 ); // @mint
            }
            else if (bC.initiator == bC.pB){
                bC.price = _acceptPrice;
                bC.pA = msg.sender;
                require(_acceptPrice >= bC.price, "Open28");
                pio.setBalance( ( bO.imA + bO.dfA) * _acceptPrice / 1e18 * bC.amount / 1e18  , bC.pA, address(0), false, false);
                pio.addCumImBalances(msg.sender, bO.imA * bC.amount / 1e18 * _acceptPrice / 1e18 ); // @mint
                pio.setBalance( ((bO.imB + bO.dfB) * (_acceptPrice - bC.price) / 1e18 * bC.amount / 1e18) , bC.pB, address(0), true, true);
                pio.removeCumImBalances(msg.sender, bO.imA * bC.amount / 1e18 * (_acceptPrice - bC.price) / 1e18 ); // @mint
            }
            bC.openTime = block.timestamp;
            bC.hedger = backendAffiliate;
            bC.state = 2;
            pio.addOpenPositionNumber(msg.sender);
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
            pio.removeCumImBalances(msg.sender, bO.imA * bC.amount / 1e18 * bC.price / 1e18 ); // @mint
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