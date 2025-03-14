// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Distribution {

    uint256 public lastDistributionBlock;

    uint256 public onlineReward = 60;                              // 在线奖励
    uint256 public roundUnlock = (onlineReward * 70) / 100 / 180;  // 每轮释放
    uint256 public DISTRIBUTION_BLOCK_INTERVAL = 7200;             // 约 1 天（假设 12s/块）
    uint256 public LOCK_BLOCKS = 1080000;                          // 约 180 天（180 * 24 * 60 * 60 / 12）

    struct LockInfo {
        uint256 totalAmount;
        uint256 startBlock;       // 锁仓释放
        uint256 lastClaimedBlock; // 线性释放
        bool isUnlocked;
    }

    struct Reward {
        LockInfo[] lockInfo;
        uint256 unlockedAmount;
    }

    mapping(address => Reward) public lockedBalances;  // 线性解锁记录
    address[] public recipients; // 钱包地址列表

    constructor() {
        lastDistributionBlock = block.number;
    }

    // 自动分发
    function distributeRewards() public {
        require(block.number >= lastDistributionBlock + DISTRIBUTION_BLOCK_INTERVAL, "Distribution not ready");

        lastDistributionBlock = block.number;
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            // if (checkNode[recipient].length >= 3) {
                uint256 initialAmount = (onlineReward * 30) / 100;
                lockedBalances[recipient].unlockedAmount += initialAmount;
                lockedBalances[recipient].lockInfo.push(LockInfo({
                    totalAmount: onlineReward - initialAmount,
                    startBlock: lastDistributionBlock,         // 锁仓释放
                    lastClaimedBlock: lastDistributionBlock,   // 线性释放
                    isUnlocked: false
                }));
            // }
        }
    }

    function checkClaimRelease() public view returns (uint256) {
        Reward storage reward = lockedBalances[msg.sender];
        require(reward.lockInfo.length > 0, "No locked tokens");

        uint256 unlockedAmount = reward.unlockedAmount;
        for (uint256 i = 0; i < reward.lockInfo.length; i++) {
            if (!reward.lockInfo[i].isUnlocked) {
                uint256 elapsedBlocks;
                if (block.number - reward.lockInfo[i].startBlock >= LOCK_BLOCKS) {
                    elapsedBlocks = reward.lockInfo[i].startBlock + LOCK_BLOCKS - reward.lockInfo[i].lastClaimedBlock;
                } else {
                    elapsedBlocks = block.number - reward.lockInfo[i].lastClaimedBlock;
                }
                require(elapsedBlocks >= DISTRIBUTION_BLOCK_INTERVAL, "Not yet reached next unlock point");

                uint256 unlockRounds = elapsedBlocks / DISTRIBUTION_BLOCK_INTERVAL;
                uint256 unlockReward = unlockRounds * roundUnlock;
                if (unlockReward < reward.lockInfo[i].totalAmount) {
                    unlockedAmount += unlockReward;
                } else {
                    unlockedAmount += reward.lockInfo[i].totalAmount;
                }
            }
        }
        return unlockedAmount;
    }
}