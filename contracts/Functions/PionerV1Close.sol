// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;
// LICENSE.txt at : https://www.pioner.io/license

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";

import "hardhat/console.sol";


/**
 * @title PionerV1 Close
 * @dev This contract manage contract closing functions
 * @notice This contract is not audited
 * @author Microderiv
 */
contract PionerV1Close {
    PionerV1 private pio;
    PionerV1Compliance private kyc;

    event openCloseQuoteEvent( uint256 indexed bCloseQuoteId);
    event acceptCloseQuoteEvent( uint256 indexed bCloseQuoteId);
    event expirateBContractEvent(uint256 indexed bContractId);
    event closeMarketEvent( uint256 indexed bCloseQuoteId);
    event cancelOpenCloseQuoteContractEvent(uint256 indexed bContractId);

    event Cancelled(address indexed sender, bytes32 indexed messageHash);

    mapping(bytes32 => bool) private cancelledMessages;


    constructor(address _pionerV1, address _pionerV1Compliance) {
        pio = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
    }

    function cancelSignedMessage(bytes32 messageHash) public {
        cancelledMessages[messageHash] = true;
        emit Cancelled(msg.sender, messageHash);
    }

    function openCloseQuote(
        uint256[] memory bContractIds,
        uint256[] memory price,
        uint256[] memory qty,
        uint256[] memory limitOrStop,
        uint256[] memory expiry,
        bytes32 messageHash,
        bytes memory signature
    ) public {
        require(!cancelledMessages[messageHash], "Close10a");
        require( utils.verifySignatureCloseQuote(msg.sender,messageHash, signature ), "Close10b");
        require(
            bContractIds.length == price.length && 
            price.length == qty.length && 
            qty.length == limitOrStop.length &&
            qty.length == expiry.length,
            "Close11"
        );
        for (uint256 i = 0; i < qty.length; i++) {
            require(qty[i] != 0, "Close12");
            require(price[i] != 0, "Close13");
        }

        utils.bCloseQuote memory newQuote = utils.bCloseQuote(
            bContractIds,
            price,
            qty,
            limitOrStop,
            expiry,
            msg.sender,
            0,                 
            block.timestamp,
            1
        );
        pio.setBCloseQuote(pio.getBCloseQuoteLength(), newQuote);
        pio.addBCloseQuoteLength();
        emit openCloseQuoteEvent(pio.getBCloseQuoteLength() - 1 );
    }


    function openCloseQuote(
        uint256[] memory bContractIds,
        uint256[] memory price, 
        uint256[] memory qty, 
        uint256[] memory limitOrStop, 
        uint256[] memory expiry
    ) public {

        require(
            bContractIds.length == price.length && 
            price.length == qty.length && 
            qty.length == limitOrStop.length &&
            qty.length == expiry.length,
            "Close11"
        );
        for (uint256 i = 0; i < qty.length; i++) {
            require(qty[i] != 0, "Close12");
            require(price[i] != 0, "Close13");
        }

        utils.bCloseQuote memory newQuote = utils.bCloseQuote(
            bContractIds,
            price,
            qty,
            limitOrStop,
            expiry,
            msg.sender,
            0,                 
            block.timestamp,
            1
        );
        pio.setBCloseQuote(pio.getBCloseQuoteLength(), newQuote);
        pio.addBCloseQuoteLength();
        emit openCloseQuoteEvent(pio.getBCloseQuoteLength() - 1 );
    }


    
    function acceptCloseQuote( uint256 bCloseQuoteId, uint256 index, uint256 amount ) public {
        utils.bCloseQuote memory _bCloseQuote = pio.getBCloseQuote(bCloseQuoteId);
        utils.bContract memory bC = pio.getBContract(_bCloseQuote.bContractIds[index]);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        
        require(index < _bCloseQuote.bContractIds.length, "Close21");
        require( (_bCloseQuote.state == 1 && _bCloseQuote.expiry[index] > block.timestamp ) 
        || ( _bCloseQuote.state == 1 && ( _bCloseQuote.cancelTime + pio.getCancelTimeBuffer() ) > block.timestamp), "Close23");
        if ( amount > bC.qty){
          amount = bC.qty;
         }
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, _bCloseQuote.price[index], amount, bC.interestRate, bC.openTime , bC.isAPayingAPR);

        if (_bCloseQuote.initiator == bC.pA ) { 
            require( msg.sender == bC.pB, "Close24");
            if (_bCloseQuote.limitOrStop[index] >0){  // stop limit
                require(bO.lastPrice >= _bCloseQuote.limitOrStop[index], "Close25" );
            }
            else { // limit
                //require( bO.lastPrice <= _bCloseQuote.price[index], "Close26");
            }
        } else if ( _bCloseQuote.initiator == bC.pB ){
            require( msg.sender == bC.pA, "Close27");
            if (_bCloseQuote.limitOrStop[index] >0){
                require(bO.lastPrice <= _bCloseQuote.limitOrStop[index], "Close28" );
            }
            else {
                //require( bO.lastPrice >= _bCloseQuote.price[index], "Close29");
            }
        }
        require( amount <= bC.qty + pio.getMinNotional(), "Close210");
        require( amount >= pio.getMinNotional() / bC.qty / 1e18, "Close211");

        closePosition(bC, bO, _bCloseQuote.bContractIds[index], uPnl, isNegative, amount, _bCloseQuote.price[index]);
        _bCloseQuote.qty[index] -= amount;
        pio.setBCloseQuote(bCloseQuoteId, _bCloseQuote);
        pio.updateCumIm(bO, bC, _bCloseQuote.bContractIds[index]);

        emit acceptCloseQuoteEvent( bCloseQuoteId);
    }    

    
    function closeMarket(uint256 bCloseQuoteId, uint256 index) public {
        utils.bCloseQuote memory _bCloseQuote = pio.getBCloseQuote(bCloseQuoteId);
        utils.bContract memory bC = pio.getBContract(_bCloseQuote.bContractIds[index]);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);
        require(bO.forceCloseType == 1, "close30" );
        require(index < _bCloseQuote.bContractIds.length, "Close31");
        require( _bCloseQuote.qty[index] <= bC.qty + pio.getMinNotional(), "Close32");
        require( _bCloseQuote.qty[index] * bO.lastPrice / 1e18 >= pio.getMinNotional(), "Close33");
        require(bC.state == 2, "Close34");
        require(_bCloseQuote.expiry[index] >= block.timestamp, "Close34a");
        require( bO.lastPriceUpdateTime <= bO.maxDelay + block.timestamp, "Close34c" );
        require(block.timestamp - bC.openTime > bO.maxDelay, "Close35"); 
        require( _bCloseQuote.initiator == msg.sender, "Close36");
        require( _bCloseQuote.limitOrStop[index] == 1, "Close37");
        require(_bCloseQuote.openTime + pio.getCancelTimeBuffer() <= block.timestamp, "Close38");
        uint256 bidAsk;
        if(msg.sender == bC.pA ){ bidAsk = bO.lastAsk; } else { bidAsk = bO.lastBid;}

        (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, _bCloseQuote.price[index], bC.qty, bC.interestRate, bC.openTime, bC.isAPayingAPR );

        if (msg.sender == bC.pA){
            require( _bCloseQuote.price[index] <= bidAsk, "Close310");
        }
        else{
            require(msg.sender == bC.pB, "Close311");
            require( _bCloseQuote.price[index] >= bidAsk, "Close312");
        }
        closePosition(bC, bO, _bCloseQuote.bContractIds[index], uPnl, isNegative, _bCloseQuote.qty[index], _bCloseQuote.price[index]);
        _bCloseQuote.qty[index] = 0;
        pio.setBCloseQuote(bCloseQuoteId, _bCloseQuote);
        pio.updateCumIm(bO, bC, _bCloseQuote.bContractIds[index]);
        emit closeMarketEvent(bCloseQuoteId);
  }

    function expirateBContract( uint256 bContractId) public { 
        utils.bContract memory bC = pio.getBContract(bContractId);
        utils.bOracle memory bO = pio.getBOracle(bC.oracleId);

      require( bO.lastPriceUpdateTime <= bO.maxDelay + block.timestamp, "Close40" );
      require ( bC.state == 2, "Close41");

      uint256 bidAsk;
      if(msg.sender == bC.pA ){ bidAsk = bO.lastAsk; } else { bidAsk = bO.lastBid;}
      (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, bidAsk, bC.qty, bC.interestRate, bC.openTime , bC.isAPayingAPR );

      if (msg.sender == bC.pA){
          require( bC.openTime + bO.timeLockA <= block.timestamp, "Close42");
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.qty, bidAsk);
      }
      else{
          require(msg.sender == bC.pB, "Close43");
          require( bC.openTime + bO.timeLockB <= block.timestamp, "Close44");
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.qty, bidAsk);
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
      (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, bO.lastPrice, bC.qty, bC.interestRate, bC.openTime , bC.isAPayingAPR );
      if (msg.sender == bC.pA){
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.qty, bO.lastPrice);
      }
      else{
          require( bC.openTime + bO.timeLockB > block.timestamp, "Close44");
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.qty, bO.lastPrice);
      }
      pio.updateCumIm(bO, bC, bContractId);
      emit expirateBContractEvent(bContractId);
  }    

  function closePosition(utils.bContract memory bC, utils.bOracle memory bO, uint256 bContractId, uint256 toPay, bool isNegative, uint256 amount, uint256 price) internal{ 
      uint256 ir = utils.calculateIr(bC.interestRate, (block.timestamp - bC.openTime ), price, amount);
      uint256 notional = bC.price * amount / 1e18;
      uint256 collatRequirA = ( bO.imA + bO.dfA) * notional / 1e18;
      uint256 collatRequirB = ( bO.imB + bO.dfB) * notional / 1e18;
      uint256 paid;
      require(bO.maxDelay + block.timestamp >= bO.lastPriceUpdateTime, "Close51");
      if(isNegative){
        if( toPay >= collatRequirA){
            paid = pio.setBalance( toPay - collatRequirA , bC.pA, bC.pB, false, false);
            pio.addToOwed( toPay - paid, bC.pA, bC.pB);
        } else {
            paid = pio.setBalance( collatRequirA - toPay, bC.pA, address(0), true, false);
        }
          pio.payAffiliates( ir * pio.getTotalShare() /1e18, bC.frontEnd, bC.frontEnd, bC.hedger);
          pio.setBalance( paid + collatRequirB - (  ir * pio.getTotalShare()/1e18 ) , bC.pB, address(0), true, false);
      }
      else{
        if(toPay >= collatRequirB ){
            paid = pio.setBalance( toPay - collatRequirB, bC.pB, bC.pA, false, false);
            pio.addToOwed( toPay - paid, bC.pB, bC.pA);
        } else {
            paid = pio.setBalance( collatRequirB - toPay, bC.pB, address(0), true, false);
        }
          pio.payAffiliates( ir * pio.getTotalShare() /1e18, bC.frontEnd, bC.frontEnd, bC.hedger);
          pio.setBalance( paid + collatRequirA - ( ir * pio.getTotalShare()  /1e18 ) , bC.pA, address(0), true, false);

          
      }
      bC.qty -= amount;

      if( bC.qty == 0){
          bC.state = 3;
          pio.decreaseOpenPositionNumber(msg.sender);
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