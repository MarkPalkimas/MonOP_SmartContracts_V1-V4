//This Solidity smart contract defines a token named "MonoOP" (symbol: MONO) that extends the ERC-20 standard. Upon deployment, it mints and assigns 50,000,000 tokens to the contract deployer's address.
//version 1.2

/*
   _/﹋\_
   (҂`_´)
   <,︻╦╤─ ҉ - -
   _/﹋\_
*/

// MonOp_Token_Contract.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MonoOpToken is ERC20 {
    constructor() ERC20("MonoOp", "MONO") {
        _mint(msg.sender, 50000000 * 10**decimals());
    }
}
