// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.20;
// LICENSE.txt at : https://www.pioner.io/license

import "./PionerV1.sol";
import "./PionerV1Compliance.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";


/**
 * @title PionerV1 Close
 * @dev This contract manage contract closing functions
 * @notice This contract is not audited
 * @author Microderiv
 */
contract PionerV1Close is EIP712 {
    PionerV1 private pio;
    PionerV1Compliance private kyc;

    event openCloseQuoteEvent( uint256 indexed bCloseQuoteId);
    event acceptCloseQuoteEvent( uint256 indexed bCloseQuoteId);
    event expirateBContractEvent(uint256 indexed bContractId);
    event closeMarketEvent( uint256 indexed bCloseQuoteId);
    event cancelOpenCloseQuoteContractEvent(uint256 indexed bContractId);
    event cancelSignedMessageCloseEvent(address indexed sender, bytes indexed messageHash);

    constructor(address _pionerV1, address _pionerV1Compliance) EIP712("PionerV1Close", "1.0") {
        pio = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
    }

    function cancelSignedMessageClose(
        utils.CancelRequestSign calldata cancelRequest,
        bytes calldata signature
    ) public {
        bytes32 structHash = keccak256(abi.encode(
            keccak256("CancelCloseQuoteRequest(bytes targetHash,uint256 nonce)"),
            keccak256(abi.encodePacked(cancelRequest.targetHash)),
            cancelRequest.nonce
        ));

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        pio.setCancelledCloseQuotes(cancelRequest.targetHash, signer, block.timestamp);
        emit cancelSignedMessageCloseEvent(signer, cancelRequest.targetHash);
    }


    function openCloseQuoteSigned(
        utils.OpenCloseQuoteSign calldata quote,
        bytes calldata signHash,
        address wrapperSigner
    ) public {
        bytes32 structHash = keccak256(abi.encode(
            keccak256("OpenCloseQuote(uint256 bContractId,uint256 price,uint256 amount,uint256 limitOrStop,uint256 expiry,address authorized,uint256 nonce)"),
            quote.bContractId,
            quote.price,
            quote.amount,
            quote.limitOrStop,
            quote.expiry,
            quote.authorized,
            quote.nonce
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signHash);
        require((pio.getCancelledCloseQuotes(signHash, signer) + pio.getCancelTimeBuffer()) >= block.timestamp || pio.getCancelledCloseQuotes(signHash, signer) == 0, "Quote expired");
        pio.setCancelledCloseQuotes(signHash, signer, block.timestamp - pio.getCancelTimeBuffer() - 1);

        require(wrapperSigner == quote.authorized || quote.authorized == address(0), "Invalid signature or unauthorized");
        require(quote.amount != 0 && quote.price != 0, "Invalid parameters");


        utils.bCloseQuote memory newQuote = utils.bCloseQuote(
            quote.bContractId,
            quote.price,
            quote.amount,
            quote.limitOrStop,
            quote.expiry,
            signer,
            0, 
            block.timestamp,
            1  
        );  
        pio.setBCloseQuote(pio.getBCloseQuoteLength(), newQuote);
        pio.addBCloseQuoteLength();
        emit openCloseQuoteEvent(pio.getBCloseQuoteLength() - 1);
    }


     function acceptCloseQuote( uint256 bCloseQuoteId,  uint256 amount ) public{
        acceptCloseQuoteCore( bCloseQuoteId, amount, msg.sender );
     }


    function acceptCloseQuotewrapper( uint256 bCloseQuoteId,  uint256 amount, address target ) public{
        require( msg.sender == pio.getPIONERV1WRAPPERADDRESS(), "Not wrapper" );
        acceptCloseQuoteCore( bCloseQuoteId, amount, target );
     }
    
    function acceptCloseQuoteCore( uint256 bCloseQuoteId,  uint256 amount, address target ) internal {
        utils.bCloseQuote memory _bCloseQuote = pio.getBCloseQuote(bCloseQuoteId);
        utils.bContract memory bC = pio.getBContract(_bCloseQuote.bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        require( (_bCloseQuote.state == 1 && _bCloseQuote.expiry> block.timestamp ) 
        || ( _bCloseQuote.state == 1 && ( _bCloseQuote.cancelTime + pio.getCancelTimeBuffer() ) > block.timestamp), "Close23");
        if ( amount > bC.amount){
          amount = bC.amount;
          
         }
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, _bCloseQuote.price, amount, bC.interestRate, bC.openTime , bC.isAPayingAPR);

        if (_bCloseQuote.initiator == bC.pA ) { 
            require( target == bC.pB, "Close24");
            if (_bCloseQuote.limitOrStop>0){  // stop limit
                require(bO.lastPrice >= _bCloseQuote.limitOrStop, "Close25" );
            }
            else { // limit
                //require( bO.lastPrice <= _bCloseQuote.price, "Close26");
            }
        } else if ( _bCloseQuote.initiator == bC.pB ){
            require( target == bC.pA, "Close27");
            if (_bCloseQuote.limitOrStop>0){
                require(bO.lastPrice <= _bCloseQuote.limitOrStop, "Close28" );
            }
            else {
                //require( bO.lastPrice >= _bCloseQuote.price, "Close29");
            }
        }
        closePosition(bC, bO, _bCloseQuote.bContractId, uPnl, isNegative, amount, _bCloseQuote.price);
        require( _bCloseQuote.amount >= amount, "Close212");
        _bCloseQuote.amount-= amount;
        pio.setBCloseQuote(bCloseQuoteId, _bCloseQuote);
        pio.updateCumIm(bO, bC, _bCloseQuote.bContractId);

        emit acceptCloseQuoteEvent( bCloseQuoteId);
    }    

    

    function closeMarketSign(utils.CloseQuoteSign calldata closeQuote, bytes calldata signature) public {
        bytes32 structHash = keccak256(abi.encode(
            closeQuote.bCloseQuoteId,
            closeQuote.nonce
        ));

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        closeMarketCore( closeQuote.bCloseQuoteId, signer);
    }

    function closeMarket(uint256 bCloseQuoteId) public {
        closeMarketCore( bCloseQuoteId, msg.sender);
    }
    
    function closeMarketCore(uint256 bCloseQuoteId, address target) internal {
        utils.bCloseQuote memory _bCloseQuote = pio.getBCloseQuote(bCloseQuoteId);
        utils.bContract memory bC = pio.getBContract(_bCloseQuote.bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        require(bO.forceCloseType == 1, "close30" );
        require( _bCloseQuote.amount<= bC.amount + pio.getMinNotional(), "Close32");
        require( _bCloseQuote.amount* bO.lastPrice / 1e18 >= pio.getMinNotional(), "Close33");
        require(bC.state == 2, "Close34");
        require(_bCloseQuote.expiry>= block.timestamp, "Close34a");
        require( bO.lastPriceUpdateTime <= bO.maxDelay + block.timestamp, "Close34c" );
        require( block.timestamp - bC.openTime > bO.maxDelay, "Close35"); 
        require( _bCloseQuote.initiator == target, "Close36");
        require( _bCloseQuote.limitOrStop== 1, "Close37");
        require(_bCloseQuote.openTime + pio.getCancelTimeBuffer() <= block.timestamp, "Close38");
        uint256 bidAsk;
        if(target == bC.pA ){ bidAsk = bO.lastAsk; } else { bidAsk = bO.lastBid;}

        (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, _bCloseQuote.price, bC.amount, bC.interestRate, bC.openTime, bC.isAPayingAPR );
    
        if (target == bC.pA){
            require( _bCloseQuote.price<= bidAsk, "Close310");
        }
        else{
            require(target == bC.pB, "Close311");
            require( _bCloseQuote.price>= bidAsk, "Close312");
        }
        closePosition(bC, bO, _bCloseQuote.bContractId, uPnl, isNegative, _bCloseQuote.amount, _bCloseQuote.price);
        _bCloseQuote.amount= 0;
        pio.setBCloseQuote(bCloseQuoteId, _bCloseQuote);
        pio.updateCumIm(bO, bC, _bCloseQuote.bContractId);
        emit closeMarketEvent(bCloseQuoteId);
  }

    function expirateBContract( uint256 bContractId) public { 
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);

      require( bO.lastPriceUpdateTime <= bO.maxDelay + block.timestamp, "Close40" );
      require ( bC.state == 2, "Close41");

      uint256 bidAsk;
      if(msg.sender == bC.pA ){ bidAsk = bO.lastAsk; } else { bidAsk = bO.lastBid;}
      (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, bidAsk, bC.amount, bC.interestRate, bC.openTime , bC.isAPayingAPR );

      if (msg.sender == bC.pA){
          require( bC.openTime + bO.timeLock <= block.timestamp, "Close42");
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.amount, bidAsk);
      }
      else{
          require(msg.sender == bC.pB, "Close43");
          require( bC.openTime + bO.timeLock <= block.timestamp, "Close44");
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.amount, bidAsk);
      }
      pio.updateCumIm(bO, bC, bContractId);
      emit expirateBContractEvent(bContractId);
  }    

    // case where Oracle not update for 7 days
    // note : oracle doesnt update if price is same as before
  function expirateBContractOracleTimeout( uint256 bContractId) public { 
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
      require( 7 days < block.timestamp - bO.lastPriceUpdateTime, "Close40" );
      require ( bC.state == 2, "Close41");
      (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, bO.lastPrice, bC.amount, bC.interestRate, bC.openTime , bC.isAPayingAPR );
      require( bC.openTime + bO.timeLock > block.timestamp, "Close44");
      if (msg.sender == bC.pA){
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.amount, bO.lastPrice);
      }
      else{
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.amount, bO.lastPrice);
      }
      pio.updateCumIm(bO, bC, bContractId);
      emit expirateBContractEvent(bContractId);
  }    

  function closePosition(utils.bContract memory bC, utils.bOracle memory bO, uint256 bContractId, uint256 toPay, bool isNegative, uint256 amount, uint256 price) internal{ 
      uint256 ir = utils.calculateIr(bC.interestRate, (block.timestamp - bC.openTime ), price, amount) * pio.getTotalShare()  /1e18;
      uint256 notional = bC.price * amount / 1e18;
      uint256 collatRequirA = ( bO.imA + bO.dfA) * notional / 1e18;
      uint256 collatRequirB = ( bO.imB + bO.dfB) * notional / 1e18;
      uint256 paid;
      require(bO.maxDelay + block.timestamp >= bO.lastPriceUpdateTime, "Close51");
      if(isNegative){
        if( toPay >= collatRequirA){
            paid = pio.setBalance( toPay - collatRequirA , bC.pA, bC.pB, false, false) + collatRequirA;
            pio.addToOwed( toPay - paid, bC.pA, bC.pB);
        } else {
            paid = pio.setBalance( collatRequirA - toPay, bC.pA, address(0), true, false);
            paid = toPay;
        }  
          if(ir <= paid + collatRequirB ){
            pio.payFundingShare( ir);
            pio.setBalance( paid + collatRequirB - ir  , bC.pB, address(0), true, false);
          }
          
      }
      else{
        if(toPay >= collatRequirB ){
            paid = pio.setBalance( toPay - collatRequirB, bC.pB, bC.pA, false, false) + collatRequirB;
            pio.addToOwed( toPay - paid, bC.pB, bC.pA);
        } else {
            paid = pio.setBalance( collatRequirB - toPay, bC.pB, address(0), true, false);
            paid = toPay;
        }
          if(ir <= paid + collatRequirA  ){
            pio.payFundingShare( ir);
            pio.setBalance( paid + collatRequirA - ( ir  ) , bC.pA, address(0), true, false);
          } 
      }
      bC.amount -= amount;
      if( bC.amount == 0){
          bC.state = 3;
          pio.decreaseOpenPositionNumber(bC.pA);
          pio.decreaseOpenPositionNumber(bC.pB);
      }
      pio.setBContract(bContractId, bC);
    }

    // delete and repush to modify a inner order
    function cancelCloseQuote(uint256 bCloseQuoteId) public {
        utils.bCloseQuote memory _bCloseQuote = pio.getBCloseQuote(bCloseQuoteId);
        require(_bCloseQuote.state != 4, "Quote already canceled");
        _bCloseQuote.state = 4;
            _bCloseQuote.cancelTime = block.timestamp;
        pio.setBCloseQuote(bCloseQuoteId, _bCloseQuote);
        emit cancelOpenCloseQuoteContractEvent(bCloseQuoteId);
    }

}