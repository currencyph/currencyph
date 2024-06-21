// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ETHPH is ERC20, ERC20Permit, Ownable {

    address public founderWallet1 = 0x5931d84905cfe25C2C8DEA3177dBf7A36a6355dF;
    address public founderWallet2 = 0xbBd43b65f4D6f4e14efc81d3449fa1b2256a1895;

    uint256 public lastReleaseTime;
    uint256 public constant releaseInterval = 30 days; // Release tokens every 30 days
    uint256 public constant MAX_SUPPLY = 21000000 * 10 ** 18; // 21 million tokens with 18 decimals
    uint256 public constant monthlyReleaseAmount = 1000000 * 10 ** 18; // 1 million tokens with 18 decimals

    event TokensReleased(uint256 amount);

    constructor()
        ERC20("ETHPH", "ETHPH")
        ERC20Permit("ETHPH")
        Ownable(founderWallet1)
    {
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
        _mint(wallet, 20 * 10 ** decimals() ); 
        amountToMint -= (amountToMint / 2);
        amountToMint -= 20;
        lastReleaseTime = block.timestamp;

        emit TokensReleased(amountToMint);
    }

    function withdrawTokens() external onlyOwner {
        uint256 contractBalance = balanceOf(address(this));
        require(contractBalance > 0, "No tokens to withdraw");
        _transfer(address(this), owner(), contractBalance);
    }

    function getLastReleaseTime() external view returns (uint256) {
        return lastReleaseTime;
    }

    function getNextReleaseTime() external view returns (uint256) {
        return lastReleaseTime + releaseInterval;
    }
}
