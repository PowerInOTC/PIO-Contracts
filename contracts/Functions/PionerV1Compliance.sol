// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
// LICENSE.txt at : https://www.pioner.io/license

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../PionerV1.sol";
//import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";

contract PionerV1Compliance {
    using SafeERC20 for IERC20;

    PionerV1 private pnr;

    constructor(address _pionerV1) {
        pnr = PionerV1(_pionerV1);
    }

    // Compliance module
     mapping ( address => mapping (address => bool)) internal kycWaitingAddress;// user // kyc 
	 mapping ( address => address) internal kycAddress; //user
	 mapping ( address => utils.kycType) internal kycTypes; // user
     mapping ( address => uint256) internal maxPositions;// kyc 
     mapping ( address => uint256) internal nextMaxPositions;// kyc 
     mapping ( address => uint256 ) internal lastKycParameterUpdateTime;
     mapping ( address => bool) internal kycPaused; // kyc 

    event kycAddressSet(address indexed user, address kycAddress);
    event kycValidated(address indexed validator, address target);
    event BOracleRevoked(uint256 indexed bOracleId, bool isPaused);
    event kycRevoked(address indexed revoker, address target);
    
    event DepositEvent(address indexed user, uint256 amount);
    event InitiateWithdrawEvent(address indexed user, uint256 amount);
    event WithdrawEvent(address indexed user, uint256 amount);
    event CancelWithdrawEvent(address indexed user, uint256 amount);
    
    // Deposit function
    function deposit(uint256 _amount) public {
        console.log("deposit");
        require(kycAddress[msg.sender] != address(0), "CA11");
        require(_amount > 0, "CA12");
        IERC20 BALANCETOKEN = pnr.getBALANCETOKEN();
        require(BALANCETOKEN.balanceOf(msg.sender) >= _amount, "CA13");
        pnr.setBalance( _amount, msg.sender, address(0), true, false);
        BALANCETOKEN.safeTransferFrom(msg.sender, address(this), _amount); 
        emit DepositEvent(msg.sender, _amount);
    }

    // First Deposit
    function firstDeposit(uint256 _amount, utils.kycType _kyc, address _kycAddress ) public {
        require(pnr.getBalances(msg.sender) == 0, "CA21");
        require(kycAddress[msg.sender] == address(0), "CA22");
        require( _kyc != utils.kycType.unasigned, "CA23" );
        setKycAddress( msg.sender , _kycAddress, _kyc);
        if( _kyc == utils.kycType.oneWayOneSide || _kyc == utils.kycType.oneWayTwoSide || _kyc == utils.kycType.mint || _kyc == utils.kycType.fundOneWay || _kyc == utils.kycType.pirate ) {
            deposit(_amount);
        }
    }

    // Initiate Withdraw function
    function initiateWithdraw(uint256 _amount) public { 
        pnr.setGracePeriodLockedTime( msg.sender, block.timestamp); 
        pnr.addGracePeriodLockedWithdrawBalances(msg.sender, _amount);
        pnr.setBalance( _amount, msg.sender, address(0), false, true);
            //emit InitiateWithdrawEvent(msg.sender, _amount);
    }

    // Withdraw function
    function withdraw(uint256 _amount) public { 
        require(pnr.getGracePeriodLockedWithdrawBalance(msg.sender) >= _amount, "CA41");
        IERC20 BALANCETOKEN = pnr.getBALANCETOKEN();
        require(pnr.getGracePeriodLockedTime(msg.sender) + pnr.getGRACE_PERIOD() < block.timestamp, "CA42");
        pnr.removeGracePeriodLockedWithdrawBalances(msg.sender, _amount); 
        pnr.setGracePeriodLockedTime( msg.sender, block.timestamp); 
        BALANCETOKEN.safeTransfer(msg.sender, _amount);
        emit WithdrawEvent(msg.sender, _amount);
    }

    // Cancel Withdraw function
    function cancelWithdraw(uint256 _amount) public {
        require(pnr.getGracePeriodLockedWithdrawBalance(msg.sender) >= _amount, "CA51");
        pnr.removeGracePeriodLockedWithdrawBalances( msg.sender, _amount);
        pnr.setBalance( _amount, msg.sender, address(0), true, false);
        emit CancelWithdrawEvent(msg.sender, _amount);
    }
        
    // Function to setkyc address
    // Once Kyc set, cannot be changed for an address
    function setKycAddress(address target, address _kycAddress, utils.kycType _kyc) private {
        if (_kyc == utils.kycType.twoWayOneSide ||_kyc == utils.kycType.twoWayTwoSide) {
           kycWaitingAddress[target][_kycAddress] = true;
           kycTypes[target] = _kyc;
        } else if (_kyc == utils.kycType.oneWayOneSide || _kyc == utils.kycType.oneWayTwoSide || _kyc == utils.kycType.mint || _kyc == utils.kycType.fundOneWay || _kyc == utils.kycType.fundManager || _kyc == utils.kycType.pirate) {
           kycAddress[target] = _kycAddress;
           kycTypes[target] = _kyc;
        }
        emit kycValidated(target, _kycAddress);
    }

    // Function to validatekyc
    function validateKyc(address target) public {
        if (kycWaitingAddress[msg.sender][target]) {
           kycAddress[target] = msg.sender;
        }
        emit kycValidated(msg.sender, target);
    }


    // Function to revokekyc
    function revokeKyc(address target) public {
        if ((kycTypes[msg.sender] ==utils.kycType.oneWayTwoSide 
            || (kycTypes[msg.sender] ==utils.kycType.twoWayTwoSide) &&  kycAddress[target] == msg.sender)) {
           kycAddress[target] = address(0);
        }
            emit kycRevoked(msg.sender, target);
    }

    // Function to revoke BOracle
    // To update an oracle, create a new, and close this one.
    // Instant set to false after 1 week true is a feature.
    function manageBOracle(uint256 bOracleId, bool isPaused) public {
        utils.bOracle memory bO = pnr.getBOracle(bOracleId);
        require(msg.sender == bO.kycAddress, "Unauthorized");
        // 1 week notice to allow peoples exist positions. ( 5 buisness day following ISDA requirements )
        require( bO.deployTime + 1440 * 7 > block.timestamp );
        bO.isPaused = isPaused;
        bO.deployTime = block.timestamp;
        emit BOracleRevoked(bOracleId, isPaused);
    }

    function manageKycParameters(uint256 _maxPositions) public {
        if( block.timestamp - lastKycParameterUpdateTime[msg.sender] > 7 days){
            maxPositions[msg.sender] = nextMaxPositions[msg.sender];
        }
        nextMaxPositions[msg.sender] = _maxPositions;
        lastKycParameterUpdateTime[msg.sender] = block.timestamp;
    }

    //Allowkyc manager to pause openQuotes and acceptQuotes 
    function pauseKyc(bool newState) public {
        kycPaused[msg.sender] = newState;
    }


        //kyc Check function
    function kycCheck(address target , address openQuoteParty) external view returns (bool) {
        utils.kycType _kyc = kycTypes[target];
        address _kycAddress = kycAddress[target];
        require(maxPositions[_kycAddress] >= pnr.getOpenPositionNumber(target), "kyc11");
        require(!kycPaused[_kycAddress], "kyc12");
        if ( openQuoteParty == address(0)){
            if( _kyc != utils.kycType.fundManager) {
                return( true );
            } else {
                return( false );
            }
        } else {
            if (((_kyc == utils.kycType.oneWayTwoSide || _kyc == utils.kycType.twoWayTwoSide ||  _kyc == utils.kycType.twoWayTwoSide || _kyc == utils.kycType.fundTwoWay)
                && _kycAddress != kycAddress[openQuoteParty]) || _kyc == utils.kycType.fundManager) {
                return( false );
            } else {
                return( true );
            }
        }
    }

    function getMintValue( address target ) external view returns(uint256) {
        utils.bOracle memory bO = pnr.getBOracle(pnr.getBOracleIdStable(kycAddress[target]));
        require( bO.maxDelay + bO.lastPriceUpdateTime < block.timestamp );
        return( pnr.getMintedAmounts(target) * bO.lastPrice );
    }

    function getKycType(address user) external view returns (utils.kycType) {
        return kycTypes[user];
    }

    function getKycAddress(address user) external view returns (address) {
        return kycAddress[user];
    }


}