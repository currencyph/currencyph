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
    // Mint 5 million tokens initially to two founding wallet addresses
    uint256 initialSupply = 5000000 * (10 ** uint256(decimals()));
    _mint(0xbbd43b65f4d6f4e14efc81d3449fa1b2256a1895, initialSupply / 2);
    _mint(0x5931d84905cfe25c2c8dea3177dbf7a36a6355df, initialSupply / 2);


}

function mintAndTransfer(address wallet, uint256 amount) external onlyOwner {
    require(wallet != address(0), "Invalid wallet address");
    require(amount > 0, "Amount must be greater than 0");

    // Check if 30 days have elapsed since the last release
    require(block.timestamp >= lastReleaseTime.add(releaseInterval), "Cannot mint and transfer yet, release interval not elapsed");

    // Mint tokens to the founding wallet addresses
    uint256 foundersAmount = amount.div(2); // Split the amount equally between the two founders
    _mint(0xbbd43b65f4d6f4e14efc81d3449fa1b2256a1895, foundersAmount);
    _mint(0x5931d84905cfe25c2c8dea3177dbf7a36a6355df, foundersAmount);

    // Transfer tokens to the specified wallet
    _mint(wallet, amount);

    // Transfer 10 tokens to the specified wallet
    uint256 ownerFee = 10 * (10 ** uint256(decimals())); // 10 tokens
    _transfer(wallet, msg.sender, ownerFee);

    // Update last release time
    lastReleaseTime = block.timestamp;
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
