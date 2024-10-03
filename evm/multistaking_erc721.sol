// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ERC721Multistaking is ERC721 {

    using EnumerableSet for EnumerableSet.UintSet;

    IERC721 public depositToken; // token to accept
    
    mapping(address => EnumerableSet.UintSet) private stakingPools;

    event StakeOccured(address indexed staker, address indexed toPool, uint256 indexed tokenId);
    event UnstakeOccured(address indexed unstaker, address indexed fromPool, uint256 indexed tokenId);

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
        depositToken.transferFrom(address(this), msg.sender, tokenId);

        emit UnstakeOccured(msg.sender, fromPool, tokenId);
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
