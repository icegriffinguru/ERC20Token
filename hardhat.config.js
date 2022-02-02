require("@nomiclabs/hardhat-waffle");
require("hardhat-abi-exporter");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */


module.exports = {
	solidity: {
		compilers: [
			{
				version: "0.8.0",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200,
					},
				},
			},
			{
				version: "0.8.2",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200,
					},
				},
			},
			{
				version: "0.6.2",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200,
					},
				},
			}
		],
	},
	abiExporter: {
		path: './abi',
		runOnCompile: true,
	},
	networks: {
	// 	hardhat : {
	// 		forking: {
	// 			url: "https://api.avax.network/ext/bc/C/rpc",
	// 			chainId: 31337,
	// 		},
	// 	},
	// 	avalanche : {
	// 		url: "https://api.avax.network/ext/bc/C/rpc",
	// 		chainId: 43114,
	// 	},
		avalanche_test: {
			url: 'https://api.avax-test.network/ext/bc/C/rpc',
			chainId: 43113,
			accounts: [
				`0x76831bab4ac6b6fe943c9308d71b5136afe81ea235ac51029821adb287a5b110`,
				'0x99da3c905068290de03eb6ec818b3ce3e316f25790f5e3da328a7b074402cb6a'
			],
			timeout: 100000,
		}
	},
	// defaultNetwork: 'avalanche',
};
