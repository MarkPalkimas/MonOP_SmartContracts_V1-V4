// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

// (҂`_´)

contract MonOPToken is ERC20Burnable, AccessControl, Pausable, ReentrancyGuard, ERC20Snapshot, ERC20Permit {
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => uint256) private _lockedBalances;
    mapping(address => uint256) private _lockTimestamps;
    mapping(address => bool) private _hasVoted;
    mapping(address => uint256) private _stakedBalances;
    mapping(address => uint256) private _lastStakeTime;

    uint256 public rewardRate = 10; // Reward rate as a percentage
    uint256 public stakingCooldown = 1 days;
    uint256 public proposalCooldown = 3 days;

    struct Proposal {
        uint256 id;
        address creator;
        string description;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votingDeadline;
        uint256 quorum;
    }
    Proposal[] private _proposals;

    event TokensLocked(address indexed account, uint256 amount, uint256 unlockTimestamp);
    event TokensUnlocked(address indexed account, uint256 amount);
    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount, uint256 reward);
    event ProposalCreated(uint256 proposalId, address indexed creator, string description, uint256 votingDeadline);
    event ProposalExecuted(uint256 proposalId, string result);
    event QuorumNotMet(uint256 proposalId, string result);

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
        require(balanceOf(account) >= amount, "Insufficient balance to lock");
        _lockTimestamps[account] = unlockTimestamp;
        _transfer(account, address(this), amount);
        emit TokensLocked(account, amount, unlockTimestamp);
    }

    function unlockTokens(address account) external onlyLocker {
        require(block.timestamp >= _lockTimestamps[account], "Tokens are still locked");
        uint256 lockedAmount = balanceOf(address(this));
        _transfer(address(this), account, lockedAmount);
        _lockTimestamps[account] = 0;
        emit TokensUnlocked(account, lockedAmount);
    }

    function stake(uint256 amount) external whenStakeCooldownElapsed(msg.sender) {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");
        _stakedBalances[msg.sender] += amount;
        _lastStakeTime[msg.sender] = block.timestamp;
        _transfer(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(_stakedBalances[msg.sender] >= amount, "Insufficient staked balance");
        uint256 reward = (amount * rewardRate) / 100;
        _stakedBalances[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount + reward);
        emit Unstaked(msg.sender, amount, reward);
    }

    function getStakedBalance(address account) external view returns (uint256) {
        return _stakedBalances[account];
    }

    function createProposal(string memory description, uint256 votingDuration, uint256 quorum) external onlyGovernor {
        require(block.timestamp >= _lastStakeTime[msg.sender] + proposalCooldown, "Proposal cooldown not elapsed");
        uint256 proposalId = _proposals.length;
        uint256 votingDeadline = block.timestamp + votingDuration;
        _proposals.push(Proposal(proposalId, msg.sender, description, false, 0, 0, votingDeadline, quorum));
        emit ProposalCreated(proposalId, msg.sender, description, votingDeadline);
    }

    function vote(uint256 proposalId, bool support) external {
        require(!_hasVoted[msg.sender], "Already voted");
        require(proposalId < _proposals.length, "Invalid proposal ID");
        require(block.timestamp <= _proposals[proposalId].votingDeadline, "Voting period has ended");

        _hasVoted[msg.sender] = true;
        uint256 voteWeight = balanceOf(msg.sender);

        if (support) {
            _proposals[proposalId].votesFor += voteWeight;
        } else {
            _proposals[proposalId].votesAgainst += voteWeight;
        }
    }

    function executeProposal(uint256 proposalId) external onlyGovernor {
        require(!_proposals[proposalId].executed, "Proposal already executed");
        require(block.timestamp > _proposals[proposalId].votingDeadline, "Voting period has not ended");

        Proposal storage proposal = _proposals[proposalId];
        proposal.executed = true;

        if (proposal.votesFor + proposal.votesAgainst >= proposal.quorum) {
            if (proposal.votesFor > proposal.votesAgainst) {
                emit ProposalExecuted(proposalId, "Proposal Passed");
            } else {
                emit ProposalExecuted(proposalId, "Proposal Rejected");
            }
        } else {
            emit QuorumNotMet(proposalId, "Proposal Failed: Quorum not met");
        }
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
