// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract fakeUSD is ERC20 {
    using SafeERC20 for IERC20;

    address public owner;

    constructor() ERC20("Fake USD", "fUSD") {
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "Some error message related to permission");
        _mint(to, amount);
    }
}

