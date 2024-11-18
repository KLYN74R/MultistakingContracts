// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NativeCoinsMultistaking is ERC20 {
    
    mapping(string => uint256) public stakingPools;
    
    struct WithdrawalRequest {
        uint256 amount;
        uint256 unlockTime;
    }
    
    mapping(address => WithdrawalRequest[]) public withdrawalRequests;
    
    uint256 public lockPeriod = 3 days;

    event StakeOccured(address indexed staker, string indexed toPool, uint256 indexed amount);
    event UnstakeRequested(address indexed unstaker, string indexed fromPool, uint256 indexed amount, uint256 unlockTime);
    event UnstakeMultipleRequested(address indexed unstaker, uint256 indexed totalAmount, uint256 unlockTime);
    event Withdrawal(address indexed unstaker, uint256 indexed amount);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function stake(string memory toPool) external payable {
        require(msg.value > 0, "No funds sent");
        
        stakingPools[toPool] += msg.value;

        _mint(msg.sender, msg.value);

        emit StakeOccured(msg.sender, toPool, msg.value);
    }

    function unstake(string memory fromPool, uint256 amount) external {
        require(stakingPools[fromPool] >= amount, "Pool doesn't have enough points to unstake");
        require(balanceOf(msg.sender) >= amount, "Not enough ERC-20 tokens");

        _burn(msg.sender, amount);

        stakingPools[fromPool] -= amount;

        withdrawalRequests[msg.sender].push(WithdrawalRequest({
            amount: amount,
            unlockTime: block.timestamp + lockPeriod
        }));

        emit UnstakeRequested(msg.sender, fromPool, amount, block.timestamp + lockPeriod);
    }


    function unstakeMultiple(string[] memory fromPools, uint256[] memory amounts) external {
        require(fromPools.length == amounts.length, "Pools and amounts array length mismatch");

        uint256 totalUnstaked = 0;

        for (uint256 i = 0; i < fromPools.length; i++) {
            string memory fromPool = fromPools[i];
            uint256 amount = amounts[i];

            require(stakingPools[fromPool] >= amount, "Pool doesn't have enough points to unstake");
            require(balanceOf(msg.sender) >= amount, "Not enough ERC-20 tokens");

            _burn(msg.sender, amount);

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

        payable(msg.sender).transfer(totalAmountToWithdraw);

        emit Withdrawal(msg.sender, totalAmountToWithdraw);
    }
}
