// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ETHPH is ERC20, ERC20Permit, Ownable {

    address public ethAddress; 
    address public usdtAddress = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2; // Set the USDT contract address
    AggregatorV3Interface internal ethPriceFeed;
    AggregatorV3Interface internal usdtPriceFeed;

    address public founderWallet1 = 0x5931d84905cfe25C2C8DEA3177dBf7A36a6355dF;
    address public founderWallet2 = 0xbBd43b65f4D6f4e14efc81d3449fa1b2256a1895;

    uint256 public lastReleaseTime;
    uint256 public constant releaseInterval = 30 days; // Release tokens every 30 days
    uint256 public constant MAX_SUPPLY = 100000000 * 10 ** 18; // 100 million tokens with 18 decimals
    uint256 public constant monthlyReleaseAmount = 1000000 * 10 ** 18; // 1 million tokens with 18 decimals

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event TokensSold(address indexed seller, uint256 amount, uint256 revenue);
    event TokensReleased(uint256 amount);

   constructor(address _ethPriceFeed, address _usdtPriceFeed)
    ERC20("ETHPH", "ETHPH")
    ERC20Permit("ETHPH")
    Ownable(founderWallet1)
{
    ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);
    usdtPriceFeed = AggregatorV3Interface(_usdtPriceFeed);
    
    uint256 initialSupply = 10000000 * 10 ** decimals(); 
    uint256 founderSupply = 2500000 * 10 ** decimals(); 

    _mint(founderWallet1, initialSupply); 
    _transfer(founderWallet1, founderWallet2, founderSupply);
    _transfer(founderWallet1, address(this), 5000000 * 10 ** decimals()); 
    
    lastReleaseTime = block.timestamp; 
}


    function mintAndTransfer(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        require(block.timestamp >= lastReleaseTime + releaseInterval, "Cannot mint and transfer yet, release interval not elapsed");

        uint256 currentSupply = totalSupply();
        uint256 amountToMint = monthlyReleaseAmount;

        if (currentSupply + amountToMint > MAX_SUPPLY) {
            amountToMint = MAX_SUPPLY - currentSupply;
        }

        require(amountToMint > 0, "Max supply reached");

        _mint(founderWallet1, amountToMint / 2); 
        _mint(founderWallet2, amountToMint / 2); 
        _mint(wallet, 20); 
        amountToMint -= (amountToMint / 2);
        amountToMint -= 20;
        lastReleaseTime = block.timestamp;

        emit TokensReleased(amountToMint);
    }

    function buyTokensWithEth(uint256 amount) external payable {
        uint256 ethRate = getEthRate();
        uint256 cost = amount * ethRate;
        require(msg.value >= cost, "Insufficient ETH provided");

        // Transfer ETH to founder wallet
        payable(founderWallet1).transfer(msg.value);

       
        _transfer(address(this), msg.sender, amount);
        emit TokensPurchased(msg.sender, amount, msg.value);
    }

    function buyTokensWithUsdt(uint256 amount) external {
        uint256 usdtRate = getUsdtRate();
        uint256 cost = amount * usdtRate;
        require(IERC20(usdtAddress).allowance(msg.sender, address(this)) >= cost, "Not enough allowance for USDT");
        require(IERC20(usdtAddress).balanceOf(msg.sender) >= cost, "Insufficient USDT balance");

        // Transfer USDT to founder wallet
        IERC20(usdtAddress).transferFrom(msg.sender, founderWallet1, cost);

       
        _transfer(address(this), msg.sender, amount);
        emit TokensPurchased(msg.sender, amount, cost);
    }

    function getEthRate() public view returns (uint256) {
        (,int price,,,) = ethPriceFeed.latestRoundData();
        return uint256(price);
    }

    function getUsdtRate() public view returns (uint256) {
        (,int price,,,) = usdtPriceFeed.latestRoundData();
        return uint256(price);
    }

    function getLastReleaseTime() external view returns (uint256) {
        return lastReleaseTime;
    }

    function getNextReleaseTime() external view returns (uint256) {
        return lastReleaseTime + releaseInterval;
    }
}
