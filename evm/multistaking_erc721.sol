// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ERC721Multistaking is ERC721 {

    using EnumerableSet for EnumerableSet.UintSet;

    IERC721 public depositToken; // token to accept

    mapping(address => EnumerableSet.UintSet) private stakingPools;

    struct WithdrawalRequest {
        uint256 tokenId;
        uint256 unlockTime;
    }
    
    mapping(address => WithdrawalRequest[]) public withdrawalRequests;

    uint256 public lockPeriod = 3 days;

    event StakeOccured(address indexed staker, address indexed toPool, uint256 indexed tokenId);
    event UnstakeRequested(address indexed unstaker, address indexed fromPool, uint256 indexed tokenId, uint256 unlockTime);
    event Withdrawal(address indexed unstaker, uint256 indexed tokenId);

    constructor(
        string memory name, 
        string memory symbol, 
        address _depositToken
    ) ERC721(name, symbol) {
        depositToken = IERC721(_depositToken);
    }

    // Function to stake NFT to pool
    function stake(address toPool, uint256 tokenId) external {

        require(depositToken.ownerOf(tokenId) == msg.sender, "You are not the owner of this token");

        // Transfer NFT to this contract
        depositToken.transferFrom(msg.sender, address(this), tokenId);

        // Assign to staking pool
        stakingPools[toPool].add(tokenId);

        // Mint own token for liquidity
        _mint(msg.sender, tokenId);

        emit StakeOccured(msg.sender, toPool, tokenId);

    }

    // Unstake NFT from pool
    function unstake(address fromPool, uint256 tokenId) external {
        require(stakingPools[fromPool].contains(tokenId), "Pool doesn't have this token staked");
        require(ownerOf(tokenId) == msg.sender, "You are not the owner of this staked token");

        // Burn our liquidity token
        _burn(tokenId);

        // Remove token from pool
        stakingPools[fromPool].remove(tokenId);

        // ... and return the original NFT to owner
        withdrawalRequests[msg.sender].push(WithdrawalRequest({
            tokenId: tokenId,
            unlockTime: block.timestamp + lockPeriod
        }));

        emit UnstakeRequested(msg.sender, fromPool, tokenId, block.timestamp + lockPeriod);
    }


    function withdraw() external {
        uint256 withdrawCount = 0;

        WithdrawalRequest[] storage requests = withdrawalRequests[msg.sender];

        for (uint256 i = 0; i < requests.length; i++) {
            if (block.timestamp >= requests[i].unlockTime && requests[i].tokenId != 0) {
                uint256 tokenId = requests[i].tokenId;
                
                // Return original NFT to owner
                depositToken.transferFrom(address(this), msg.sender, tokenId);

                withdrawCount++;

                emit Withdrawal(msg.sender, tokenId);

                delete requests[i];
            }
        }

        require(withdrawCount > 0, "No tokens available for withdrawal");
    }

    // To list all tokens staked in some pool
    function getStakedTokens(address pool) external view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](stakingPools[pool].length());

        for (uint256 i = 0; i < stakingPools[pool].length(); i++) {
            tokenIds[i] = stakingPools[pool].at(i);
        }

        return tokenIds;
    }
}
