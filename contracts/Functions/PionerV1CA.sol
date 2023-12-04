// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
// LICENSE.txt at : https://www.pioner.io/license

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

import "./PionerV1Storage.sol";

import "hardhat/console.sol";

contract PionerV1CA is PionerV1Storage {


    // setBalance( ,bC.pA, bC.pB, true, true);
    function setBalance(uint256 amount, address target, address receiver, bool sign, bool revertMode) public onlyContracts {
        uint256 _balance1 = balances[target];
            uint256 _balance2 = balances[receiver];        
        if (sign){
            balances[target] += payOwed( amount, target);
            _balance1 = balances[target];
            _balance2 = balances[receiver];
            console.log("1 %s , %s, %s, %s", _balance1 / 1e18, _balance2 / 1e18, amount / 1e18);
        } else {
            if ( amount >= balances[target]){
                if (revertMode){
                    revert("Not enough balance");
                }
                owedAmounts[target][receiver] += amount - balances[target];
                totalOwedAmounts[target] += amount - balances[target];
                balances[target] = 0;
                _balance1 = balances[target];
            _balance2 = balances[receiver];
            console.log("2 %s , %s, %s, %s", _balance1 / 1e18, _balance2 / 1e18, amount / 1e18);
            } else {
                balances[target] -= amount;
                _balance1 = balances[target];
            _balance2 = balances[receiver];
            console.log("3 %s , %s, %s, %s", _balance1 / 1e18, _balance2 / 1e18, amount / 1e18);
            }
        }
    }

        // setBalance( ,bC.pA, bC.pB, true, true);
    function setBalancePrint(uint256 amount, address target, address receiver, bool sign, bool revertMode) external onlyContracts returns(uint256) {
        
        uint256 _balance1 = balances[target];
        uint256 _balance2 = balances[receiver];
        if (sign){
            balances[target] += payOwed( amount, target);
            _balance1 = balances[target];
            _balance2 = balances[receiver];
            console.log("1 %s , %s, %s, %s", _balance1 / 1e18, _balance2 / 1e18, amount / 1e18);
            return(amount);
        } else {
            if ( amount >= balances[target]){
                if (revertMode){
                    revert("Not enough balance");
                }
                addToOwed( amount - balances[target], target, receiver);
                uint256 tempBalance;
                balances[target] = 0;
                _balance1 = balances[target];
            _balance2 = balances[receiver];
            console.log("2 %s , %s, %s, %s", _balance1 / 1e18, _balance2 / 1e18, amount / 1e18);
                return(tempBalance);
            } else {
                balances[target] -= amount;
            _balance1 = balances[target];
            _balance2 = balances[receiver];
            console.log("3 %s , %s, %s, %s", _balance1 / 1e18, _balance2 / 1e18, amount / 1e18);
                return(amount);
            }
        }
    }

    function manageOwedIr( address target) private {
        uint256 ir;
        if ( avgOpenOwedTime[msg.sender] != block.timestamp){
            ir = utils.calculateIr( 20e16, block.timestamp - avgOpenOwedTime[msg.sender] , 1e18 , totalOwedAmounts[target]);
            totalOwedAmounts[target] += ir;
            avgOpenOwedTime[msg.sender] = block.timestamp;
        }
    }

    function payOwed(uint256 amount, address target) public returns(uint256 returnedAmount) {
        manageOwedIr( msg.sender);
        if (totalOwedAmounts[target] >= amount) { 
            totalOwedAmountPaids[target] += totalOwedAmounts[target] - amount;
            returnedAmount = 0;
        } else {
            totalOwedAmountPaids[target] += amount - totalOwedAmounts[target];
            returnedAmount = amount - totalOwedAmounts[target];
        }
        emit PayOwedEvent(target, returnedAmount);
        return returnedAmount;
    }

    function addToOwed(uint256 deficit, address target, address receiver) internal { 
        owedAmounts[target][receiver] += deficit;
        totalOwedAmounts[target] += deficit;
        emit AddToOwedEvent(target, receiver, deficit);
    }
    
    function claimOwed(address target, address receiver) public {
        balances[target] = gracePeriodLockedWithdrawBalances[target];
        gracePeriodLockedWithdrawBalances[target] = 0;
        uint256 owedAmount = owedAmounts[target][receiver];
        if(balances[target] >= 0){
            if( balances[target] >= owedAmount){
                balances[target] -= owedAmount;
                balances[receiver] += owedAmount;
                owedAmounts[target][receiver] = 0;
                totalOwedAmounts[target] -= owedAmount;
            } else {
                owedAmounts[target][receiver] -= balances[target];
                totalOwedAmounts[target] -= balances[target];
                owedAmount -= balances[target];
                balances[receiver] += balances[target];
                balances[target] -= 0;
            }
        }
        if (totalOwedAmountPaids[target] >= owedAmount){ 
            totalOwedAmounts[target] -= owedAmount;
            totalOwedAmountPaids[target] -= owedAmount;
            balances[receiver] += owedAmount;
            owedAmounts[target][receiver] = 0;
        } else { 
            totalOwedAmounts[target] -= totalOwedAmountPaids[target];
            owedAmounts[target][receiver] -= totalOwedAmountPaids[target];
            balances[receiver] += owedAmount;
            totalOwedAmountPaids[target] = 0;
        }
        
        emit ClaimOwedEvent(target, receiver, owedAmount);
    }
    
    function updatePriceDummy(uint256 bOracleId, uint256 price, uint256 time) public {
        utils.bOracle storage bO = bOracles[bOracleId];
        bO.lastPrice = price;
        bO.lastPriceUpdateTime = time;
 
    }

    function payAffiliates(uint256 amount, address frontend, address affiliate, address hedger) public{
        balances[frontend] += amount * FRONTEND_SHARE;
        balances[affiliate] += amount * AFFILIATION_SHARE;
        balances[hedger] += amount * HEDGER_SHARE;
        balances[PIONER_DAO] += amount * PIONER_DAO_SHARE;
    }

    function updatePricePyth( uint256 bOracleId, bytes[] memory _updateData1, bytes[] memory _updateData2) public { 
        int64 price;
        uint256 time;
        utils.bOracle storage bO = bOracles[bOracleId];
        IPyth pyth = IPyth(bO.priceFeedAddress);

        require(bO.oracleType == utils.bOrType.Pyth);

        uint feeAmount = pyth.getUpdateFee(_updateData1);
        require(msg.sender.balance >= feeAmount, "Insufficient balance");
        pyth.updatePriceFeeds{value: feeAmount}(_updateData1);
        PythStructs.Price memory pythPrice = pyth.getPrice(bO.pythAddress1);
        require(pythPrice.price > 0, "Pyth price is zero");

        price = (pythPrice.price);
        time = uint256(pythPrice.publishTime);      

        feeAmount = pyth.getUpdateFee(_updateData2);
        require(msg.sender.balance >= feeAmount, "Insufficient balance");
        pyth.updatePriceFeeds{value: feeAmount}(_updateData2);
        pythPrice = pyth.getPrice(bO.pythAddress2);
        require(pythPrice.price > 0, "Pyth price is zero");

        price = price / (pythPrice.price) / 1e6;

        if ( time < uint256(pythPrice.publishTime)){
            time = uint256(pythPrice.publishTime);
        }
        require(bO.maxDelay < time, " Oracle input expired ");
        require((bO.lastPrice != utils.int64ToUint256(price)), "if price is exact same do no update, market closed");
        bO.lastPrice = utils.int64ToUint256(price); 
        bO.lastPriceUpdateTime = time;
    }


    function updateCumIm(utils.bOracle memory bO, utils.bContract memory bC, uint256 bContractId) external onlyContracts {
        if( bC.state == utils.cState.Open || bC.state == utils.cState.Quote){
            if(bC.pA != address(0) ){
                cumImBalances[bC.pA] += utils.getIm(bO, true) * bC.price / 1e18 * bC.qty - bContractImBalances[bC.pA][bContractId] ;
            }
            if(bC.pB != address(0) ){
                cumImBalances[bC.pB] += utils.getIm(bO, true) * bC.price / 1e18 * bC.qty - bContractImBalances[bC.pB][bContractId] ;
            }
        } else if ( bC.state == utils.cState.Closed || bC.state == utils.cState.Liquidated || bC.state == utils.cState.Canceled){
            if(bC.pA != address(0) ){
                cumImBalances[bC.pA] -= bContractImBalances[bC.pA][bContractId] ;
            }
            if(bC.pB != address(0) ){
                cumImBalances[bC.pB] -= bContractImBalances[bC.pB][bContractId] ;
            }
        }
    }

    


}


