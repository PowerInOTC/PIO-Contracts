// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../PionerV1.sol";
//import { PionerV1Utils as utils } from "../Libs/PionerV1Utils.sol";


/**
 * @title PionerV1 Compliance
 * @dev This contract manage compliance functions, deposits and withdraws. Compliance is customisable to be trustless. Only deposit and open positions functions can be blocked by Compliance, withdraw and close functions cannot for safety reasons.
 * @notice This contract is not audited
 * @author  Microderiv
 */
contract PionerV1Compliance {
    using SafeERC20 for IERC20;

    PionerV1 private pio;

    constructor(address _pionerV1) {
        pio = PionerV1(_pionerV1);
    }

    // Compliance module
     mapping ( address => mapping (address => bool)) internal kycWaitingAddress;// user // kyc 
	 mapping ( address => address) internal kycAddress; //user
	 mapping ( address => uint256) internal kycTypes; // user
     mapping ( address => uint256) internal maxPositions;// kyc 
     mapping ( address => uint256) internal nextMaxPositions;// kyc 
     mapping ( address => uint256 ) internal lastKycParameterUpdateTime;
     mapping ( address => bool) internal kycPaused; // kyc 

    event kycAddressSet(address indexed user, address kycAddress);
    event kycValidated(address indexed validator, address target);
    event kycToValidat(address indexed validator, address target);
    event BOracleRevoked(uint256 indexed bOracleId, bool isPaused);
    event kycRevoked(address indexed revoker, address target);
    event kycPausedEvent(address target, bool state);
    event KycParametersChanged(address target, uint256 maxPositions);

    
    event DepositEvent(address indexed user, uint256 amount);
    event InitiateWithdrawEvent(address indexed user, uint256 amount);
    event WithdrawEvent(address indexed user, uint256 amount);
    event CancelWithdrawEvent(address indexed user, uint256 amount);
    
    // Deposit function
    function deposit(uint256 _amount) public {
        require(kycAddress[msg.sender] != address(0), "CA11");
            require(_amount > 0, "CA12");
            IERC20 BALANCETOKEN = pio.getBALANCETOKEN();
            require(BALANCETOKEN.balanceOf(msg.sender) >= _amount, "CA13");
            pio.setBalance( _amount, msg.sender, address(0), true, false);
            BALANCETOKEN.safeTransferFrom(msg.sender, address(this), _amount); 
            emit DepositEvent(msg.sender, _amount);
    }

    // First Deposit
    function deposit(uint256 _amount, uint256 _kyc, address _kycAddress ) public {
        if(kycAddress[msg.sender] == address(0) &&   _kyc != 0){
            setKycAddress( msg.sender , _kycAddress, _kyc);
        }
        
        if( _kyc == 2 || _kyc == 4 || _kyc == 6 || _kyc == 7 || _kyc == 1 ) {
            require(kycAddress[msg.sender] != address(0), "CA11");
            require(_amount > 0, "CA12");
            IERC20 BALANCETOKEN = pio.getBALANCETOKEN();
            require(BALANCETOKEN.balanceOf(msg.sender) >= _amount, "CA13");
            pio.setBalance( _amount, msg.sender, address(0), true, false);
            BALANCETOKEN.safeTransferFrom(msg.sender, address(this), _amount); 
            emit DepositEvent(msg.sender, _amount);
        }
    }

    // Initiate Withdraw function
    function initiateWithdraw(uint256 _amount) public { 
        require( pio.getBalance(msg.sender)  >= _getMintValue(msg.sender) + pio.getTotalOwedAmount(msg.sender));
        pio.setGracePeriodLockedTime( msg.sender, block.timestamp); 
        pio.addGracePeriodLockedWithdrawBalances(msg.sender, _amount);
        pio.setBalance( _amount, msg.sender, address(0), false, true);
        emit InitiateWithdrawEvent(msg.sender, _amount);
    }

    // Withdraw function
    function withdraw(uint256 _amount) public { 
        require( pio.getBalance(msg.sender)  >= _getMintValue(msg.sender) + pio.getTotalOwedAmount(msg.sender));
        require(pio.getGracePeriodLockedWithdrawBalance(msg.sender) >= _amount, "CA41");
        IERC20 BALANCETOKEN = pio.getBALANCETOKEN();
        require(pio.getGracePeriodLockedTime(msg.sender) + pio.getGRACE_PERIOD() < block.timestamp, "CA42");
        pio.removeGracePeriodLockedWithdrawBalances(msg.sender, _amount); 
        pio.setGracePeriodLockedTime( msg.sender, block.timestamp); 
        BALANCETOKEN.safeTransfer(msg.sender, _amount);
        emit WithdrawEvent(msg.sender, _amount);
    }

    // Cancel Withdraw function
    function cancelWithdraw(uint256 _amount) public {
        require(pio.getGracePeriodLockedWithdrawBalance(msg.sender) >= _amount, "CA51");
        pio.removeGracePeriodLockedWithdrawBalances( msg.sender, _amount);
        pio.setBalance( _amount, msg.sender, address(0), true, false);
        emit CancelWithdrawEvent(msg.sender, _amount);
    }
        
    // Function to setkyc address
    // Once Kyc set, cannot be changed for an address
    function setKycAddress(address target, address _kycAddress, uint256 _kyc) private {
        if (target == _kycAddress) { // becoming a kyc admin
           kycAddress[target] = _kycAddress;
           kycTypes[target] = _kyc;
           emit kycValidated(target, _kycAddress);
        } else if (_kyc == 3 ||_kyc == 5) {
           kycWaitingAddress[target][_kycAddress] = true;
           kycTypes[target] = _kyc;
           emit kycToValidat(target, _kycAddress);
        } else if (_kyc == 2 || _kyc == 4 || _kyc == 6 || _kyc == 7 || _kyc == 9 || _kyc == 1) {
           kycAddress[target] = _kycAddress;
           kycTypes[target] = _kyc;
           emit kycValidated(target, _kycAddress);
        }
        
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
        if ((kycTypes[msg.sender] ==4 
            || (kycTypes[msg.sender] ==5) &&  kycAddress[target] == msg.sender)) {
           kycAddress[target] = address(0);
        }
            emit kycRevoked(msg.sender, target);
    }

    // Function to revoke BOracle
    // To update an oracle, create a new, and close this one.
    // Instant set to false after 1 week true is a feature.
    function manageBOracle(uint256 bOracleId, bool isPaused) public {
        utils.bOracle memory bO = pio.getBOracle(bOracleId);
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
        emit KycParametersChanged(msg.sender, _maxPositions);
    }
    
    //Allowkyc manager to pause openQuotes and acceptQuotes 
    function pauseKyc(bool newState) public {
        kycPaused[msg.sender] = newState;
        emit kycPausedEvent(msg.sender, newState);
    }

        //kyc Check function
    function kycCheck(address target , address openQuoteParty) external view returns (bool) {
        uint256 _kyc = kycTypes[target];
        address _kycAddress = kycAddress[target];
        require(_kyc == 1 || maxPositions[_kycAddress] >= pio.getOpenPositionNumber(target), "kyc11");
        require(!kycPaused[_kycAddress], "kyc12");
        if ( openQuoteParty == address(0)){
            if( _kyc != 9) {
                return( true );
            } else {
                return( false );
            }
        } else {
            if (((_kyc == 4 || _kyc == 5 ||  _kyc == 5 || _kyc == 8)
                && _kycAddress != kycAddress[openQuoteParty]) || _kyc == 9) {
                return( false );
            } else {
                return( true );
            }
        }
    }

    function getMintValue( address target ) external view returns(uint256) {
        utils.bOracle memory bO = pio.getBOracle(pio.getBOracleIdStable(kycAddress[target]));
        require( bO.maxDelay + bO.lastPriceUpdateTime < block.timestamp );
        return( pio.getMintedAmounts(target) * bO.lastPrice );
    }

    function _getMintValue( address target ) public view returns(uint256) {
        utils.bOracle memory bO = pio.getBOracle(pio.getBOracleIdStable(kycAddress[target]));
        require( bO.maxDelay + bO.lastPriceUpdateTime < block.timestamp );
        return( pio.getMintedAmounts(target) * bO.lastPrice );
    }

    function getKycType(address user) external view returns (uint256) {
        return kycTypes[user];
    }

    function getKycAddress(address user) external view returns (address) {
        return kycAddress[user];
    }

    function getKycWaitingAddress(address user, address counterparty) public view returns (bool) {
        return kycWaitingAddress[user][counterparty];
    }

    function getMaxPositions(address user) public view returns (uint256) {
        return maxPositions[user];
    }

    function getNextMaxPositions(address user) public view returns (uint256) {
        return nextMaxPositions[user];
    }

    function getLastKycParameterUpdateTime(address user) public view returns (uint256) {
        return lastKycParameterUpdateTime[user];
    }

    function getKycPaused(address user) public view returns (bool) {
        return kycPaused[user];
    }

        /*
    /// @dev Semi-Permisionless Migration System
        1/ adming init migration
        2/ bContract can be replicated on new contract and close on old contracts after 15 days
        3/ balance transfered to new contract after 15 days
        case 1 : user accept migration
            - Migration is automatic
        case 2 : user refuse migration
            - User have 1 month to refuse migration
            - Counterparty of a user who refuse migration, should settle before migration
    */

    bool isMigration;
    address migrationContract;
    uint256 migrationTime;
    mapping(address => bool) public refuseMigrations;
    mapping(address => bool) public balanceMigrated;
    mapping(address => uint256) public collateralNotToMigrate;

    event MigrationInitiated(address migrationContract, uint256 migrationTime);
    event MigrationRefused(address user);
    event bContractMigrated(uint256 bContractId);

    function initMigration(address _migrationContract) public {
        require(msg.sender == pio.getPionerDao(), "Only Pioner DAO can init migration");
        isMigration = true;
        migrationContract = _migrationContract;
        migrationTime = block.timestamp + 15 days;
    }

    function refuseMigration() public {
        require(isMigration, "Migration is not active");
        refuseMigrations[msg.sender] = true;
    }

    function migrateBalance(address target) internal {
        require(isMigration, "Migration is not active");
        require(!refuseMigrations[target], "User refuse migration");
        require(!balanceMigrated[target], "Balance already migrated");
        require(pio.getBalance(target) > 0, "No balance to migrate");
        uint256 balanceToMigrate = 0;
        if(pio.getBalance(target) > collateralNotToMigrate[target]){
            balanceToMigrate = pio.getBalance(target) - collateralNotToMigrate[target];
            pio.setBalance( balanceToMigrate, target, address(0), false, true);
        }
        IERC20 BALANCETOKEN = pio.getBALANCETOKEN();
        BALANCETOKEN.safeTransfer(migrationContract, balanceToMigrate);
        balanceMigrated[target] = true;
    }

    function migratebContract(uint256[] memory bContractId) public {
        require(isMigration, "Migration is not active");
        for (  uint256 i = 0; i < bContractId.length; i++ ) {
            utils.bContract memory bC = pio.getBContract(bContractId[i]);
            if ( balanceMigrated[bC.pA] == false ) {
                migrateBalance(bC.pA);
            }
            if ( balanceMigrated[bC.pB] == false ) {
                migrateBalance(bC.pB);
            }
            require(bC.state == 2, "bContract is not open");
            require(bC.openTime <= block.timestamp, "bContract is not old enough");
            require(!refuseMigrations[bC.pA] && !refuseMigrations[bC.pB], "One of the counterparty refuse migration");
            bC.state = 4;
            pio.setBContract(bContractId[i], bC);
            emit bContractMigrated(bContractId[i]);
        }
    }

}