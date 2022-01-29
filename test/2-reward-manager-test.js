const { expect } = require("chai");
const { ethers } = require("hardhat");

const parseNodeTypes = (input) => {
  const types = input.split('-');
  let nodeTypes = [];

  types.map(v => {
    tokens = v.split('#');
    const nodeType = {
      nodeTypeName: tokens[0],
      nodePrice: tokens[1],
      claimTime: tokens[2],
      rewardAmount: tokens[3],
      claimTaxBeforeTime: tokens[4],
    };
    nodeTypes.push(nodeType);
  })

  return nodeTypes;
}

const parseCreationTimes = (input) => {
  const tokens = input.split('#');
  let result = [];

  tokens.map(v => {
    result.push(parseInt(v));
  })

  return result;
}

describe("NODERewardManagement", function () {
  let rewardManager;
  let addrs;

  beforeEach(async function () {
    addrs = await ethers.getSigners();
    // console.log('Count:', addrs.length)
    // addrs.map(v => {
    //   console.log('address', v.address);
    // })
    

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

  it("NodeType Management", async function () {
    /////////////// add NodeTypes and retrieve them to check ///////////////
    let tx, result;
    let nodeTypesResult;
    nodeTypesResult = await rewardManager.getNodeTypes();
    // console.log('nodeTypesResult:', nodeTypesResult);
    // console.log('nodeTypesResult:', typeof(nodeTypesResult));
    expect(nodeTypesResult).to.equal('');   // there is not NodeType so the result should be an empty string

    tx = await rewardManager.addNodeType('Axe', 20, 10, 20, 10);
    await tx.wait();
    tx = await rewardManager.addNodeType('Sladar', 30, 20, 30, 20);
    await tx.wait();
    tx = await rewardManager.addNodeType('Naix', 60, 30, 60, 30);
    await tx.wait();
    tx = await rewardManager.addNodeType('Sven', 50, 40, 50, 40);
    await tx.wait();
    tx = await rewardManager.addNodeType('Rikimaru', 60, 50, 60, 50);
    await tx.wait();
    tx = await rewardManager.addNodeType('Balana', 70, 60, 70, 60);
    await tx.wait();

    // tx = await rewardManager.getNodeTypes();
    // nodeTypesResult = await tx.wait();
    nodeTypesResult = await rewardManager.getNodeTypes();
    // console.log('nodeTypesResult:', nodeTypesResult);
    let nodeTypes;
    nodeTypes = parseNodeTypes(nodeTypesResult);
    // console.log('nodeTypes', nodeTypes);
    expect(nodeTypes.length).to.equal(6);
    expect(nodeTypes[0].nodeTypeName).to.equal('Axe');
    expect(nodeTypes[5].nodeTypeName).to.equal('Balana');


    /////////////// change NodeTypes and retrieve them to check ///////////////
    // if you want to not change any property, pass -1
    tx = await rewardManager.changeNodeType('Axe', 100, -1, 100, -1);
    await tx.wait();
    nodeTypes = parseNodeTypes(await rewardManager.getNodeTypes());
    // console.log('nodeTypes', nodeTypes);
    expect(nodeTypes.length).to.equal(6);
    expect(nodeTypes[0].nodeTypeName).to.equal('Axe');
    expect(nodeTypes[0].nodePrice).to.equal('100');
    expect(nodeTypes[0].claimTime).to.equal('10');
    expect(nodeTypes[0].rewardAmount).to.equal('100');
    expect(nodeTypes[0].claimTaxBeforeTime).to.equal('10');


    /////////////// create new nodes ///////////////
    tx = await rewardManager.createNode(addrs[3].address, 'Axe', 10);
    await tx.wait();

    result = await rewardManager._getNodesCreationTime(addrs[3].address);
    // console.log('_getNodesCreationTime', result);

    let creationTimes;
    creationTimes = parseCreationTimes(result);
    // console.log(creationTimes);
    expect(creationTimes.length).to.equal(10);
    expect(creationTimes[9] - creationTimes[0]).to.equal(9);

    tx = await rewardManager.createNode(addrs[3].address, 'Balana', 4);
    await tx.wait();

    result = await rewardManager._getNodesCreationTime(addrs[3].address);

    creationTimes = parseCreationTimes(result);
    // console.log(creationTimes);
    expect(creationTimes.length).to.equal(14);

    /////////////// reward ///////////////
    let leftTime;
    leftTime = await rewardManager.getLeftTimeFromReward(addrs[3].address, creationTimes[0]);
    // console.log('leftTime', leftTime);
    expect(leftTime).to.equal(9);   // 9s left, 1s passed

    // let rewardAmount;
    // rewardAmount = await rewardManager._getRewardAmountOf(addrs[3].address, creationTimes[0]);
    
  });
});
