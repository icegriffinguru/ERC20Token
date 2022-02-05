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
  let addrs;

  beforeEach(async function () {
    this.timeout(1000000) // 1000 seconds timeout for setup


    addrs = await ethers.getSigners();
    console.log('Count:', addrs.length)
    addrs.map(v => {
      console.log('address', v.address);
    })
    

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

    

    rewardManager = await NODERewardManagement.deploy();
    replaceInAddressFile(/const NODERewardManagement(.*);/g, "const NODERewardManagement = \"" + rewardManager.address + "\";");
    console.log('NODERewardManagement deployed at ', rewardManager.address);
  });

  it("All tests", async function () {
    this.timeout(1000000) // 10 second timeout for setup

    
  });
});
