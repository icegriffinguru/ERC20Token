const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const fs = require("fs");

const replaceInAddressFile = async (searchPattern, newLine) => {
  const addressFilePath = "./test/utils/address.js";
  const origin = fs.readFileSync(addressFilePath, "utf8");
  const changed = origin.replace(searchPattern, newLine);
  fs.writeFileSync(addressFilePath, changed);
}

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
  let owner, addrs;
  let polarNodes;
  let signer;

  beforeEach(async function () {
    this.timeout(1000000); // 1000 seconds timeout for setup


    [owner, ...addrs] = await ethers.getSigners();
    // console.log('Count:', addrs.length)
    // addrs.map(v => {
    //   console.log('address', v.address);
    // })
    

    const IterableMapping = await ethers.getContractFactory("IterableMapping");
    iterableMapping = await IterableMapping.deploy();
    replaceInAddressFile(/const IterableMapping(.*);/g, "const IterableMapping = \"" + iterableMapping.address + "\";");
    console.log('IterableMapping deployed at ', iterableMapping.address);

    const IterableNodeTypeMapping = await ethers.getContractFactory("IterableNodeTypeMapping");
    iterableNodeTypeMapping = await IterableNodeTypeMapping.deploy();
    replaceInAddressFile(/const IterableNodeTypeMapping(.*);/g, "const IterableNodeTypeMapping = \"" + iterableNodeTypeMapping.address + "\";");
    console.log('IterableNodeTypeMapping deployed at ', iterableNodeTypeMapping.address);

    // const OldNodeRewardManagement = await ethers.getContractFactory("OldNodeRewardManagement", {
    //   libraries: {
    //     IterableMapping: iterableMapping.address,
    //   },
    // });
    // const oldNodeRewardManagement = await OldNodeRewardManagement.deploy(
    //   10, 10, 10
    // );
    // console.log('OldNodeRewardManagement deployed at ', oldNodeRewardManagement.address);

    const PolarNodes = await ethers.getContractFactory("PolarNodes", owner);

    const NODERewardManagement = await ethers.getContractFactory("NODERewardManagement",
      {
        libraries: {
          IterableMapping: iterableMapping.address,
          IterableNodeTypeMapping: iterableNodeTypeMapping.address,
        },
      },
      owner
    );

    const oldNodeRewardManager = '0x6A50D15619f68739A77C01859642d77809992E8e';
    // const token = '0x18711b34d5f72b837848abd8be33a5be08fa7923';
    const token = '0x6c1c0319d8ddcb0ffe1a68c5b3829fd361587db4';
    const payees = [
      "0xfB7e9E883629eb0D4691D4Dc240b9c57A38888B4", // salty payees wallet
      "0xc1E6e63BbF402D3Ba812784D9E1b692130Ac61bA", // enor
      "0xaDC2cdCEcD0d45033acc62788670C55D45764d24", // 1Frey payess wallet
    ];
    const shares = [45, 45, 10];
    const addresses = [
      "0x24C835D252Dd8FA19242b7b74A094385f14Beb0f", // supply 
      "0xf128b6Ba7db8532Fa1d98BF2C31fC843B2882605", // futurUsePool 
      "0xAB3b24BA4c5911366C59cC870FAcC25B6ea3a053", // distributionPool 
      "0x15B72F2F0cd37fAde6c734E72485dE0909B1e2A8", // lp pool provider
      "0xfB7e9E883629eb0D4691D4Dc240b9c57A38888B4", // salty payees wallet
      "0xc1E6e63BbF402D3Ba812784D9E1b692130Ac61bA", // enor
      "0xaDC2cdCEcD0d45033acc62788670C55D45764d24", // 1Frey payess wallet
      owner.address
    ];
    const balances = [
      1, // supply
      1, // futurUsePool
      900000, // distributionPool
      10000, // liquidityPool creation
      26666,
      26666,
      26666,
      10000
    ];
    const fees = [
      // totalFee = rewardsFee + liquidityPoolFee + futurFee
      10, // futurFee (Node creation: contract balance perc sent to futurUsePool) avax
      60, // rewardsFee (Node creation: contract balance perc to calc rewardsPoolTokens)
      10, // liquidityPoolFee (Node creation: contract balance perc to add lp liquidity) avax/tokens
      10, // cashoutFee (cashout: reward amount perc sent to futurUsePool) avax
      1 // rwSwap (Node creation: rewardsPoolTokens perc sent to distributionPool) avax
      // (rewardsPoolTokens - (rwSwap calc) sent to distributionPool) tokens
    ];
    const swapAmount = 50;
    const uniV2Router = '0x60ae616a2155ee3d9a68541ba4544862310933d4';

    polarNodes = await PolarNodes.deploy(
      payees,
      shares,
      addresses,
      balances,
      fees,
      swapAmount,
      uniV2Router,
    );
    console.log('PolarNodes deployed at ', polarNodes.address);

    rewardManager = await NODERewardManagement.deploy(
      oldNodeRewardManager,
      polarNodes.address,
      // token,
      payees,
      shares,
      addresses,
      fees,
      swapAmount,
      uniV2Router,
    );
    replaceInAddressFile(/const NODERewardManagement(.*);/g, "const NODERewardManagement = \"" + rewardManager.address + "\";");
    console.log('NODERewardManagement deployed at ', rewardManager.address);
  });

  it("All tests", async function () {
    this.timeout(1000000) // 10 second timeout for setup

    let tx, result, nodes;
    result = await rewardManager.getNodeTypes();
    console.log('getNodeTypes:', result);

    tx = await rewardManager.addNodeType('Axe', 10, 10, 1000, 10);
    await tx.wait();
    tx = await rewardManager.addNodeType('Sladar', 30, 20, 3000, 20);
    await tx.wait();
    tx = await rewardManager.addNodeType('Naix', 60, 30, 6000, 30);
    await tx.wait();
    tx = await rewardManager.addNodeType('Sven', 50, 40, 5000, 40);
    await tx.wait();
    tx = await rewardManager.addNodeType('Rikimaru', 60, 50, 6000, 50);
    await tx.wait();
    tx = await rewardManager.addNodeType('Balana', 70, 60, 7000, 60);
    await tx.wait();

    result = await rewardManager.getNodeTypes();
    console.log('getNodeTypes:', result);

    tx = await rewardManager.changeNodeType('Balana', 100, 1, 100, 10);
    await tx.wait();
    result = await rewardManager.getNodeTypes();
    console.log('getNodeTypes', result);

    result = await polarNodes.balanceOf(owner.address);
    console.log('polarNodes.balanceOf', result);

    result = await rewardManager.setDefaultNodeTypeName("Axe");

    console.log('owner', owner.address);
    tx = await rewardManager.createNodeWithTokens('Axe', 10);
    await tx.wait();
    tx = await rewardManager.createNodeWithTokens('Sladar', 20);
    await tx.wait();
    // await rewardManager.createNodeWithDeposit('Axe', 10);
    // await tx.wait();
    // tx = await rewardManager.createNodeWithDeposit('Sladar', 20);
    // await tx.wait();

    result = await rewardManager.getNodeOwners(0, 100);
    console.log('getNodeOwners', result);

    result = await rewardManager.getNodes(owner.address, 0, 100);
    console.log('getNodes', result);
    nodes = parseString(result.substring(1));
    console.log('nodes', nodes);

    result = await rewardManager.getLeftTimeFromReward(owner.address, nodes[0][1]);
    console.log('getLeftTimeFromReward', result);

    // claim reward after enough sleep
    await sleep(7000);
    tx = await rewardManager.cashoutReward(nodes[0][1]);
    await tx.wait();

    tx = await rewardManager.levelUpNodes('Axe', 'Sladar');
    await tx.wait();

    result = await rewardManager.getNodes(owner.address, 0, 100);
    console.log('getNodes', result);
    nodes = parseString(result.substring(1));
    console.log('nodes', nodes);
  });
});
