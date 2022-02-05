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

    const NODERewardManagement = await ethers.getContractFactory("NODERewardManagement", {
      libraries: {
        IterableMapping: iterableMapping.address,
        IterableNodeTypeMapping: iterableNodeTypeMapping.address,
      },
    });

    const oldNodeRewardManager = '0x4579d0d1d60ac7828419f44ccb846ae5cb2cf307';
    const token = '0xE7436564Fa2432dcA88bf325a44fAa4338fD10Ca';
    const payees = [addrs[0].address, addrs[1].address];
    const shares = [10, 90];
    const addresses = [
      '0x81893f85E46C6A506ef5EedC48507421234a4742',
      '0x7690704d17fAeaba62f6fc45E464F307763445de',
      '0xDCf130b430576C91B74467711aF4d1082dc746ad',
      '0x9328429372dB08D406A8953f6b4Bf9F6C86797aA',
    ];
    const fees = [3, 4, 5, 6, 7];
    const swapAmount = 1000;
    const uniV2Router = '0x0373d73622e3922A20d02236BF9c55B46891c068';

    rewardManager = await NODERewardManagement.deploy(
      oldNodeRewardManager,
      token,
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

    
  });
});
