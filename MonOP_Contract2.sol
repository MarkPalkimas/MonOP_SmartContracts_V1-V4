//This Solidity smart contract, named "MonOP," represents a token with additional features. It extends the ERC-20 standard and includes a pausable mechanism. Each token transfer incurs a 1% fee, with the remaining amount transferred to the recipient. Additionally, users can initiate burning of their tokens, but the burning is time-locked for 30 days to prevent abuse.
//version 2.5

/*
   (҂`_´)
*/

// MonOp_Token_Contract.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MonOP is ERC20, Pausable {
    uint256 public constant BURN_DELAY = 30 days;
    uint256 public constant TRANSFER_FEE_PERCENT = 1; // 1% transfer fee

    mapping(address => uint256) private _burnTimelock;

    event TokensBurned(address indexed account, uint256 amount, uint256 unlockTimestamp);
    event TransferWithFee(address indexed from, address indexed to, uint256 amount, uint256 fee);

    constructor() ERC20("MonOP", "MOP") {
        _mint(msg.sender, 100000000 * 10**decimals());
    }

    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        uint256 fee = amount * TRANSFER_FEE_PERCENT / 100;
        _transfer(msg.sender, recipient, amount - fee);
        _burnTimelock[msg.sender] = block.timestamp + BURN_DELAY;
        emit TransferWithFee(msg.sender, recipient, amount - fee, fee);
        return true;
    }

    function burnTokens() external {
        require(_burnTimelock[msg.sender] <= block.timestamp, "Tokens are still timelocked");
        uint256 burnAmount = balanceOf(msg.sender);
        _burn(msg.sender, burnAmount);
        emit TokensBurned(msg.sender, burnAmount, _burnTimelock[msg.sender]);
    }
}
