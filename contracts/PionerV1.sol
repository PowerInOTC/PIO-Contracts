// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import "./Functions/PionerV1CA.sol";

import { PionerV1Utils as utils } from "./Libs/PionerV1Utils.sol";

/**
 * @title PionerV1
 * @notice This contract is not audited
 * @author Microderiv
 */
contract PionerV1 is PionerV1CA{
    /** 
     * PionerV1CA is PionerV1Storage 
     * PionerV1Open, PionerV1Close, PionerV1Compliance, PionerV1Default and PionerV1Oracle are independant contract whiteslited on initilization.
     * 
    */
    constructor(
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
        address admin) {
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
    }

    bool private ISCONTRACTINIT;
    function setContactAddress(
        address _PIONERV1OPEN,
        address _PIONERV1CLOSE,
        address _PIONERV1DEFAULT,
        address _PIONERV1STABLE,
        address _PIONERV1COMPLIANCE,
        address _PIONERV1ORACLE ,
        address _PIONERV1WARPER  ) public {
        require(ISCONTRACTINIT == false);
        PIONERV1OPEN = _PIONERV1OPEN;
        PIONERV1CLOSE = _PIONERV1CLOSE;
        PIONERV1DEFAULT = _PIONERV1DEFAULT;
        PIONERV1STABLE = _PIONERV1STABLE;
        PIONERV1COMPLIANCE = _PIONERV1COMPLIANCE;
        PIONERV1ORACLE = _PIONERV1ORACLE;
        PIONERV1WARPER = _PIONERV1WARPER;
        ISCONTRACTINIT = true;
    }
}
