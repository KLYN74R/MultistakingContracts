// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract NativeCoinsMultistaking is ERC20 {
    
    mapping(address => uint256) public stakingPools;
    
    event StakeOccured(address indexed staker,address indexed toPool, uint256 indexed amount);
    event UnstakeOccured(address indexed unstaker,address indexed fromPool, uint256 indexed amount);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    // Function to stake native coins of network (ETH, BNB, AVAX, etc.)
    function stake(address toPool) external payable {

        require(msg.value > 0, "No funds sent");

        // Assign it to some pool  Обновляем данные замороженных средств пользователя
        stakingPools[toPool] += msg.value;
        
        // Emit appropriate amount of own tokens to save liqudity

        _mint(msg.sender, msg.value);

        emit StakeOccured(msg.sender, toPool, msg.value);
    }

    // Function to receive native coins back by burning current token and unstake from pool
    function unstake(address fromPool, uint256 amount) external {

        require(stakingPools[fromPool] >= amount, "Pool doesn't have enough points to unstake");
        require(balanceOf(msg.sender) >= amount, "Not enough ERC-20 tokens");

        // Burn this tokens and return native coins

        _burn(msg.sender, amount);
        
        payable(msg.sender).transfer(amount);

        if(stakingPools[fromPool] == 0){

            delete stakingPools[fromPool];

        }

        emit UnstakeOccured(msg.sender, fromPool, amount);
    }
    
}
