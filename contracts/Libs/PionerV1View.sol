// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
// LICENSE.txt at : https://www.pioner.io/license

import "../PionerV1.sol";

contract View {
    PionerV1 pnr;

    constructor(address _pionerV1Address) {
        pnr = PionerV1(_pionerV1Address);
    }

    function getOracle(uint256 oracleId) public view returns (
        uint256 lastPrice,
        uint256 lastPriceUpdateTime,
        uint256 maxDelay,
        address priceFeedAddress,
        bytes32 pythAddress1,
        bytes32 pythAddress2,
        utils.bOrType oracleType,
        uint256 imA,
        uint256 imB,
        uint256 dfA,
        uint256 dfB,
        uint256 expiryA,
        uint256 expiryB,
        uint256 timeLockA,
        uint256 timeLockB
    ) {
        utils.bOracle memory bO = pnr.getBOracle(oracleId);
        return (
            bO.lastPrice,
            bO.lastPriceUpdateTime,
            bO.maxDelay,
            bO.priceFeedAddress,
            bO.pythAddress1,
            bO.pythAddress2,
            bO.oracleType,
            bO.imA,
            bO.imB,
            bO.dfA,
            bO.dfB,
            bO.expiryA,
            bO.expiryB,
            bO.timeLockA,
            bO.timeLockB
        );
    }

    function getContract(uint256 contractId) public view returns (
        address pA,
        address pB,
        uint256 oracleId,
        address initiator,
        uint256 price,
        uint256 qty,
        uint256 interestRate,
        bool isAPayingAPR,
        uint256 openTime,
        utils.cState state,
        address frontEnd,
        address hedger,
        address affiliate,
        uint256 cancelTime
    ) {
        utils.bContract memory bC = pnr.getBContract(contractId);
        return (
            bC.pA,
            bC.pB,
            bC.oracleId,
            bC.initiator,
            bC.price,
            bC.qty,
            bC.interestRate,
            bC.isAPayingAPR,
            bC.openTime,
            bC.state,
            bC.frontEnd,
            bC.hedger,
            bC.affiliate,
            bC.cancelTime
        );
    }

    function getCloseQuote(uint256 closeQuoteId) public view returns (
        uint256[] memory bContractIds,
        uint256[] memory price,
        uint256[] memory qty,
        uint256[] memory limitOrStop,
        uint256[] memory expiry,
        address initiator,
        uint256 cancelTime,
        uint256 openTime,
        utils.cState state
    ) {
        utils.bCloseQuote memory closeQuote = pnr.getBCloseQuote(closeQuoteId);
        return (
            closeQuote.bContractIds,
            closeQuote.price,
            closeQuote.qty,
            closeQuote.limitOrStop,
            closeQuote.expiry,
            closeQuote.initiator,
            closeQuote.cancelTime,
            closeQuote.openTime,
            closeQuote.state
        );
    }

    function getUserRelatedInfo(address user, address counterparty) public view returns (
        uint256 openPositionNumber,
        uint256 owedAmount,
        uint256 totalOwedAmount,
        uint256 totalOwedAmountPaid,
        uint256 gracePeriodLockedWithdrawBalance,
        uint256 gracePeriodLockedTime,
        uint256 minimumOpenPartialFillNotional,
        uint256 sponsorReward,
        uint256 oracleLength,
        uint256 contractLength,
        uint256 closeQuoteLength
    ) {
        openPositionNumber = pnr.getOpenPositionNumber(user);
        owedAmount = pnr.getOwedAmount(user, counterparty);
        totalOwedAmount = pnr.getTotalOwedAmount(user);
        totalOwedAmountPaid = pnr.getTotalOwedAmountPaid(user);
        gracePeriodLockedWithdrawBalance = pnr.getGracePeriodLockedWithdrawBalance(user);
        gracePeriodLockedTime = pnr.getGracePeriodLockedTime(user);
        minimumOpenPartialFillNotional = pnr.getMinimumOpenPartialFillNotional(user);
        sponsorReward = pnr.getSponsorReward(user);
        oracleLength = pnr.getBOracleLength(); 
        contractLength = pnr.getBContractLength(); 
        closeQuoteLength = pnr.getBCloseQuoteLength(); 
        return (
            openPositionNumber,
            owedAmount,
            totalOwedAmount,
            totalOwedAmountPaid,
            gracePeriodLockedWithdrawBalance,
            gracePeriodLockedTime,
            minimumOpenPartialFillNotional,
            sponsorReward,
            oracleLength,
            contractLength,
            closeQuoteLength
        );
    }


}
