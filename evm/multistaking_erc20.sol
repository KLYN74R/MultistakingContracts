// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Multistaking is ERC20 {

    IERC20 public depositToken; // target token to accept as multistaking
    
    mapping(address => uint256) public stakingPools;

    struct WithdrawalRequest {
        uint256 amount;
        uint256 unlockTime;
    }
    
    mapping(address => WithdrawalRequest[]) public withdrawalRequests;
    
    uint256 public lockPeriod = 3 days;

    event StakeOccured(address indexed staker, address indexed toPool, uint256 indexed amount);
    event UnstakeRequested(address indexed unstaker, address indexed fromPool, uint256 indexed amount, uint256 unlockTime);
    event UnstakeMultipleRequested(address indexed unstaker, uint256 indexed totalAmount, uint256 unlockTime);
    event Withdrawal(address indexed unstaker, uint256 indexed amount);

    constructor(
        string memory name, 
        string memory symbol, 
        address _depositToken
    ) ERC20(name, symbol) {
        depositToken = IERC20(_depositToken);
    }

    // Function to stake ERC-20 tokens to some pool
    function stake(address toPool, uint256 amount) external {
        
        require(amount > 0, "No tokens provided");

        // Transfer stake to the address of current contract

        require(depositToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Update the value of staking points for pool
        stakingPools[toPool] += amount;

        // Emit own token to save liquidity
        _mint(msg.sender, amount);

        emit StakeOccured(msg.sender, toPool, amount);
    }


    // Function to unstake
    function unstake(address fromPool, uint256 amount) external {
        
        require(stakingPools[fromPool] >= amount, "Pool doesn't have enough points to unstake");
        require(balanceOf(msg.sender) >= amount, "Not enough ERC-20 tokens");

        // Burn this tokens and return the real token to staker
        _burn(msg.sender, amount);
        
        // Reduce the staking points from pool
        stakingPools[fromPool] -= amount;

        withdrawalRequests[msg.sender].push(WithdrawalRequest({
            amount: amount,
            unlockTime: block.timestamp + lockPeriod
        }));

        emit UnstakeRequested(msg.sender, fromPool, amount, block.timestamp + lockPeriod);
    }

    // Function to unstake from multiple pools in one call
    function unstakeMultiple(address[] memory fromPools, uint256[] memory amounts) external {
        
        require(fromPools.length == amounts.length, "Pools and amounts array length mismatch");

        uint256 totalUnstaked = 0;

        for (uint256 i = 0; i < fromPools.length; i++) {
            address fromPool = fromPools[i];
            uint256 amount = amounts[i];

            require(stakingPools[fromPool] >= amount, "Pool doesn't have enough points to unstake");
            require(balanceOf(msg.sender) >= amount, "Not enough ERC-20 tokens");

            // Burn the tokens and return the real token to staker
            _burn(msg.sender, amount);

            // Reduce the staking points from the pool
            stakingPools[fromPool] -= amount;
            totalUnstaked += amount;

            if (stakingPools[fromPool] == 0) {
                delete stakingPools[fromPool];
            }

            emit UnstakeRequested(msg.sender, fromPool, amount, block.timestamp + lockPeriod);
        }

        withdrawalRequests[msg.sender].push(WithdrawalRequest({
            amount: totalUnstaked,
            unlockTime: block.timestamp + lockPeriod
        }));

        emit UnstakeMultipleRequested(msg.sender, totalUnstaked, block.timestamp + lockPeriod);
    }


    function withdraw() external {
        uint256 totalAmountToWithdraw = 0;

        WithdrawalRequest[] storage requests = withdrawalRequests[msg.sender];

        for (uint256 i = 0; i < requests.length; i++) {
            if (block.timestamp >= requests[i].unlockTime && requests[i].amount > 0) {
                totalAmountToWithdraw += requests[i].amount;
                delete requests[i];
            }
        }

        require(totalAmountToWithdraw > 0, "No withdrawable amount");

        require(depositToken.transfer(msg.sender, totalAmountToWithdraw), "Transfer failed");

        emit Withdrawal(msg.sender, totalAmountToWithdraw);
    }
}
