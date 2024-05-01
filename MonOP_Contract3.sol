//This Solidity smart contract, named "MonopolyToken," is an advanced token implementation with additional features. It extends the ERC-20 standard and includes functionalities like burning, access control, pausing, and a time-lock mechanism. Users with the "LOCKER_ROLE" can lock and unlock token balances, introducing a time constraint on locked tokens. Additionally, the contract implements reentrancy protection during transfers and can be paused and unpaused by the contract admin.
//Version 3.2

/*
   (҂`_´)
*/

// MonOp_Token_Contract.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MonopolyToken is ERC20Burnable, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");

    mapping(address => uint256) private _lockedBalances;

    event TokensLocked(address indexed account, uint256 amount, uint256 unlockTimestamp);
    event TokensUnlocked(address indexed account, uint256 amount);

    modifier onlyLocker() {
        require(hasRole(LOCKER_ROLE, msg.sender), "Caller is not a locker");
        _;
    }

    modifier whenNotLocked(address account, uint256 amount) {
        require(_lockedBalances[account] <= block.timestamp, "Tokens are still locked");
        require(balanceOf(account).sub(_lockedBalances[account]) >= amount, "Insufficient unlocked balance");
        _;
    }

    constructor() ERC20("MonOP Token", "MNP") {
        _mint(msg.sender, 100000000 * 10**decimals());

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(LOCKER_ROLE, msg.sender);
    }

    function lockTokens(address account, uint256 amount, uint256 unlockTimestamp) external onlyLocker {
        _lockedBalances[account] = unlockTimestamp;
        _transfer(account, address(this), amount);
        emit TokensLocked(account, amount, unlockTimestamp);
    }

    function unlockTokens(address account) external onlyLocker {
        require(_lockedBalances[account] <= block.timestamp, "Tokens are still locked");
        uint256 lockedAmount = _lockedBalances[account];
        _lockedBalances[account] = 0;
        _transfer(address(this), account, lockedAmount);
        emit TokensUnlocked(account, lockedAmount);
    }

    function transfer(address recipient, uint256 amount) public override whenNotPaused whenNotLocked(msg.sender, amount) nonReentrant returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused whenNotLocked(sender, amount) nonReentrant returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
