// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

import "hardhat/console.sol";

import "../Libs/MuonClientBase.sol";
import "../Libs/SchnorrSECP256K1Verifier.sol";
import "../interfaces/IMuonNodeManager.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";



contract PionerV1 is MuonClientBase  {

    using SafeERC20 for IERC20;

    uint256 internal MIN_NOTIONAL;
    uint256 internal FRONTEND_SHARE; 
    uint256 internal AFFILIATION_SHARE;
    uint256 internal HEDGER_SHARE;
    uint256 internal PIONER_DAO_SHARE;
    uint256 internal TOTAL_SHARE;
    uint256 internal DEFAULT_AUCTION_PERIOD;
    uint256 internal CANCEL_TIME_BUFFER;
    uint256 internal MAX_OPEN_POSITIONS; 
    uint256 internal GRACE_PERIOD;
    address internal PIONER_DAO;
    address internal ADMIN;
    IERC20 internal BALANCETOKEN;
    
    address internal PIONERV1OPEN;
    address internal PIONERV1CLOSE;
    address internal PIONERV1DEFAULT;
    address internal PIONERV1STABLE;
    address internal PIONERV1COMPLIANCE;
    address internal PIONERV1CCP;
    address internal PIONERV1FLATCOIN;
    address internal PIONERV1MANAGEMENT;
    address internal PIONERV1ORACLE;
    address internal PIONERV1WRAPPER;
    
    modifier onlyContracts() {
        require(
            msg.sender == address(this) || 
            msg.sender == PIONERV1OPEN || 
            msg.sender == PIONERV1CLOSE || 
            msg.sender == PIONERV1DEFAULT || 
            msg.sender == PIONERV1STABLE ||
            //msg.sender == PIONERV1CCP ||
            //msg.sender == PIONERV1FLATCOIN ||
            //msg.sender == PIONERV1MANAGEMENT ||
            msg.sender == PIONERV1COMPLIANCE ||
            msg.sender == PIONERV1ORACLE ||
            msg.sender == PIONERV1WRAPPER ,
            "Caller not authorized"
        );
        _;
    }

    function getPIONERV1WRAPPERADDRESS() external view returns (address) {
        return PIONERV1WRAPPER;
    }

    mapping( address => uint256) internal balances; 
    uint256 internal bOracleLength;
    mapping( uint256 => utils.bOracle) internal bOracles;
    uint256 internal bContractLength;
    mapping( uint256 => utils.bContract) internal bContracts;
    mapping( uint256 => utils.bContractUpdate) internal bContractUpdates;
    mapping( uint256 => mapping( address => utils.bContractTransferQuote)) bContractTransferQuotes;
    uint256 internal bCloseQuotesLength;
    mapping(uint256 => utils.bCloseQuote) internal bCloseQuotes;
    mapping(address => uint256) internal openPositionNumbers;
    mapping(address => mapping( address => uint256 )) internal owedAmounts;
    mapping(address => uint256 ) internal totalOwedAmounts;
    mapping(address => uint256 ) internal totalOwedAmountPaids;
    mapping(address => uint256 ) internal avgOpenOwedTime;
    mapping(address => uint256 ) internal claimedKycIrAmounts; // kyc // to be used in ccp
    mapping(address => uint256 ) internal gracePeriodLockedWithdrawBalances;
    mapping(address => uint256 ) internal gracePeriodLockedTime;
    mapping(address => uint256 ) internal minimumOpenPartialFillNotional;
    mapping(address => uint256 ) internal sponsorReward;
    

    event PayOwedEvent(address indexed target, uint256 returnedAmount);
    event AddToOwedEvent(address indexed target, address indexed receiver, uint256 deficit);
    event ClaimOwedEvent(address indexed target, address indexed receiver, uint256 amount);
    event deployPriceFeedEvent(uint256 indexed bOracleLength);
    event updatePricePythEvent(uint256 indexed bOracleId, uint256 lastPrice);


// Stablecoin Module
    mapping(address => uint256) bOracleIdStable; // kyc
    mapping( address => address) accountToToken; //kyc
    mapping(address => uint256) internal mintedAmounts; // user
    mapping ( address => uint256 ) internal cumImBalances; // user
    mapping( address => mapping( uint256 => uint256)) bContractImBalances;

// Read only functions

    

    function getBContract(uint256 id) external view returns (utils.bContract memory) {
             return bContracts[id];
        }

    function getBContractTransferQuote(uint256 id, address target) external view returns (utils.bContractTransferQuote memory) {
             return bContractTransferQuotes[id][target];
        }

    function getBContractUpdate(uint256 id) external view returns (utils.bContractUpdate memory) {
             return bContractUpdates[id];
        }

    function getBOracle(uint256 id) external view returns (utils.bOracle memory) {
             return bOracles[id];
        }

    function getBCloseQuote(uint256 id) external view returns (utils.bCloseQuote  memory) {
            return bCloseQuotes[id];
        }

    function getMinNotional() external view returns (uint256) {
        return MIN_NOTIONAL;
    }

    function getBALANCETOKEN() external view returns (IERC20) {
        return BALANCETOKEN;
    }

    function getGRACE_PERIOD() external view returns (uint256) {
        return GRACE_PERIOD;
    }


    function getTotalShare() external view returns (uint256) {
        return TOTAL_SHARE;
    }

    function getDefaultAuctionPeriod() external view returns (uint256) {
        return DEFAULT_AUCTION_PERIOD;
    }

    function getCancelTimeBuffer() external view returns (uint256) {
        return CANCEL_TIME_BUFFER;
    }

    function getMaxOpenPositions() external view returns (uint256) {
        return MAX_OPEN_POSITIONS;
    }

    // Getters for address internal variables
    function getPionerDao() external view returns (address) {
        return PIONER_DAO;
    }

    // Getter for IERC20 internal variable
    function getBalanceToken() external view returns (IERC20) {
        return BALANCETOKEN;
    }

    function getBOracleLength() public view returns (uint256 oracleLength) {
        oracleLength = bOracleLength;
    }

    function addBOracleLength() external onlyContracts{
        bOracleLength++ ;
    }

    function getBContractLength() public view returns (uint256 contractLength) {
        contractLength = bContractLength;
    }

    function addBContractLength() external onlyContracts{
        bContractLength++ ;
    }

    function getBCloseQuoteLength() public view returns (uint256 closeQuoteLength) {
        closeQuoteLength = bCloseQuotesLength;
    }

    function addBCloseQuoteLength() external onlyContracts{
        bCloseQuotesLength++ ;
    }

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function getOpenPositionNumber(address user) external view returns (uint256) {
        return openPositionNumbers[user];
    }

    function getOwedAmount(address user, address counterparty) external view returns (uint256) {
        return owedAmounts[user][counterparty];
    }

    function getTotalOwedAmount(address user) external view returns (uint256) {
        return totalOwedAmounts[user];
    }

    function getTotalOwedAmountPaid(address user) external view returns (uint256) {
        return totalOwedAmountPaids[user];
    }

    function getAvgOpenOwedTime(address user) external view returns (uint256) {
        return avgOpenOwedTime[user];
    }

    function getClaimedKycIrAmount(address user) external view returns (uint256) {
        return claimedKycIrAmounts[user];
    }

    function getGracePeriodLockedWithdrawBalance(address user) external view returns (uint256) {
        return gracePeriodLockedWithdrawBalances[user];
    }

    function getGracePeriodLockedTime(address user) external view returns (uint256) {
        return gracePeriodLockedTime[user];
    }

    function setGracePeriodLockedTime(address id, uint256 value) external onlyContracts {
        gracePeriodLockedTime[id] = value;
    }

    function getMinimumOpenPartialFillNotional(address user) external view returns (uint256) {
        return minimumOpenPartialFillNotional[user];
    }

    function getCumImBalances(address user) external view returns (uint256) {
        return cumImBalances[user];
    }

    function getBalances(address user) external view returns (uint256) {
        return balances[user];
    }

    function getAccountToToken(address user) external view returns (address) {
        return accountToToken[user];
    }

    function getBOracleIdStable(address user) external view returns (uint256) {
        return bOracleIdStable[user];
    }

    function setAccountToToken(address user, address _token) external onlyContracts {
        accountToToken[user] = _token;
    }

    function setCumImBalances(address user, uint256 amount) external onlyContracts {
        cumImBalances[user] = amount;
    }

    function addCumImBalances(address user, uint256 amount) external onlyContracts {
        cumImBalances[user] += amount;
    }

    function removeCumImBalances(address user, uint256 amount) external onlyContracts {
        cumImBalances[user] -= amount;
    }

    function getMintedAmounts(address user) external view returns (uint256) {
        return mintedAmounts[user];
    }

    function addMintedAmounts(address user, uint256 amount) external onlyContracts {
        mintedAmounts[user] += amount;
    }

    function removeMintedAmounts(address user, uint256 amount) external onlyContracts {
        mintedAmounts[user] -= amount;
    }


// set functions

    function setBContract(uint256 id, utils.bContract memory newContract) external onlyContracts {
        bContracts[id] = newContract;
    }

    function setBContractUpdate(uint256 id, utils.bContractUpdate memory newContractUpdate) external onlyContracts {
        bContractUpdates[id] = newContractUpdate;
    }

    function setBContractTransferQuote(uint256 id, address target, utils.bContractTransferQuote memory newBContractTransferQuote) external onlyContracts {
        bContractTransferQuotes[id][target] = newBContractTransferQuote;
    }

    function setBOracle(uint256 id, utils.bOracle memory newOracle) external onlyContracts {
        bOracles[id] = newOracle;
    }

    function setBCloseQuote(uint256 id, utils.bCloseQuote  memory newCloseQuote) external onlyContracts {
        bCloseQuotes[id] = newCloseQuote;
    }

    function addBalance(address user, uint256 amount) external onlyContracts {
        balances[user] += amount;
    }

    function removeBalance(address user, uint256 amount) external onlyContracts {
        balances[user] -= amount;
    }

    function addOpenPositionNumber(address user) external    {
        openPositionNumbers[user]++;
    }

    function decreaseOpenPositionNumber(address user) external onlyContracts {
        openPositionNumbers[user]--;
    }

    function setOwedAmount(address user, address counterparty, uint256 amount) external onlyContracts {
        owedAmounts[user][counterparty] = amount;
    }

    function decreaseOwedAmount(address user, address counterparty, uint256 amount) external onlyContracts {
        owedAmounts[user][counterparty] -= amount;
    }

    function addOwedAmount(address user, address counterparty, uint256 amount) external onlyContracts {
        owedAmounts[user][counterparty] += amount;
    }

    function removeOwedAmount(address user, address counterparty, uint256 amount) external onlyContracts {
        owedAmounts[user][counterparty] -= amount;
    }

    function setTotalOwedAmountPaid(address user, uint256 amount) external onlyContracts {
        totalOwedAmounts[user] = amount;
    }

    function decreaseTotalOwedAmountPaid(address user, uint256 amount) external onlyContracts {
        totalOwedAmountPaids[user] -= amount;
    }

    function setTotalOwedAmount(address user, uint256 amount) external onlyContracts {
        totalOwedAmountPaids[user] = amount;
    }

        function decreaseTotalOwedAmount(address user, uint256 amount) external onlyContracts {
            totalOwedAmounts[user] -= amount;
        }

    function setbOracleIdStable(address kyc, uint256 _id) external onlyContracts {
        require( bOracleIdStable[kyc] == 0);
        bOracleIdStable[kyc] = _id;
    }

    function addGracePeriodLockedWithdrawBalances(address user, uint256 amount) external onlyContracts {
        gracePeriodLockedWithdrawBalances[user] += amount;
    }

    function removeGracePeriodLockedWithdrawBalances(address user, uint256 amount) external onlyContracts {
        gracePeriodLockedWithdrawBalances[user] -= amount;
    }

    mapping(bytes => mapping( address => uint256)) public cancelledOpenQuotes;
    mapping(bytes => mapping( address => uint256)) public cancelledCloseQuotes;

    function getCancelledOpenQuotes(bytes calldata id, address target ) external view returns(uint256){
        return( cancelledOpenQuotes[id][target]);
    }

    function setCancelledOpenQuotes(bytes calldata id, address target , uint256 value ) external onlyContracts {
        cancelledOpenQuotes[id][target] = value;
    }


    function getCancelledCloseQuotes(bytes calldata id, address target  ) external view returns(uint256){
        return( cancelledCloseQuotes[id][target]);
    }

    function setCancelledCloseQuotes(bytes calldata id, address target , uint256 value ) external onlyContracts {
        cancelledCloseQuotes[id][target] = value;
    }


    function getAllStateVariables() public view returns (
        uint256 minNotional,
        uint256 frontendShare,
        uint256 affiliationShare,
        uint256 hedgerShare,
        uint256 pionerDaoShare,
        uint256 totalShare,
        uint256 defaultAuctionPeriod,
        uint256 cancelTimeBuffer,
        uint256 maxOpenPositions,
        uint256 gracePeriod,
        address pionerDao,
        address admin
            ) {
        minNotional = MIN_NOTIONAL;
        frontendShare = FRONTEND_SHARE;
        affiliationShare = AFFILIATION_SHARE;
        hedgerShare = HEDGER_SHARE;
        pionerDaoShare = PIONER_DAO_SHARE;
        totalShare = TOTAL_SHARE;
        defaultAuctionPeriod = DEFAULT_AUCTION_PERIOD;
        cancelTimeBuffer = CANCEL_TIME_BUFFER;
        maxOpenPositions = MAX_OPEN_POSITIONS;
        gracePeriod = GRACE_PERIOD;
        pionerDao = PIONER_DAO;
        admin = ADMIN;
    }

        // Affiliation, Fee Sharing
    mapping(address => uint256) internal feeShare;
    mapping(address => uint256) internal newFeeShare;
    mapping(address => uint256) internal initNewFeeShareTime;

    /// dev Set fee share for target address, for case of multiple fee share use multiple addresses.
    function setFeeShare( address target, uint256 newShare) external onlyContracts {
        if (feeShare[target] != newShare){
            newFeeShare[target] = newShare;
            initNewFeeShareTime[target] = block.timestamp;
        } else if (initNewFeeShareTime[target] + 1 days < block.timestamp){
            feeShare[target] = newFeeShare[target];
            initNewFeeShareTime[target] = 0;
        }
    }

    function getFeeShare(address target) external view returns(uint256) {
        return feeShare[target];
    }


    /// @return uint256 paid ammount due to not enough balance
    function setBalance(uint256 amount, address target, address receiver, bool sign, bool revertMode) external onlyContracts returns(uint256) {
        if (sign){
            balances[target] += payOwed( amount, target);
            return(amount);
        } else {
            if ( amount >= balances[target]){
                balances[target] += gracePeriodLockedWithdrawBalances[target];
                gracePeriodLockedWithdrawBalances[target] = 0;
                gracePeriodLockedTime[target] = block.timestamp;
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
        gracePeriodLockedTime[target] = block.timestamp;
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
    

    function payTradingFeeShare(uint256 amount, address frontend, address affiliate) public{
        balances[frontend] += amount * FRONTEND_SHARE;
        balances[affiliate] += amount * AFFILIATION_SHARE;
    }

    function payFundingShare(uint256 amount) public{
        balances[PIONER_DAO] += amount;
    }

    function payLiquidationShare(uint256 amount, address winner) public{
        balances[PIONER_DAO] += amount * HEDGER_SHARE / 1e18;
        balances[winner] += amount * (1e18 - HEDGER_SHARE) / 1e18;
    }

    // update cum Im for stable default management
    function updateCumIm(utils.bOracle memory bO, utils.bContract memory bC, uint256 bContractId) external onlyContracts { 
        if( bC.state == 2 || bC.state == 1){
            if(bC.pA != address(0) ){
                cumImBalances[bC.pA] += utils.getIm(bO, true) * bC.price / 1e18 * bC.amount - bContractImBalances[bC.pA][bContractId] ;
            }
            if(bC.pB != address(0) ){
                cumImBalances[bC.pB] += utils.getIm(bO, true) * bC.price / 1e18 * bC.amount - bContractImBalances[bC.pB][bContractId] ;
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


    function getSponsorReward(address user) external view returns (uint256) {
        return sponsorReward[user];
    }

    /**
     * @notice only pay sponsor if imA > or < 80% compared to upnl
     * @return amount unpaid
     */
    function paySponsor(address receiver, address target, uint256 price, uint256 lastPrice, uint256 im) external onlyContracts returns(uint256) {
        uint256 sponsorReward = sponsorReward[receiver];
        if(receiver ==  target){
        } else if(lastPrice > price && (lastPrice / price /1e18) <=  im * 8e17 / 1e18){
            if (balances[receiver] <= sponsorReward){
                return balances[receiver];
            } else {
                balances[receiver] += sponsorReward;
                balances[target] -= sponsorReward;
                return 0;
            }
        } else if (price > lastPrice && (price / lastPrice /1e18) <=  im * 8e17 / 1e18){
            if (balances[receiver] <= sponsorReward){
                return balances[receiver];
            } else {
                balances[receiver] += sponsorReward;
                balances[target] -= sponsorReward;
                return 0;
            }
        }
        return 0;
    }

    //Deploy
    bool internal ISCONTRACTINIT;

    function setContactAddress(        
        address daiAddress, 
        uint256 min_notional,
        uint256 frontend_share,
        uint256 affiliation_share,
        uint256 hedger_share,
        uint256 pioner_dao_share,
        uint256 total_share,
        uint256 default_auction_period,
        uint256 cancel_time_buffer,
        uint256 max_open_positions,
        uint256 grace_period, 
        address pioner_dao,
        address admin,
        address _PIONERV1OPEN,
        address _PIONERV1CLOSE,
        address _PIONERV1DEFAULT,
        address _PIONERV1COMPLIANCE,
        address _PIONERV1ORACLE ,
        address _PIONERV1WRAPPER  ) public {
        require(ISCONTRACTINIT == false);
        BALANCETOKEN = IERC20(daiAddress);
        MIN_NOTIONAL = min_notional;
        FRONTEND_SHARE = frontend_share;
        AFFILIATION_SHARE = affiliation_share;
        HEDGER_SHARE = hedger_share;
        PIONER_DAO_SHARE = pioner_dao_share;
        TOTAL_SHARE = total_share;
        DEFAULT_AUCTION_PERIOD = default_auction_period;
        CANCEL_TIME_BUFFER = cancel_time_buffer;
        MAX_OPEN_POSITIONS = max_open_positions;
        GRACE_PERIOD = grace_period;
        PIONER_DAO = pioner_dao;
        ADMIN = admin;
        PIONERV1OPEN = _PIONERV1OPEN;
        PIONERV1CLOSE = _PIONERV1CLOSE;
        PIONERV1DEFAULT = _PIONERV1DEFAULT;
        PIONERV1COMPLIANCE = _PIONERV1COMPLIANCE;
        PIONERV1ORACLE = _PIONERV1ORACLE;
        PIONERV1WRAPPER = _PIONERV1WRAPPER;
        ISCONTRACTINIT = true;
    }

}






