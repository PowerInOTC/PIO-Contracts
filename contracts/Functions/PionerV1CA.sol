// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

import "./PionerV1Storage.sol";

import "hardhat/console.sol";

contract PionerV1CA is PionerV1Storage {


    /// @return uint256 paid ammount due to not enough balance
    function setBalance(uint256 amount, address target, address receiver, bool sign, bool revertMode) external onlyContracts returns(uint256) {
        if (sign){
            balances[target] += payOwed( amount, target);
            
            return(amount);
        } else {
            if ( amount >= balances[target]){
                if (revertMode){
                    revert("Not enough balance");
                }
                uint256 temp = balances[target];
                balances[target] = 0;
                return(temp);
            } else {
                balances[target] -= amount;
                return(amount);
            }
        }
    }

    // interests on unpaid owed.debt
    function manageOwedIr( address target) private {
        uint256 ir;
        if ( avgOpenOwedTime[msg.sender] != block.timestamp){
            ir = utils.calculateIr( 20e16, block.timestamp - avgOpenOwedTime[msg.sender] , 1e18 , totalOwedAmounts[target]);
            totalOwedAmounts[target] += ir;
            avgOpenOwedTime[msg.sender] = block.timestamp;
        }
    }

    // only use inside a function
    /// @param amount positive amount paid to 
    /// @return returnedAmount amount paid using input amount 
    function payOwed(uint256 amount, address target) internal returns(uint256 returnedAmount)  {
        manageOwedIr( msg.sender);
        if (totalOwedAmounts[target] >= amount) { 
            totalOwedAmountPaids[target] += amount;
            returnedAmount = 0;
        } else {
            totalOwedAmountPaids[target] += totalOwedAmounts[target];
            returnedAmount = amount - totalOwedAmounts[target];
        }
        emit PayOwedEvent(target, returnedAmount);
        return returnedAmount;
    }

    function addToOwed(uint256 deficit, address target, address receiver)  external onlyContracts { 
        owedAmounts[target][receiver] += deficit;
        totalOwedAmounts[target] += deficit;
        emit AddToOwedEvent(target, receiver, deficit);
    }

/*    function addToOwedTest(uint256 deficit, address target, address receiver)  public { 
        owedAmounts[target][receiver] += deficit;
        totalOwedAmounts[target] += deficit;
        emit AddToOwedEvent(target, receiver, deficit);
    }*/
    
    /// @dev Claim owed amount from amount prepaid by user or balance.
    /// @param target address of user owing money
    /// @param receiver address of user owed money from target
    function claimOwed(address target, address receiver) public {
        balances[target] += gracePeriodLockedWithdrawBalances[target];
        gracePeriodLockedWithdrawBalances[target] = 0;
        balances[target] = payOwed(balances[target], target);

        uint256 owedAmount = owedAmounts[target][receiver];

        if (totalOwedAmountPaids[target] >= owedAmount){ 
            totalOwedAmounts[target] -= owedAmount;
            totalOwedAmountPaids[target] -= owedAmount;
            balances[receiver] += payOwed(owedAmount, receiver);
            owedAmounts[target][receiver] = 0;
        } else { 
            totalOwedAmounts[target] -= totalOwedAmountPaids[target];
            owedAmounts[target][receiver] -= totalOwedAmountPaids[target];
            balances[receiver] += payOwed(totalOwedAmountPaids[target], receiver);
            totalOwedAmountPaids[target] = 0;
        }
        emit ClaimOwedEvent(target, receiver, owedAmount);
    }
    
    function payAffiliates(uint256 amount, address frontend, address affiliate, address hedger) public{
        balances[frontend] += amount * FRONTEND_SHARE;
        balances[affiliate] += amount * AFFILIATION_SHARE;
        balances[hedger] += amount * HEDGER_SHARE;
        balances[PIONER_DAO] += amount * PIONER_DAO_SHARE;
    }


    // update cum Im for stable default management
    function updateCumIm(utils.bOracle memory bO, utils.bContract memory bC, uint256 bContractId) external onlyContracts { 
        if( bC.state == 2 || bC.state == 1){
            if(bC.pA != address(0) ){
                cumImBalances[bC.pA] += utils.getIm(bO, true) * bC.price / 1e18 * bC.qty - bContractImBalances[bC.pA][bContractId] ;
            }
            if(bC.pB != address(0) ){
                cumImBalances[bC.pB] += utils.getIm(bO, true) * bC.price / 1e18 * bC.qty - bContractImBalances[bC.pB][bContractId] ;
            }
        } else if ( bC.state == 3 || bC.state == 4 || bC.state == 4){
            if(bC.pA != address(0) ){
                cumImBalances[bC.pA] -= bContractImBalances[bC.pA][bContractId] ;
            }
            if(bC.pB != address(0) ){
                cumImBalances[bC.pB] -= bContractImBalances[bC.pB][bContractId] ;
            }
        }
    }

    function updateMinimumOpenPartialFillNotional(uint256 newAmount) public {
        minimumOpenPartialFillNotional[msg.sender] = newAmount;
    }

    function updateSponsorReward(uint256 newAmount) public {
        sponsorReward[msg.sender] = newAmount;
    }

    function paySponsor(address receiver,address target, uint256 price, uint256 lastPrice, uint256 im, bool isA) external onlyContracts{
        if(receiver ==  target){
        }
        else if(isA && (lastPrice / price /1e18) <=  im * 8e17 / 1e18){
            if(balances[target] >= sponsorReward[target]){
                balances[receiver] += sponsorReward[target];
                balances[target] -= sponsorReward[target];
            }   
        } else if (!isA && (price / lastPrice /1e18) <=  im * 8e17 / 1e18){
            if(balances[target] >= sponsorReward[target]){
                balances[receiver] += sponsorReward[target];
                balances[target] -= sponsorReward[target];
            }   
        }
    }


}




