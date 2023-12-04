// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
// LICENSE.txt at : https://www.pioner.io/license

import "../PionerV1.sol";
import "./PionerV1Compliance.sol";

import "hardhat/console.sol";


contract PionerV1Close {
    PionerV1 private pnr;
    PionerV1Compliance private kyc;

    constructor(address _pionerV1, address _pionerV1Compliance) {
        pnr = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
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
            utils.cState.Quote
        );
        pnr.setBCloseQuote(pnr.getBCloseQuoteLength(), newQuote);
        pnr.addBCloseQuoteLength();
        //emit openCloseQuoteEvent(msg.sender, getBCloseQuoteLength()--, bContractIds, price, qty, limitOrStop, expiration );
    }
    
    function acceptCloseQuote( uint256 bCloseQuoteId, uint256 index, uint256 amount ) public {
        utils.bCloseQuote memory _bCloseQuote = pnr.getBCloseQuote(bCloseQuoteId);
        utils.bContract memory bC = pnr.getBContract(_bCloseQuote.bContractIds[index]);
        utils.bOracle memory bO = pnr.getBOracle(bC.oracleId);
        
        require(index < _bCloseQuote.bContractIds.length, "Close21");
        require( (_bCloseQuote.state == utils.cState.Quote && _bCloseQuote.expiry[index] > block.timestamp ) || 
        ( _bCloseQuote.state == utils.cState.Quote && ( _bCloseQuote.cancelTime + pnr.getCancelTimeBuffer() ) > block.timestamp), "Close23");
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, _bCloseQuote.price[index], bC.qty, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR);
        if(_bCloseQuote.qty[index] >= bC.qty){
            amount = bC.qty;
        }
        else{
            amount = _bCloseQuote.qty[index];
        }
        if (_bCloseQuote.initiator == bC.pA ) { 
            require( msg.sender == bC.pB, "Close24");
            if (_bCloseQuote.limitOrStop[index] >0){  // stop limit
                require(bO.lastPrice >= _bCloseQuote.limitOrStop[index], "Close25" );
            }
            else {
                require( bO.lastPrice <= _bCloseQuote.price[index], "Close26");
            }
        } else if ( _bCloseQuote.initiator == bC.pB ){
            require( msg.sender == bC.pA, "Close27");
            if (_bCloseQuote.limitOrStop[index] >0){
                require(bO.lastPrice <= _bCloseQuote.limitOrStop[index], "Close28" );
            }
            else {
                require( bO.lastPrice >= _bCloseQuote.price[index], "Close29");
            }
        }
        require( amount <= bC.qty + pnr.getMinNotional(), "Close210");
        require( amount >= pnr.getMinNotional() / bC.qty / 1e18, "Close211");
        
    
        closePosition(bC, bO, _bCloseQuote.bContractIds[index], uPnl, isNegative, amount);
        _bCloseQuote.qty[index] -= amount;
        pnr.setBCloseQuote(bCloseQuoteId, _bCloseQuote);
        pnr.updateCumIm(bO, bC, _bCloseQuote.bContractIds[index]);

        //_bOracleemit acceptCloseQuoteEvent( msg.sender, bCloseQuoteId, index, amount );
    }
    
    function closeMarket(uint256 bCloseQuoteId, uint256 index) public {
        utils.bCloseQuote memory _bCloseQuote = pnr.getBCloseQuote(bCloseQuoteId);
        utils.bContract memory bC = pnr.getBContract(_bCloseQuote.bContractIds[index]);
        utils.bOracle memory bO = pnr.getBOracle(bC.oracleId);

        require(index < _bCloseQuote.bContractIds.length, "Close31");
        require( _bCloseQuote.qty[index] <= bC.qty + pnr.getMinNotional(), "Close32");
        require( _bCloseQuote.qty[index] * bO.lastPrice / 1e18 >= pnr.getMinNotional(), "Close33");
        require(bC.state == utils.cState.Open, "Close34");
        require(_bCloseQuote.expiry[index] >= block.timestamp, "Close34a");
        require( bO.lastPriceUpdateTime <= bO.maxDelay + block.timestamp, "Close34b" );
        require(block.timestamp - bC.openTime > bO.maxDelay, "Close35"); 
        require( _bCloseQuote.initiator == msg.sender, "Close36");
        require( _bCloseQuote.limitOrStop[index] == 0, "Close37");
        require(_bCloseQuote.openTime + pnr.getCancelTimeBuffer() <= block.timestamp, "Close38");
        (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, _bCloseQuote.price[index], bC.qty, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR );

        if (msg.sender == bC.pA){
            require( _bCloseQuote.price[index] >= bO.lastPrice, "Close310");
        }
        else{
            require(msg.sender == bC.pB, "Close311");
            require( _bCloseQuote.price[index] <= bO.lastPrice, "Close312");
        }
        closePosition(bC, bO, _bCloseQuote.bContractIds[index], uPnl, isNegative, _bCloseQuote.qty[index]);
        _bCloseQuote.qty[index] = 0;
        pnr.setBCloseQuote(bCloseQuoteId, _bCloseQuote);
        pnr.updateCumIm(bO, bC, _bCloseQuote.bContractIds[index]);
        //emit closeMarketEvent( msg.sender, bCloseQuoteId, index);
  }

    function expirateBContract( uint256 bContractId) public { 
        utils.bContract memory bC = pnr.getBContract(bContractId);
        utils.bOracle memory bO = pnr.getBOracle(bC.oracleId);

      require( bO.lastPriceUpdateTime <= bO.maxDelay + block.timestamp, "Close40" );
      require ( bC.state == utils.cState.Open, "Close41");
      (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, bO.lastPrice, bC.qty, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR );

      if (msg.sender == bC.pA){
          require( bC.openTime + bO.timeLockA <= block.timestamp, "Close42");
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.qty);
      }
      else{
          require(msg.sender == bC.pB, "Close43");
          require( bC.openTime + bO.timeLockB <= block.timestamp, "Close44");
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.qty);
      }
      pnr.updateCumIm(bO, bC, bContractId);
      //emit expirateBContractEvent(bContractId);
  }    

    // case where Oracle not update for 7 days
    // note : oracle doesnt update if price is same as before
  function expirateBContractOracleTimeout( uint256 bContractId) public { 
        utils.bContract memory bC = pnr.getBContract(bContractId);
        utils.bOracle memory bO = pnr.getBOracle(bC.oracleId);
      require( 7 days < block.timestamp - bO.lastPriceUpdateTime, "Close40" );
      require ( bC.state == utils.cState.Open, "Close41");
      (uint256 uPnl, bool isNegative) = utils.calculateuPnl( bC.price, bO.lastPrice, bC.qty, bC.interestRate, bO.lastPriceUpdateTime, bC.isAPayingAPR );
      if (msg.sender == bC.pA){
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.qty);
      }
      else{
          require( bC.openTime + bO.timeLockB > block.timestamp, "Close44");
          closePosition(bC, bO, bContractId, uPnl, isNegative, bC.qty);
      }
      pnr.updateCumIm(bO, bC, bContractId);
      //emit expirateBContractEvent(bContractId);
  }    

  function closePosition(utils.bContract memory bC, utils.bOracle memory bO, uint256 bContractId, uint256 toPay, bool isNegative, uint256 amount) internal{ 
      require(bO.maxDelay + block.timestamp >= bO.lastPriceUpdateTime, "Close51");
      console.log(toPay / 1e18);
      if ( amount > bC.qty){
          amount = bC.qty;
      }
      console.log(toPay / 1e18);
      if(isNegative){
        if( toPay >= utils.getNotional(bO, bC, true)){
            toPay = pnr.setBalancePrint( toPay - ( bO.imA + bO.dfA) * bC.price / 1e18 * amount / 1e18 , bC.pA, bC.pB, false, false) + ( bO.imA + bO.dfA) * bC.price / 1e18 * amount / 1e18 ;
            
        } else {
            pnr.setBalancePrint( ( bO.imA + bO.dfA) * bC.price / 1e18 * amount / 1e18 - toPay, bC.pA, address(0), true, false);
        }
          console.log(((bC.interestRate * (block.timestamp - bC.openTime) /1e18 * bC.price /1e18 * amount /1e18) / 31536000 /1e18) * pnr.getTotalShare() /1e18);
          pnr.payAffiliates(((bC.interestRate * (block.timestamp - bC.openTime) /1e18 * bC.price /1e18 * amount /1e18) / 31536000 ) * pnr.getTotalShare() /1e18, bC.frontEnd, bC.frontEnd, bC.hedger);
          pnr.setBalance( toPay + utils.getNotional(bO, bC, false), bC.pA, address(0), true, false);
      }
      else{
        if(toPay >= utils.getNotional(bO, bC, false) ){
            toPay = pnr.setBalancePrint( toPay - ( bO.imB + bO.dfB) * bC.price / 1e18 * amount / 1e18, bC.pB, bC.pA, false, false) + ( bO.imB + bO.dfB) * bC.price / 1e18 * amount / 1e18;
            
        } else {
            pnr.setBalance( ( bO.imB + bO.dfB) * bC.price / 1e18 * amount / 1e18 - toPay, bC.pB, bC.pA, true, false);
        }
            console.log(toPay/ 1e18);

          pnr.payAffiliates( utils.calculateIr( bC.interestRate, block.timestamp - bC.openTime, bO.lastPrice, bC.qty) * pnr.getTotalShare() /1e18, bC.frontEnd, bC.frontEnd, bC.hedger); 
          pnr.setBalance( toPay + ( bO.imA + bO.dfA) * bC.price / 1e18 * amount / 1e18, bC.pA, address(0), true, false);
          
      }
      bC.qty -= amount;
      if( bC.qty == 0){
          bC.state = utils.cState.Closed;
          pnr.decreaseOpenPositionNumber(msg.sender);
      }
      pnr.setBContract(bContractId, bC);
    }

    // delete and repush to modify a inner order
    function cancelCloseQuote(uint256 bCloseQuoteId) public {
        utils.bCloseQuote memory _bCloseQuote = pnr.getBCloseQuote(bCloseQuoteId);
        require(_bCloseQuote.state != utils.cState.Canceled, "Quote already canceled");
        _bCloseQuote.state = utils.cState.Canceled;
        _bCloseQuote.cancelTime = block.timestamp;
        pnr.setBCloseQuote(bCloseQuoteId, _bCloseQuote);
        //emit cancelOpenCloseQuoteContractIdEvent(contractId);
    }

}