// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";

import "hardhat/console.sol";

/**
 * @title PionerV1 Open
 * @dev This contract manage contract opening functions.
 * @notice This contract is not audited
 * @author Microderiv
 */
contract PionerV1Open {
    PionerV1 private pio;
    PionerV1Compliance private kyc;

    event openQuoteEvent( uint256 indexed bContractId); 
    event openQuoteSignedEvent( uint256 indexed bContractId,bytes32 indexed fillAPIEventId); 
    event cancelSignedMessageOpenEvent(address indexed sender, bytes32 indexed messageHash);

    event acceptQuoteEvent( uint256 indexed bContractId); 
    event cancelOpenQuoteEvent( uint256 indexed bContractId);

    constructor(address _pionerV1, address _pionerV1Compliance) {
        pio = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
    }

    mapping(bytes32 => uint256) private cancelledOpenQuotes;
    

    function cancelSignedMessageOpen(
        bytes32 targetHash,
        bytes32 signHash,
        bytes memory signature
    ) public {
        bytes32 paramsHash = keccak256(abi.encodePacked(targetHash));
        require(utils.verifySignature(paramsHash, signature) == utils.verifySignature(signHash, signature), "Unauthorized");
        cancelledOpenQuotes[signHash] = block.timestamp;
        emit cancelSignedMessageOpenEvent(msg.sender, signHash);
    }

    function openQuoteSigned( 
        bool isLong,
        uint256 bOracleId,
        uint256 price,
        uint256 qty,
        uint256 interestRate, 
        bool isAPayingAPR, 
        address frontEnd, 
        address affiliate,
        address authorized,
        bytes32 signHash,
        bytes memory signature
        ) public {

        require((cancelledOpenQuotes[signHash]+ pio.getCancelTimeBuffer()) <= block.timestamp || cancelledOpenQuotes[signHash] == 0, "Quote expired");
        cancelledOpenQuotes[signHash]=block.timestamp - pio.getCancelTimeBuffer() -1;
        address signer = utils.verifySignature(signHash, signature);    
        console.log(signer, "signer");
        bytes32 paramsHash = keccak256(abi.encodePacked(block.chainid, address(this), isLong, bOracleId, price, qty, interestRate, isAPayingAPR, frontEnd, affiliate, authorized));
        require(signHash == paramsHash, "Hash mismatch");
        require(authorized == address(0) || signer == authorized, "Invalid signature or unauthorized");

        utils.bContract memory bC = pio.getBContract(pio.getBContractLength());
        utils.bOracle memory bO = pio.getBOracle(bOracleId);

        require( pio.getOpenPositionNumber(signer) <= pio.getMaxOpenPositions(), "Open11" );
        require(qty * price / 1e18 >= pio.getMinNotional(), "Open12");
        require(kyc.kycCheck(signer , address(0)), "Open12b");

        bC.initiator = signer;
        bC.price = price;
        bC.qty = qty;
        bC.interestRate = interestRate;
        bC.isAPayingAPR = isAPayingAPR;
        bC.oracleId = bOracleId;
        bC.state = 1;
        bC.frontEnd = frontEnd;
        bC.affiliate = affiliate;
        
        if(isLong){
            pio.setBalance( (bO.imA + bO.dfA) * qty / 1e18 * price / 1e18, signer, address(0), false, true);
            bC.pA = signer;
        }
        else{
            pio.setBalance( (bO.imB + bO.dfB) * qty / 1e18 * price / 1e18 , signer, address(0), false, true);
            bC.pB = signer;
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
        uint256 qty,
        uint256 interestRate, 
        bool isAPayingAPR, 
        address frontEnd, 
        address affiliate
    ) public {
        utils.bContract memory bC = pio.getBContract(pio.getBContractLength());
        utils.bOracle memory bO = pio.getBOracle(bOracleId);

        require( pio.getOpenPositionNumber(msg.sender) <= pio.getMaxOpenPositions(), "Open11" );
        require(qty * price / 1e18 >= pio.getMinNotional(), "Open12");
        require(kyc.kycCheck(msg.sender , address(0)), "Open12b");

        bC.initiator = msg.sender;
        bC.price = price;
        bC.qty = qty;
        bC.interestRate = interestRate;
        bC.isAPayingAPR = isAPayingAPR;
        bC.oracleId = bOracleId;
        bC.state = 1;
        bC.frontEnd = frontEnd;
        bC.affiliate = affiliate;
        
        if(isLong){
            pio.setBalance( (bO.imA + bO.dfA) * qty / 1e18 * price / 1e18, msg.sender, address(0), false, true);
            bC.pA = msg.sender;
        }
        else{
            pio.setBalance( (bO.imB + bO.dfB) * qty / 1e18 * price / 1e18 , msg.sender, address(0), false, true);
            bC.pB = msg.sender;
        }   

        emit openQuoteEvent( pio.getBContractLength());
        pio.setBContract(pio.getBContractLength(), bC);
        pio.addBContractLength();
        pio.addOpenPositionNumber(msg.sender);
        pio.updateCumIm(bO, bC, pio.getBContractLength() - 1);
    }

    function acceptQuoteSigned(uint256 bContractId, uint256 _acceptPrice, address backendAffiliate, uint256 amount, bytes32 signHash, bytes memory signature) public {
        require(cancelledOpenQuotes[signHash] == 0, "Quote expired");
        cancelledOpenQuotes[signHash]=block.timestamp - pio.getCancelTimeBuffer() -1;
        address signer = utils.verifySignature(signHash, signature);
        bytes32 paramsHash = keccak256(abi.encodePacked(block.chainid, address(this), bContractId, _acceptPrice, backendAffiliate, amount));
        require(signHash == paramsHash, "Hash mismatch");

        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        require(bC.initiator == msg.sender , "Invalid signature or unauthorized");

        require( pio.getOpenPositionNumber(signer) < pio.getMaxOpenPositions(), "Open21" );
        require(kyc.kycCheck(signer , bC.initiator), "Open21b");   

        if (bC.state == 1){
            if (bC.initiator == bC.pA){
                bC.price = _acceptPrice;
                bC.pB = signer;
                require(_acceptPrice <= bC.price, "Open26");
                pio.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.qty / 1e18 , bC.pB, address(0), false, true);
                pio.addCumImBalances(signer, bO.imB * bC.qty / 1e18 * _acceptPrice / 1e18 ); // @mint
                pio.setBalance( (bO.imA + bO.dfA) * (_acceptPrice - bC.price) / 1e18 * bC.qty / 1e18  , bC.pA, address(0), true, false);
                pio.removeCumImBalances(signer, bO.imA * bC.qty / 1e18 * (_acceptPrice - bC.price) / 1e18 ); // @mint
            }
            else if (bC.initiator == bC.pB){
                bC.price = _acceptPrice;
                bC.pA = signer;
                require(_acceptPrice >= bC.price, "Open28");
                pio.setBalance( ( bO.imA + bO.dfA) * _acceptPrice / 1e18 * bC.qty / 1e18  , bC.pA, address(0), false, false);
                pio.addCumImBalances(signer, bO.imA * bC.qty / 1e18 * _acceptPrice / 1e18 ); // @mint
                pio.setBalance( ((bO.imB + bO.dfB) * (_acceptPrice - bC.price) / 1e18 * bC.qty / 1e18) , bC.pB, address(0), true, true);
                pio.removeCumImBalances(signer, bO.imA * bC.qty / 1e18 * (_acceptPrice - bC.price) / 1e18 ); // @mint
            }
            bC.openTime = block.timestamp;
            bC.hedger = backendAffiliate;
            bC.state = 2;
            pio.addOpenPositionNumber(signer);
            pio.setBContract(bContractId, bC);

            pio.updateCumIm(bO, bC, bContractId);
            emit acceptQuoteEvent(bContractId);
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
                pio.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * bC.price / 1e18 ); // @mint
                pio.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.qty / 1e18  , msg.sender, address(0), false, true);
                
                pio.setBalance( ((1e18+(bO.imA + bO.dfA)) * ( _acceptPrice - bC.price ) / 1e18 * bC.qty / 1e18) , bC.pA, address(0), true, false);
                pio.decreaseOpenPositionNumber(bC.pB);
                bC.pB = msg.sender;
                bC.price = _acceptPrice;
                }
            else if(bC.initiator == bC.pB && _acceptPrice > bC.price) { 
                pio.setBalance( utils.getNotional(bO, bC, true) , bC.pA, address(0), true, true);
                pio.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * bC.price / 1e18 ); // @mint
                pio.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.qty / 1e18  , msg.sender, address(0), false, true);
                pio.setBalance( ((1e18+(bO.imB + bO.dfB)) * (bC.price - _acceptPrice ) / 1e18 * bC.qty / 1e18 ) , bC.pB, address(0), false, true);
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
                pio.setBalance( ( bO.imB + bO.dfB) * _acceptPrice / 1e18 * bC.qty / 1e18 , bC.pB, address(0), false, true);
                pio.addCumImBalances(msg.sender, bO.imB * bC.qty / 1e18 * _acceptPrice / 1e18 ); // @mint
                pio.setBalance( (bO.imA + bO.dfA) * (_acceptPrice - bC.price) / 1e18 * bC.qty / 1e18  , bC.pA, address(0), true, false);
                pio.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * (_acceptPrice - bC.price) / 1e18 ); // @mint
            }
            else if (bC.initiator == bC.pB){
                bC.price = _acceptPrice;
                bC.pA = msg.sender;
                require(_acceptPrice >= bC.price, "Open28");
                pio.setBalance( ( bO.imA + bO.dfA) * _acceptPrice / 1e18 * bC.qty / 1e18  , bC.pA, address(0), false, false);
                pio.addCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * _acceptPrice / 1e18 ); // @mint
                pio.setBalance( ((bO.imB + bO.dfB) * (_acceptPrice - bC.price) / 1e18 * bC.qty / 1e18) , bC.pB, address(0), true, true);
                pio.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * (_acceptPrice - bC.price) / 1e18 ); // @mint
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
            pio.setBalance( ( bO.imA + bO.dfA ) * bC.qty   / 1e18 * bC.price / 1e18 , msg.sender, address(0), true, false);
            pio.decreaseOpenPositionNumber(msg.sender);
            bC.state = 3; 
            pio.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * bC.price / 1e18 ); // @mint
        }
        else{
        require( msg.sender == bC.pB, "Open32" );
            pio.setBalance( (bO.imB + bO.dfB) * bC.qty  / 1e18 * bC.price  / 1e18 , msg.sender, address(0), true, false);
            pio.decreaseOpenPositionNumber(msg.sender);
            bC.state = 3;
            pio.removeCumImBalances(msg.sender, bO.imA * bC.qty / 1e18 * bC.price / 1e18 ); // @mint
        }
        pio.setBContract(bContractId, bC);
        pio.updateCumIm(bO, bC, bContractId);
        emit cancelOpenQuoteEvent(bContractId );
    }

}