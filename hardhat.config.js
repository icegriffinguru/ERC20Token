require("@nomiclabs/hardhat-waffle");
require("hardhat-abi-exporter");
// require("hardhat-gas-reporter");
require('hardhat-contract-sizer');
require('dotenv').config()

const {
	ACCOUNT1,
	ACCOUNT2,
	ACCOUNT3,
	ACCOUNT4,
	ACCOUNT5,
	COINMARKETCAP_KEY,
} = process.env;

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
			// {
			// 	version: "0.8.0",
			// 	settings: {
			// 		optimizer: {
			// 			enabled: true,
			// 			runs: 200,
			// 		},
			// 	},
			// },
			{
				version: "0.8.2",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100,
					},
				},
			},
			// {
			// 	version: "0.6.2",
			// 	settings: {
			// 		optimizer: {
			// 			enabled: true,
			// 			runs: 200,
			// 		},
			// 	},
			// }
		],
	},
	// gasReporter: {
	// 	enabled: true,
	// 	currency: "USD",
	// 	gasPrice: 30,
	// 	coinmarketcap: COINMARKETCAP_KEY,
	// },
	abiExporter: {
		path: './abi',
		runOnCompile: true,
	},
	networks: {
		hardhat : {
			forking: {
				url: "https://api.avax.network/ext/bc/C/rpc",
				chainId: 31337,
				accounts: [
					ACCOUNT1,
					ACCOUNT2,
					ACCOUNT3,
					ACCOUNT4,
					ACCOUNT5,
				],
			},
		},
	// 	avalanche : {
	// 		url: "https://api.avax.network/ext/bc/C/rpc",
	// 		chainId: 43114,
	// 	},
		testnet: {	// Avalanche testnet
			url: 'https://api.avax-test.network/ext/bc/C/rpc',
			chainId: 43113,
			accounts: [
				ACCOUNT1,
				ACCOUNT2,
				ACCOUNT3,
				ACCOUNT4,
				ACCOUNT5,
			],
			timeout: 100000,
		}
	},
	// defaultNetwork: 'avalanche',
};
