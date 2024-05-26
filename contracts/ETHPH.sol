// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ETHPH is ERC20, ERC20Permit, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lastClaimedTime;

    address public ethAddress; // ETH contract address  
    address public usdtAddress; // USDT contract address  
    uint256 public ethRate; // Rate of 1 token in terms of ETH (e.g., 18 decimals) get from chainlink oracle
    uint256 public usdtRate; // Rate of 1 token in terms of USDT (e.g., 18 decimals) get from chainlink oracle
    address[] public stakedUsers;
    uint256 public totalStakedUsers;
    uint256 public constant rewardRate = 100; // Example reward rate: 100 tokens per day
    uint256 public constant claimCooldown = 1 days; // Example cooldown period: 1 day
    uint256 public releaseAmount = 10000000 * (10 ** uint256(decimals())); // 10 million tokens released every month
    uint256 public lastReleaseTime;
    uint256 public constant releaseInterval = 30 days; // Release tokens every 30 days

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event TokensSold(address indexed seller, uint256 amount, uint256 revenue);

    event RewardClaimed(address indexed user, uint256 amount);
    event TokensReleased(uint256 amount);

    constructor()
        ERC20("ETHPH", "ETHPH")
        ERC20Permit("ETHPH")
        Ownable()
    {
        // Mint 21 million tokens initially
        _mint(msg.sender, 100000000 * (10 ** uint256(decimals())));

        // 10 wallet addresses with correct checksums
        address payable[] memory wallets = new address payable[](10);
        wallets[0] = payable(0x7cc58ecBE95c77DBd64f5159c45c12CA6595453D);
        wallets[1] = payable(0xbC935693A79a997CfCcbBdaE8524F6221387Ff93);
        wallets[2] = payable(0x7Dc6525B6AA316B388a19C54fBB0f0fa0cb128e7);
        wallets[3] = payable(0x98d45A79516566B7E9dB045433CEece8e00A4DdB);
        wallets[4] = payable(0x18f1661a70502caa10DAaA495f391F75214baF49);
        wallets[5] = payable(0xc04916675801e1A2EB7668E517921a3C5691Ee21);
        wallets[6] = payable(0x115C808DC1BE36A99cCD4f145eB4E0875079A021);
        wallets[7] = payable(0xaF9162C8258Bc1C840223469D3a6b272792bD34c);
        wallets[8] = payable(0x49D9810Ddca06fb0aE8d89b43E197Ebd364BeD2c);
        wallets[9] = payable(0x2f5C7F990e85CF882ED130711B792FE386319979);
        
        uint256 amountPerWallet = 1000000 * (10 ** uint256(decimals())); // 1 million tokens per wallet

        // Distribute tokens to each wallet
        for (uint256 i = 0; i < wallets.length; i++) {
            _transfer(msg.sender, wallets[i], amountPerWallet);
        }
    }

    /**
     * @dev Function to buy tokens with ETH
     * @param amount The amount of tokens to buy
     */
    function buyTokensWithEth(uint256 amount) external payable {
        require(msg.value >= amount.mul(ethRate), "Insufficient ETH provided");

        _mint(msg.sender, amount);
        emit TokensPurchased(msg.sender, amount, msg.value);
    }

    /**
     * @dev Function to sell tokens for ETH
     * @param amount The amount of tokens to sell
     */
    function sellTokensForEth(uint256 amount) external {
        uint256 ethAmount = amount.mul(ethRate);
        require(address(this).balance >= ethAmount, "Contract does not have enough ETH");

        _burn(msg.sender, amount);
        payable(msg.sender).transfer(ethAmount);
        emit TokensSold(msg.sender, amount, ethAmount);
    }

    /**
     * @dev Function to buy tokens with USDT
     * @param amount The amount of tokens to buy
     */
    function buyTokensWithUsdt(uint256 amount) external {
        IERC20(usdtAddress).transferFrom(msg.sender, address(this), amount.mul(usdtRate));
        _mint(msg.sender, amount);
        emit TokensPurchased(msg.sender, amount, amount.mul(usdtRate));
    }

    /**
     * @dev Function to sell tokens for USDT
     * @param amount The amount of tokens to sell
     */
    function sellTokensForUsdt(uint256 amount) external {
        uint256 usdtAmount = amount.mul(usdtRate);
        require(IERC20(usdtAddress).balanceOf(address(this)) >= usdtAmount, "Contract does not have enough USDT");

        _burn(msg.sender, amount);
        IERC20(usdtAddress).transfer(msg.sender, usdtAmount);
        emit TokensSold(msg.sender, amount, usdtAmount);
    }
   
    /**
     * @dev Function to stake tokens
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);

        // Update staked balance
        stakedBalances[msg.sender] = stakedBalances[msg.sender].add(amount);

        // Update staked users list if the user is not already in the list
        if (stakedBalances[msg.sender] == amount) {
            stakedUsers.push(msg.sender);
            totalStakedUsers++;
        }

        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Function to unstake tokens
     * @param amount The amount of tokens to unstake
     */
    function unstake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(stakedBalances[msg.sender] >= amount, "Insufficient staked balance");

        // Transfer tokens back to user
        _transfer(address(this), msg.sender, amount);

        // Update staked balance
        stakedBalances[msg.sender] = stakedBalances[msg.sender].sub(amount);

        // If user unstaked all tokens, remove them from the staked users list
        if (stakedBalances[msg.sender] == 0) {
            removeUserFromArray(msg.sender);
        }

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev Function to claim rewards
     */
    function claimReward() external {
        require(lastClaimedTime[msg.sender] + claimCooldown <= block.timestamp, "Cooldown period has not elapsed");

        // Calculate reward based on staked balance and time since last claim
        uint256 reward = (stakedBalances[msg.sender] * rewardRate * (block.timestamp - lastClaimedTime[msg.sender])) / (1 days);

        // Update last claimed time
        lastClaimedTime[msg.sender] = block.timestamp;

        // Transfer reward to user
        _transfer(address(this), msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);

        // Select a random user who holds the token
        address randomUser = getRandomUser();
        if (randomUser != address(0)) {
            // Calculate and transfer 5% of the reward to the random user
            uint256 randomReward = reward.mul(5).div(100);
            _transfer(address(this), randomUser, randomReward);
            emit RewardClaimed(randomUser, randomReward);
        }
    }

    /**
     * @dev Function to release tokens to the owner
     */
    function releaseTokens() external onlyOwner {
        require(block.timestamp >= lastReleaseTime.add(releaseInterval), "Release interval not elapsed yet");

        // Update last release time
        lastReleaseTime = block.timestamp;

        // Transfer tokens to owner
        _transfer(address(this), owner(), releaseAmount);

        emit TokensReleased(releaseAmount);
    }

    /**
     * @dev Internal function to remove user from the staked users array
     * @param user The address of the user to be removed
     */
    function removeUserFromArray(address user) private {
        for (uint256 i = 0; i < stakedUsers.length; i++) {
            if (stakedUsers[i] == user) {
                stakedUsers[i] = stakedUsers[stakedUsers.length - 1];
                stakedUsers.pop();
                totalStakedUsers--;
                break;
            }
        }
    }

    /**
     * @dev Internal function to select a random user from the staked users array
     */
    function getRandomUser() internal view returns (address) {
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1))));
        
        // Select a random index based on the number of staked users
        uint256 randomIndex = randomNumber % totalStakedUsers;

        // Get the address of the user at the random index
        address randomUser = stakedUsers[randomIndex];

        return randomUser;
    }


       /**
     * @dev External function to get the ETH rate
     * @return The current ETH rate
     */
    function getEthRate() external view returns (uint256) {
        return ethRate;
    }

    /**
     * @dev External function to get the USDT rate
     * @return The current USDT rate
     */
    function getUsdtRate() external view returns (uint256) {
        return usdtRate;
    }

    /**
     * @dev External function to get the staked balance of an account
     * @param account The address of the account
     * @return The staked balance of the account
     */
    function getStakedBalance(address account) external view returns (uint256) {
        return stakedBalances[account];
    }

    /**
     * @dev External function to get the last claimed time of an account
     * @param account The address of the account
     * @return The last claimed time of the account
     */
    function getLastClaimedTime(address account) external view returns (uint256) {
        return lastClaimedTime[account];
    }

    /**
     * @dev External function to get the total number of staked users
     * @return The total number of staked users
     */
    function getTotalStakedUsers() external view returns (uint256) {
        return totalStakedUsers;
    }

    /**
     * @dev External function to get the array of staked users
     * @return The array of staked users
     */
    function getStakedUsers() external view returns (address[] memory) {
        return stakedUsers;
    }

    /**
     * @dev External function to get the release amount of tokens
     * @return The release amount of tokens
     */
    function getReleaseAmount() external view returns (uint256) {
        return releaseAmount;
    }

    /**
     * @dev External function to get the last release time of tokens
     * @return The last release time of tokens
     */
    function getLastReleaseTime() external view returns (uint256) {
        return lastReleaseTime;
    }

    /**
     * @dev External function to get the next release time of tokens
     * @return The next release time of tokens
     */
    function getNextReleaseTime() external view returns (uint256) {
        return lastReleaseTime.add(releaseInterval);
    }

    /**
     * @dev External function to get the reward rate
     * @return The reward rate
     */
    function getRewardRate() external pure returns (uint256) {
        return rewardRate;
    }

    /**
     * @dev External function to get the claim cooldown period
     * @return The claim cooldown period
     */
    function getClaimCooldown() external pure returns (uint256) {
        return claimCooldown;
    }

    /**
     * @dev External function to get the count of staked users
     * @return The count of staked users
     */
    function getStakedUsersCount() external view returns (uint256) {
        return stakedUsers.length;
    }

}
