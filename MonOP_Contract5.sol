// MonOp_Token_Contract.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

// The "MonOPToken" contract is a sophisticated Ethereum-based token with features ranging from standard ERC-20 operations and time-locking to advanced functionalities like staking with cooldown periods, governance mechanisms, gasless transactions through ERC-20 permit, and historical state tracking via snapshots. Its complexity is heightened by the inclusion of various access control roles, making it a versatile and comprehensive smart contract for diverse token-related operations on the Ethereum blockchain.
// Version 5.0 (Beta)

/*
   (҂`_´)
*/

contract MonOPToken is ERC20Burnable, AccessControl, Pausable, ReentrancyGuard, ERC20Snapshot, ERC20Permit {
    // Roles used to manage permissions within the contract
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Token locking and staking mappings
    mapping(address => uint256) private _lockedBalances;
    mapping(address => uint256) private _lockTimestamps;
    mapping(address => bool) private _hasVoted;
    mapping(address => uint256) private _stakedBalances;
    mapping(address => uint256) private _lastStakeTime;

    // Reward configuration for staking
    uint256 public rewardRate = 10; // Reward rate as a percentage
    uint256 public stakingCooldown = 1 days;

    // Proposal management
    struct Proposal {
        uint256 id;
        address creator;
        string description;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
    }
    Proposal[] private _proposals;

    // Events for logging contract activities
    event TokensLocked(address indexed account, uint256 amount, uint256 unlockTimestamp);
    event TokensUnlocked(address indexed account, uint256 amount);
    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount, uint256 reward);
    event ProposalCreated(uint256 proposalId, address indexed creator, string description);
    event ProposalExecuted(uint256 proposalId, string result);

    // Modifiers to enforce access control and business logic
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _;
    }

    modifier onlyLocker() {
        require(hasRole(LOCKER_ROLE, msg.sender), "Caller is not a locker");
        _;
    }

    modifier whenNotLocked(address account, uint256 amount) {
        require(block.timestamp >= _lockTimestamps[account], "Tokens are still locked");
        require(balanceOf(account) >= amount, "Insufficient unlocked balance");
        _;
    }

    modifier onlyGovernor() {
        require(hasRole(GOVERNOR_ROLE, msg.sender), "Caller is not a governor");
        _;
    }

    modifier whenStakeCooldownElapsed(address account) {
        require(block.timestamp >= _lastStakeTime[account] + stakingCooldown, "Stake cooldown not elapsed");
        _;
    }

    // Constructor to initialize the token and default roles
    constructor() ERC20("MonOPToken", "MNP") ERC20Permit("MonOPToken") {
        // Minting an initial supply to the deployer's address
        _mint(msg.sender, 100000000 * 10**decimals());

        // Setting up default roles for the deployer
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(LOCKER_ROLE, msg.sender);
        _setupRole(GOVERNOR_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    // Transfer function overridden to enforce pause and locking logic
    function transfer(address recipient, uint256 amount) public override whenNotPaused whenNotLocked(msg.sender, amount) nonReentrant returns (bool) {
        return super.transfer(recipient, amount);
    }

    // TransferFrom function overridden to enforce pause and locking logic
    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused whenNotLocked(sender, amount) nonReentrant returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    // Lock tokens for a specified duration
    function lockTokens(address account, uint256 amount, uint256 unlockTimestamp) external onlyLocker {
        require(balanceOf(account) >= amount, "Insufficient balance to lock");
        _lockTimestamps[account] = unlockTimestamp;
        _transfer(account, address(this), amount);
        emit TokensLocked(account, amount, unlockTimestamp);
    }

    // Unlock tokens when their lock period has expired
    function unlockTokens(address account) external onlyLocker {
        require(block.timestamp >= _lockTimestamps[account], "Tokens are still locked");
        uint256 lockedAmount = balanceOf(address(this));
        _transfer(address(this), account, lockedAmount);
        _lockTimestamps[account] = 0;
        emit TokensUnlocked(account, lockedAmount);
    }

    // Stake tokens and update staking balance
    function stake(uint256 amount) external whenStakeCooldownElapsed(msg.sender) {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");
        _stakedBalances[msg.sender] += amount;
        _lastStakeTime[msg.sender] = block.timestamp;
        _transfer(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    // Unstake tokens and calculate rewards
    function unstake(uint256 amount) external {
        require(_stakedBalances[msg.sender] >= amount, "Insufficient staked balance");
        uint256 reward = (amount * rewardRate) / 100;
        _stakedBalances[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount + reward);
        emit Unstaked(msg.sender, amount, reward);
    }

    // Get the staked balance of an account
    function getStakedBalance(address account) external view returns (uint256) {
        return _stakedBalances[account];
    }

    // Create a proposal for governance
    function createProposal(string memory description) external onlyGovernor {
        uint256 proposalId = _proposals.length;
        _proposals.push(Proposal(proposalId, msg.sender, description, false, 0, 0));
        emit ProposalCreated(proposalId, msg.sender, description);
    }

    // Vote on a proposal
    function vote(uint256 proposalId, bool support) external {
        require(!_hasVoted[msg.sender], "Already voted");
        require(proposalId < _proposals.length, "Invalid proposal ID");

        _hasVoted[msg.sender] = true;
        uint256 voteWeight = balanceOf(msg.sender);

        if (support) {
            _proposals[proposalId].votesFor += voteWeight;
        } else {
            _proposals[proposalId].votesAgainst += voteWeight;
        }
    }

    // Execute a proposal after voting
    function executeProposal(uint256 proposalId) external onlyGovernor {
        require(!_proposals[proposalId].executed, "Proposal already executed");
        Proposal storage proposal = _proposals[proposalId];
        proposal.executed = true;

        if (proposal.votesFor > proposal.votesAgainst) {
            emit ProposalExecuted(proposalId, "Proposal Passed");
        } else {
            emit ProposalExecuted(proposalId, "Proposal Rejected");
        }
    }

    // Mint new tokens
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    // Take a snapshot of the current state
    function snapshot() external onlyGovernor {
        _snapshot();
    }

    // Pause all transfers
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    // Unpause all transfers
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
