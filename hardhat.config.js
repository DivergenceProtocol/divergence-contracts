require("@nomiclabs/hardhat-waffle");
require("hardhat-deploy");
// require("hardhat-docgen");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");
require('hardhat-abi-exporter');


const {
  mnemonic,
  projectId,
  etherscanKey
} = require("./secret.json")

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

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
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100
      }
    }
  },
  defaultNetwork: "ropsten",
  networks: {
    ropsten: {
      url: `https://ropsten.infura.io/v3/${projectId}`,
      accounts: {
        mnemonic: mnemonic,
      },
      gas: 40000000
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${projectId}`,
      gas: 12000000,
      accounts: {
        mnemonic: mnemonic,
      },
    }
  },
  // docgen: {
  //   path: './docs',
  //   clear: true,
  //   runOnCompile: true,
  // },
  namedAccounts: {
    deployer: {
      default: 0,
    }
  },
  etherscan: {
    apiKey: etherscanKey
  }
};