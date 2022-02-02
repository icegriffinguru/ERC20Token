// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

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

  rewardManager = await NODERewardManagement.deploy(
      '0x4525b612f620e48Fd81635dF9dA7ddA2588dB8bc',
      '0x57E23C41f924eC16c6217E642Cb738Fe0b1fa370',
  );
  await rewardManager.deployed();

  console.log("IterableMapping deployed to:", iterableMapping.address);
  console.log("IterableNodeTypeMapping deployed to:", iterableNodeTypeMapping.address);
  console.log("NODERewardManagement deployed to:", rewardManager.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
