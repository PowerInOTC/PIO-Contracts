// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.20;

import "../Functions/PionerV1.sol";
import "../Functions/PionerV1Compliance.sol";
import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";

contract PionerV1View {
    PionerV1 private pio;
    PionerV1Compliance private kyc;

    constructor(address _pionerV1, address _pionerV1Compliance) {
        pio = PionerV1(_pionerV1);
        kyc = PionerV1Compliance(_pionerV1Compliance);
    }

    function getOracle(uint256 oracleId) public view returns (
        bytes32 assetHex,
        uint256 oracleType,
        uint256 lastBid,
        uint256 lastAsk,
        address publicOracleAddress,
        uint256 maxConfidence,
        uint256 x,
        uint8 parity,
        uint256 maxDelay,
        uint256 lastPrice,
        uint256 lastPriceUpdateTime,
        uint256 imA,
        uint256 imB,
        uint256 dfA,
        uint256 dfB,
        uint256 expiryA,
        uint256 expiryB,
        uint256 timeLock,
        uint256 cType,
        uint256 forceCloseType,
        address kycAddress,
        bool isPaused,
        uint256 deployTime
    ) {
        utils.bOracle memory oracle = pio.getBOracle(oracleId);
        return (
            oracle.assetHex,
            oracle.oracleType,
            oracle.lastBid,
            oracle.lastAsk,
            oracle.publicOracleAddress,
            oracle.maxConfidence,
            oracle.x,
            oracle.parity,
            oracle.maxDelay,
            oracle.lastPrice,
            oracle.lastPriceUpdateTime,
            oracle.imA,
            oracle.imB,
            oracle.dfA,
            oracle.dfB,
            oracle.expiryA,
            oracle.expiryB,
            oracle.timeLock,
            oracle.cType,
            oracle.forceCloseType,
            oracle.kycAddress,
            oracle.isPaused,
            oracle.deployTime
        );
    }


    function getContract(uint256 contractId) public view returns (
        address pA,
        address pB,
        uint256 oracleId,
        address initiator,
        uint256 price,
        uint256 amount,
        uint256 interestRate,
        bool isAPayingAPR,
        uint256 openTime,
        uint256 state,
        address frontEnd,
        address hedger,
        address affiliate,
        uint256 cancelTime
    ) {
        utils.bContract memory bC = pio.getBContract(contractId);
        return (
            bC.pA,
            bC.pB,
            bC.oracleId,
            bC.initiator,
            bC.price,
            bC.amount,
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
        openPositionNumber = pio.getOpenPositionNumber(user);
        owedAmount = pio.getOwedAmount(user, counterparty);
        totalOwedAmount = pio.getTotalOwedAmount(user);
        totalOwedAmountPaid = pio.getTotalOwedAmountPaid(user);
        gracePeriodLockedWithdrawBalance = pio.getGracePeriodLockedWithdrawBalance(user);
        gracePeriodLockedTime = pio.getGracePeriodLockedTime(user);
        minimumOpenPartialFillNotional = pio.getMinimumOpenPartialFillNotional(user);
        sponsorReward = pio.getSponsorReward(user);
        oracleLength = pio.getBOracleLength(); 
        contractLength = pio.getBContractLength(); 
        closeQuoteLength = pio.getBCloseQuoteLength(); 
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

    function getKycData(address user, address counterparty) public view returns (
        bool waitingKyc,
        address kycLinkedAddress,
        uint256 kycType,
        uint256 maxPosition,
        uint256 nextMaxPosition,
        uint256 lastKycUpdate,
        bool isKycPaused
    ) {
        waitingKyc = kyc.getKycWaitingAddress(user, counterparty);
        kycLinkedAddress = kyc.getKycAddress(user);
        kycType = kyc.getKycType(user);
        maxPosition = kyc.getMaxPositions(user);
        nextMaxPosition = kyc.getNextMaxPositions(user);
        lastKycUpdate = kyc.getLastKycParameterUpdateTime(user);
        isKycPaused = kyc.getKycPaused(user);

        return (
            waitingKyc,
            kycLinkedAddress,
            kycType,
            maxPosition,
            nextMaxPosition,
            lastKycUpdate,
            isKycPaused
        );
    }
}
