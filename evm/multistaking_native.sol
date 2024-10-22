// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NativeCoinsMultistaking is ERC20 {
    
    mapping(address => uint256) public stakingPools;
    
    event StakeOccured(address indexed staker, address indexed toPool, uint256 indexed amount);
    event UnstakeOccured(address indexed unstaker, address indexed fromPool, uint256 indexed amount);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    // Function to stake native coins of network (ETH, BNB, AVAX, etc.)
    function stake(address toPool) external payable {
        require(msg.value > 0, "No funds sent");

        // Assign native coins to the pool
        stakingPools[toPool] += msg.value;
        
        // Mint equivalent amount of own tokens
        _mint(msg.sender, msg.value);

        emit StakeOccured(msg.sender, toPool, msg.value);
    }

    // Function to receive native coins back by burning current token and unstake from pool
    function unstake(address fromPool, uint256 amount) external {

        require(stakingPools[fromPool] >= amount, "Pool doesn't have enough points to unstake");
        require(balanceOf(msg.sender) >= amount, "Not enough ERC-20 tokens");

        // Burn tokens and return native coins
        _burn(msg.sender, amount);

        // Reduce staking points in the pool
        stakingPools[fromPool] -= amount;
        
        payable(msg.sender).transfer(amount);

        if (stakingPools[fromPool] == 0) {
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

            // Burn tokens and prepare to return native coins
            _burn(msg.sender, amount);

            // Reduce staking points in the pool
            stakingPools[fromPool] -= amount;

            // Accumulate total unstaked amount
            totalUnstaked += amount;

            if (stakingPools[fromPool] == 0) {
                delete stakingPools[fromPool];
            }

            emit UnstakeOccured(msg.sender, fromPool, amount);
        }

        // Transfer the total unstaked native coins
        payable(msg.sender).transfer(totalUnstaked);
    }
}