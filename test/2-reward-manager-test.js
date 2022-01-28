const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NODERewardManagement", function () {
  let rewardManager;
  let addrs;

  beforeEach(async function () {
    addrs = await ethers.getSigners();
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
    rewardManager = await NODERewardManagement.deploy(
        nodePrice,
        rewardPerNode,
        claimTime,
        addrs[1].address,
        addrs[2].address,
    );
    await rewardManager.deployed();

    // check addres is not equal to zero
    expect(rewardManager.address).to.not.equal(0);

    // const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    // // wait until the transaction is mined
    // await setGreetingTx.wait();

    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });

  it("NodeType", async function () {
    let tx;
    let nodeTypesResult;
    nodeTypesResult = await rewardManager.getNodeTypes();
    console.log('nodeTypesResult:', nodeTypesResult);
    // console.log('nodeTypesResult:', typeof(nodeTypesResult));
    expect(nodeTypesResult).to.equal('');   // there is not NodeType so the result should be an empty string

    tx = await rewardManager.addNodeType('Axe', 20, 1, 20);
    await tx.wait();
    tx = await rewardManager.addNodeType('Sladar', 30, 2, 30);
    await tx.wait();
    tx = await rewardManager.addNodeType('Naix', 60, 5, 60);
    await tx.wait();
    tx = await rewardManager.addNodeType('Sven', 50, 4, 50);
    await tx.wait();
    tx = await rewardManager.addNodeType('Rikimaru', 60, 5, 60);
    await tx.wait();
    tx = await rewardManager.addNodeType('Balana', 70, 6, 70);
    await tx.wait();

    // tx = await rewardManager.getNodeTypes();
    // nodeTypesResult = await tx.wait();
    nodeTypesResult = await rewardManager.getNodeTypes();
    console.log('nodeTypesResult:', nodeTypesResult);
  });
});
