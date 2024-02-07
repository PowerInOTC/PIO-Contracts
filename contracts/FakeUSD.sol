// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract fakeUSD is ERC20 {
    using SafeERC20 for IERC20;

    constructor() ERC20("Fake USD", "fUSD") {}

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
