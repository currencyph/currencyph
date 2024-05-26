import "hardhat-deploy/solc-0.8/proxy/deploy-libraries/Deployer.sol";
import {ethers} from "hardhat";
import {BigNumber} from "ethers";

describe("ETHPH", function () {
  let contract;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  const INITIAL_SUPPLY = BigNumber.from("100000000000000000000000000");
  const STAKING_AMOUNT = BigNumber.from("1000000000000000000000");

  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    const ETHPH = await ethers.getContractFactory("ETHPH");
    contract = await ETHPH.deploy();
    await contract.deployed();
  });

  it("Should return the total supply", async function () {
    expect(await contract.totalSupply()).to.equal(INITIAL_SUPPLY);
  });

  it("Should allow staking tokens", async function () {
    await contract.stake(STAKING_AMOUNT);
    expect(await contract.getStakedBalance(owner.address)).to.equal(STAKING_AMOUNT);
    expect(await contract.getStakedUsersCount()).to.equal(1);
  });

  it("Should not allow staking more than balance", async function () {
    await expect(contract.stake(STAKING_AMOUNT.add(1))).to.be.revertedWith("Insufficient balance");
  });

  it("Should allow unstaking tokens", async function () {
    await contract.stake(STAKING_AMOUNT);
    await contract.unstake(STAKING_AMOUNT);
    expect(await contract.getStakedBalance(owner.address)).to.equal(0);
    expect(await contract.getStakedUsersCount()).to.equal(0);
  });

  it("Should not allow unstaking more than staked balance", async function () {
    await contract.stake(STAKING_AMOUNT);
    await expect(contract.unstake(STAKING_AMOUNT.add(1))).to.be.revertedWith("Insufficient staked balance");
  });

  it("Should allow claiming rewards", async function () {
    await contract.stake(STAKING_AMOUNT);
    await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
    await ethers.provider.send("evm_mine"); // Mine a new block to update block.timestamp
    await contract.claimReward();
    const balance = await contract.balanceOf(owner.address);
    expect(balance).to.be.gt(0);
  });

  it("Should release tokens to the owner after release interval", async function () {
    const releaseAmount = await contract.getReleaseAmount();
    await ethers.provider.send("evm_increaseTime", [2592000]); // Increase time by 30 days
    await ethers.provider.send("evm_mine"); // Mine a new block to update block.timestamp
    await contract.releaseTokens();
    const ownerBalance = await contract.balanceOf(owner.address);
    expect(ownerBalance).to.equal(releaseAmount);
  });
});
