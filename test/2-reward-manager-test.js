const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NODERewardManagement", function () {
  it("Deploy", async function () {
    const addrs = await ethers.getSigners();
    console.log('Count:', addrs.length)
    addrs.map(v => {
      console.log('address', v.address);
    })
    

    const IterableMapping = await ethers.getContractFactory("IterableMapping");
    iterableMapping = await IterableMapping.deploy();
    const IterableNodeTypeMapping = await ethers.getContractFactory("IterableNodeTypeMapping");
    iterableNodeTypeMapping = await IterableNodeTypeMapping.deploy();

    const NODERewardManagement = await ethers.getContractFactory("NODERewardManagement", {
      libraries: {
        IterableMapping: iterableMapping.address,
        IterableNodeTypeMapping: iterableNodeTypeMapping.address,
      },
    });
    const nodePrice = 100;
    const rewardPerNode = 54;
    const claimTime = 97;
    const rewardManager = await NODERewardManagement.deploy(
        nodePrice,
        rewardPerNode,
        claimTime,
        addrs[1].address,
        addrs[2].address,
    );
    await rewardManager.deployed();

    // expect(await greeter.greet()).to.equal("Hello, world!");

    // const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    // // wait until the transaction is mined
    // await setGreetingTx.wait();

    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});
