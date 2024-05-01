//The "MonOPToken" contract is a sophisticated Ethereum-based token with features ranging from standard ERC-20 operations and time-locking to advanced functionalities like staking with cooldown periods, governance mechanisms, gasless transactions through ERC-20 permit, and historical state tracking via snapshots. Its complexity is heightened by the inclusion of various access control roles, making it a versatile and comprehensive smart contract for diverse token-related operations on the Ethereum blockchain.
//version 4.0 (Beta)

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
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "ERC20Burnable"
;

contract MonOPToken is ERC20Burnable, AccessControl, Pausable, ReentrancyGuard, ERC20Snapshot, ERC20Permit {
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => uint256) private _lockedBalances;
    mapping(address => bool) private _hasVoted;
    mapping(address => uint256) private _stakedBalances;
    mapping(address => uint256) private _lastStakeTime;

    event TokensLocked(address indexed account, uint256 amount, uint256 unlockTimestamp);
    event TokensUnlocked(address indexed account, uint256 amount);
    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event ProposalCreated(uint256 proposalId, address indexed creator, string description);

    struct Proposal {
        uint256 id;
        address creator;
        string description;
        bool executed;
    }

    Proposal[] private _proposals;

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _;
    }

    modifier onlyLocker() {
        require(hasRole(LOCKER_ROLE, msg.sender), "Caller is not a locker");
        _;
    }

    modifier whenNotLocked(address account, uint256 amount) {
        require(_lockedBalances[account] <= block.timestamp, "Tokens are still locked");
        require(balanceOf(account).sub(_lockedBalances[account]) >= amount, "Insufficient unlocked balance");
        _;
    }

    modifier onlyGovernor() {
        require(hasRole(GOVERNOR_ROLE, msg.sender), "Caller is not a governor");
        _;
    }

    modifier whenStakeCooldownElapsed(address account) {
        require(block.timestamp >= _lastStakeTime[account] + 1 days, "Stake cooldown not elapsed");
        _;
    }

    constructor() ERC20("MonOPToken", "MNP") ERC20Permit("MonOPToken") {
        _mint(msg.sender, 100000000 * 10**decimals());

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(LOCKER_ROLE, msg.sender);
        _setupRole(GOVERNOR_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function transfer(address recipient, uint256 amount) public override whenNotPaused whenNotLocked(msg.sender, amount) nonReentrant returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused whenNotLocked(sender, amount) nonReentrant returns (bool) {
        return super.transferFrom(sender, recipient, amount);
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

    function stake(uint256 amount) external whenStakeCooldownElapsed(msg.sender) {
        _stakedBalances[msg.sender] += amount;
        _lastStakeTime[msg.sender] = block.timestamp;
        _transfer(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(_stakedBalances[msg.sender] >= amount, "Insufficient staked balance");
        _stakedBalances[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function getStakedBalance(address account) external view returns (uint256) {
        return _stakedBalances[account];
    }

    function createProposal(string memory description) external onlyGovernor {
        uint256 proposalId = _proposals.length;
        _proposals.push(Proposal(proposalId, msg.sender, description, false));
        emit ProposalCreated(proposalId, msg.sender, description);
    }

    function executeProposal(uint256 proposalId) external onlyGovernor {
        require(!_proposals[proposalId].executed, "Proposal already executed");
        _proposals[proposalId].executed = true;
        // Add your governance execution logic here
    }

    function vote() external {
        require(!_hasVoted[msg.sender], "Already voted");
        _hasVoted[msg.sender] = true;
        // Add your voting logic here
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function snapshot() external onlyGovernor {
        _snapshot();
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
