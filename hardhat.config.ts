import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";

dotenv.config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const BASESCAN_API_KEY = process.env.BASESCAN_API_KEY;

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true, // Habilita el IR
        },
      },
    ],
  },
  networks: {
    "base-mainnet": {
      url: "https://mainnet.base.org",
      accounts: [PRIVATE_KEY as string],
    },
    "base-sepolia": {
      url: "https://sepolia.base.org",
      accounts: [PRIVATE_KEY as string],
    },
  },
  gasReporter: {
    L2: "base",
    L1Etherscan: ETHERSCAN_API_KEY,
    L2Etherscan: BASESCAN_API_KEY,
    enabled: true,
    currency: "USD",
    coinmarketcap: COINMARKETCAP_API_KEY,
  },
};

export default config;
