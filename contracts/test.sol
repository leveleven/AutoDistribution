// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract AutoDistribution {
    IERC20 public token;
    address public owner;
    uint256 public onlineReward = 60 * token.decimals(); // 在线奖励
    uint256 public roundUnlock = (onlineReward * 70) / 100 / 180;  // 每轮释放

    uint256 public lastDistributionBlock;
    uint256 public constant DISTRIBUTION_BLOCK_INTERVAL = 7200;              // 约 1 天（假设 12s/块）
    uint256 public constant LOCK_BLOCKS = 1080000;                           // 约 180 天（180 * 24 * 60 * 60 / 12）
    uint256 public constant EARLY_UNLOCK_PERCENT = 30;                       // 允许提前解锁 30%

    struct LockInfo {
        uint256 totalAmount;
        uint256 startBlock;       // 锁仓释放
        // uint256 lastClaimedBlock; // 线性释放
        bool isUnlocked;
    }

    struct Reward {
        LockInfo[] lockInfo;
        uint256 unlockedAmount;
    }

    mapping(address => address) public bindingWallets; // 绑定钱包 收益地址 -> 收款地址
    // 收益交互
    mapping(address => Reward) public lockedBalances;  // 线性解锁记录
    mapping(address => bool) public authorizedAddress; // 收益地址
    address[] public recipients; // 钱包地址列表

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
        lastDistributionBlock = block.number;
    }

    // 添加收益地址（机器）
    function addWallet(address wallet) public onlyOwner {
        require(!authorizedAddress[wallet], "Wallet already added");

        authorizedAddress[wallet] = true;
        recipients.push(wallet);
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
                    // lastClaimedBlock: lastDistributionBlock,   // 线性释放
                    isUnlocked: false
                }));
            // }
        }
    }

    // 锁仓直接释放
    function claimUnlockedTokens(address _rewardAddress) public {
        require(bindingWallets[_rewardAddress] == msg.sender, "No binding");
        Reward storage reward = lockedBalances[_rewardAddress];
        require(reward.lockInfo.length > 0, "No locked tokens");

        for (uint256 i = 0; i < reward.lockInfo.length; i++) {
            if (!reward.lockInfo[i].isUnlocked) {
                uint256 elapsedBlocks = block.number - reward.lockInfo[i].startBlock;
                if (elapsedBlocks >= LOCK_BLOCKS) {
                    reward.unlockedAmount += reward.lockInfo[i].totalAmount;
                    reward.lockInfo[i].totalAmount = 0;
                }
            }
        }
    }

    // 线性释放 （测试）
    // function claimReleaseTokens(address _rewardAddress) public {
    //     require(bindingWallets[_rewardAddress] == msg.sender, "No binding");
    //     Reward storage reward = lockedBalances[_rewardAddress];
    //     require(reward.lockInfo.length > 0, "No locked tokens");

    //     for (uint256 i = 0; i < reward.lockInfo.length; i++) {
    //         if (!reward.lockInfo[i].isUnlocked) {
    //             uint256 elapsedBlocks;
    //             if (block.number - reward.lockInfo[i].startBlock >= LOCK_BLOCKS) {
    //                 elapsedBlocks = reward.lockInfo[i].startBlock + LOCK_BLOCKS - reward.lockInfo[i].lastClaimedBlock;
    //             } else {
    //                 elapsedBlocks = block.number - reward.lockInfo[i].lastClaimedBlock;
    //             }
    //             require(elapsedBlocks >= DISTRIBUTION_BLOCK_INTERVAL, "Not yet reached next unlock point");

    //             uint256 unlockRounds = elapsedBlocks / DISTRIBUTION_BLOCK_INTERVAL;
    //             uint256 unlockReward = unlockRounds * roundUnlock;
    //             if (unlockReward < reward.lockInfo[i].totalAmount) {
    //                 reward.unlockedAmount += unlockReward;
    //                 reward.lockInfo[i].totalAmount -= unlockReward;
    //                 reward.lockInfo[i].lastClaimedBlock += unlockRounds * DISTRIBUTION_BLOCK_INTERVAL;
    //             } else {
    //                 reward.unlockedAmount += reward.lockInfo[i].totalAmount;
    //                 reward.lockInfo[i].totalAmount = 0;
    //                 reward.lockInfo[i].isUnlocked = true;
    //             }
    //         }
    //     }
    // }

    // 提款
    function withdraw(address _rewardAddress) public {
        require(bindingWallets[_rewardAddress] == msg.sender, "No binding");
        Reward storage reward = lockedBalances[_rewardAddress];

        require(reward.unlockedAmount > 0, "No unlocked tokens yet");
        require(token.transfer(msg.sender, reward.unlockedAmount), "Transfer failed");
        reward.unlockedAmount = 0;
    }

    // 允许合约管理员调整解锁时间
    function updateLockPeriod(uint256 newLockPeriod) public view onlyOwner {
        require(newLockPeriod > 0, "Lock period must be positive");
    }

    // 提前解锁 30%，其余 70% 作为惩罚回归合约
    function earlyUnlock(address _rewardAddress) public {
        require(bindingWallets[_rewardAddress] == msg.sender, "No binding");
        Reward storage reward = lockedBalances[_rewardAddress];

        uint256 earlyAmount = 0;
        for (uint256 i = 0; i <  reward.lockInfo.length; i ++) {
            if (!reward.lockInfo[i].isUnlocked) {
                earlyAmount += (reward.lockInfo[i].totalAmount * EARLY_UNLOCK_PERCENT) / 100;
                reward.lockInfo[i].isUnlocked = true;
                reward.lockInfo[i].totalAmount = 0; // 清除锁仓数据，防止二次解锁
            }
        }
        require(earlyAmount > 0, "No locked tokens");
        reward.unlockedAmount += earlyAmount;
    }

    // 获取钱包是否被授权
    function isAuthorized(address wallet) public view returns (bool) {
        return authorizedAddress[wallet];
    }
}
