const { expect, assert } = require("chai");
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
      nextLevelNodeTypeName: tokens[5],
      levelUpCount: tokens[6],
    };
    nodeTypes.push(nodeType);
  })

  return nodeTypes;
}

const parseString = (input) => {
  const types = input.split('-');
  let result = [];

  types.map(v => {
    result.push(v.split('#'));
  })

  return result;
}

const parseCreationTimes = (input) => {
  const tokens = input.split('#');
  let result = [];

  tokens.map(v => {
    result.push(parseInt(v));
  })

  return result;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

describe("NODERewardManagement", function () {
  let rewardManager;
  let addrs;

  beforeEach(async function () {
    this.timeout(1000000) // 10 second timeout for setup


    addrs = await ethers.getSigners();
    // console.log('Count:', addrs.length)
    // addrs.map(v => {
    //   console.log('address', v.address);
    // })
    

    const IterableMapping = await ethers.getContractFactory("IterableMapping");
    iterableMapping = await IterableMapping.attach('0x19cf9553EF064A4f2669d4a045388765A77D4643');
    const IterableNodeTypeMapping = await ethers.getContractFactory("IterableNodeTypeMapping");
    iterableNodeTypeMapping = await IterableNodeTypeMapping.attach('0x48846a44B74915B8adFed135D705173AFfC9cE09');

    const NODERewardManagement = await ethers.getContractFactory("NODERewardManagement", {
      libraries: {
        IterableMapping: iterableMapping.address,
        IterableNodeTypeMapping: iterableNodeTypeMapping.address,
      },
    });
    rewardManager = await NODERewardManagement.attach('0x5C0FC0b1166F8145E7b1AA74d691F51bc86dc55B');
    // await rewardManager.deployed();

    // console.log('rewardManager', rewardManager);
    // check addres is not equal to zero
    // expect(rewardManager.address).to.not.equal(0);
  });

  it("All tests", async function () {
    this.timeout(1000000) // 10 second timeout for setup

    /////////////// add NodeTypes and retrieve them to check ///////////////
    let tx, result;
    let nodeTypesResult;
    nodeTypesResult = await rewardManager.getNodeTypes();
    console.log('nodeTypesResult:', nodeTypesResult);
    // console.log('nodeTypesResult:', typeof(nodeTypesResult));
    // expect(nodeTypesResult).to.equal('');   // there is not NodeType so the result should be an empty string

    // tx = await rewardManager.addNodeType('Axe', 1, 10, 10, 10, "", 0);
    // await tx.wait();
    // tx = await rewardManager.addNodeType('Sladar', 30, 20, 30, 20, "Axe", 5);
    // await tx.wait();
    // tx = await rewardManager.addNodeType('Naix', 60, 30, 60, 30, "Sladar", 5);
    // await tx.wait();
    // tx = await rewardManager.addNodeType('Sven', 50, 40, 50, 40, "Naix", 5);
    // await tx.wait();
    // tx = await rewardManager.addNodeType('Rikimaru', 60, 50, 60, 50, "Sven", 5);
    // await tx.wait();
    // tx = await rewardManager.addNodeType('Balana', 70, 60, 70, 60, "Rikimaru", 5);
    // await tx.wait();

    // nodeTypesResult = await rewardManager.getNodeTypes();
    // console.log('nodeTypesResult:', nodeTypesResult);
    // // let nodeTypes;
    nodeTypes = parseNodeTypes(await rewardManager.getNodeTypes());
    // console.log('nodeTypes', nodeTypes);
    assert(nodeTypes.length === 6, 'nodeTypes.length should be equal to 6');
    assert(nodeTypes[0].nodeTypeName === 'Axe', 'Axe name');
    assert(nodeTypes[5].nodeTypeName === 'Balana', 'Balana name');

    // return;

    // /////////////// change NodeTypes and retrieve them to check ///////////////
    // if you want to not change any property, pass 0 or an empty string
    // tx = await rewardManager.changeNodeType('Balana', 100, 1, 100, 10, "", 0);
    // await tx.wait();
    // nodeTypes = parseNodeTypes(await rewardManager.getNodeTypes());
    // console.log('nodeTypes', nodeTypes);
    // expect(nodeTypes.length).to.equal(6);
    // expect(nodeTypes[5].nodeTypeName).to.equal('Balana');
    // expect(nodeTypes[5].nodePrice).to.equal('100');
    // expect(nodeTypes[5].claimTime).to.equal('1');
    // expect(nodeTypes[5].rewardAmount).to.equal('100');
    // expect(nodeTypes[5].claimTaxBeforeTime).to.equal('10');


    // /////////////// create new nodes ///////////////
    // tx = await rewardManager.createNode(addrs[0].address, 'Axe', 10);
    // await tx.wait();
    // tx = await rewardManager.createNode(addrs[1].address, 'Sladar', 20);
    // await tx.wait();
    // tx = await rewardManager.createNode(addrs[1].address, 'Naix', 10);
    // await tx.wait();
    // tx = await rewardManager.createNode(addrs[4].address, 'Sven', 10);
    // await tx.wait();
    // tx = await rewardManager.createNode(addrs[4].address, 'Rikimaru', 10);
    // await tx.wait();
    // tx = await rewardManager.createNode(addrs[5].address, 'Balana', 10);
    // await tx.wait();

    // let nodeOwners;
    nodeOwners = parseString(await rewardManager.getNodeOwners());
    console.log('nodeOwners', nodeOwners);
    // assert(nodeOwners.length === 3, "nodeOwners.length === 3");
    // assert(nodeOwners[0][1] === '0', "nodeOwners[0][1] === 0");
    // // console.log(addrs[3].address);
    // // console.log(addrs[4].address);
    // // console.log(addrs[5].address);
    // // console.log('------', await rewardManager.getNodeOwners());

    let nodes;
    nodes = parseString(await rewardManager.getNodes(addrs[0].address));
    console.log('nodes', nodes);
    nodes = parseString(await rewardManager.getNodes(addrs[1].address));
    console.log('nodes', nodes);
    // assert(nodes.length === 40, "nodes.length === 40");
    // assert(nodes[10][0] === 'Sladar', "nodes[10][0] === 'Sladar'");

    let leftTime;
    leftTime = await rewardManager.getLeftTimeFromReward(addrs[1].address, nodes[0][1]);
    console.log('leftTime', leftTime);

    // claim reward after enough sleep
    await sleep(7000);
    tx = await rewardManager.claimReward(addrs[1].address, nodes[0][1]);
    await tx.wait();

    let deposit;
    deposit = await rewardManager.getDepositAmount(addrs[1].address);
    console.log('deposit', deposit);


    // claim reward before claim time
    tx = await rewardManager.claimReward(addrs[1].address, nodes[0][1]);
    await tx.wait();

    deposit = await rewardManager.getDepositAmount(addrs[1].address);
    console.log('deposit', deposit);

    // // cashout and check deposit
    tx = await rewardManager.cashOut(addrs[1].address);
    await tx.wait();

    deposit = await rewardManager.getDepositAmount(addrs[1].address);
    console.log('after cashOut - deposit', deposit);


    // levelUp
    tx = await rewardManager.levelUpNodes(addrs[1].address, 'Sladar');
    await tx.wait();
    nodes = parseString(await rewardManager.getNodes(addrs[1].address));
    console.log('nodes', nodes);
    // console.log('nodes.length', nodes.length);
    // assert(nodes.length === 36, "nodes.length === 36");

    tx = await rewardManager.levelUpNodes(addrs[1].address, 'Naix');
    await tx.wait();
    nodes = parseString(await rewardManager.getNodes(addrs[1].address));
    console.log('nodes', nodes);
    // console.log('nodes.length', nodes.length);

    // assert(nodes.length === 32, "nodes.length === 32");
  });
});
