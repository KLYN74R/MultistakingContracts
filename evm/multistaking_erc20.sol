// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Multistaking is ERC20 {

    IERC20 public depositToken; // target token to accept as multistaking
    
    mapping(address => uint256) public stakingPools;
    
    event StakeOccured(address indexed staker,address indexed toPool, uint256 indexed amount);
    event UnstakeOccured(address indexed unstaker,address indexed fromPool, uint256 indexed amount);

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

        require(depositToken.transfer(msg.sender, amount), "Transfer failed");

        if(stakingPools[fromPool] == 0){

            delete stakingPools[fromPool];

        }

        emit UnstakeOccured(msg.sender, fromPool, amount);
        
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

            require(depositToken.transfer(msg.sender, amount), "Transfer failed");

            if (stakingPools[fromPool] == 0) {
                delete stakingPools[fromPool];
            }

            emit UnstakeOccured(msg.sender, fromPool, amount);
            totalUnstaked += amount;
        }

        require(totalUnstaked > 0, "No tokens unstaked");
    }

}