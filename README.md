# VIVI-contracts

This repository contains a **Hardhat** project for deploying and interacting with a specialized Uniswap V2, V3, Aerodrome wrapper contracts, that charges a small fee (in ETH) on swaps.

## 1. Overview

- **Tech Stack**:
  - [Hardhat](https://hardhat.org/) for compilation, testing, and deployment
  - [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) for `Ownable` and `ReentrancyGuard`
  - [Uniswap V2 Periphery](https://github.com/Uniswap/v2-periphery) for router interfaces
  - [Ethers.js](https://docs.ethers.io/) for interacting with the contract
- **Networks**:
  - [Base Sepolia](https://sepolia.base.org/) for testing.
  - [Base Mainnet](https://base.org/) for production.

## 2. Project Structure

```
.
├── contracts
│   ├── VIVIAerodrome.sol
│   ├── VIVIUniswapV2.sol
│   └── VIVIUniswapV3.sol
├── hardhat.config.ts
├── package.json
├── README.md
├── scripts
│   ├── base-mainnet
│   │   ├── deploy-vivi-aero.ts
│   │   ├── deploy-vivi-univ2.ts
│   │   └── deploy-vivi-univ3.ts
│   └── base-sepolia
│       ├── deploy-vivi-aero.ts
│       ├── deploy-vivi-univ2.ts
│       └── deploy-vivi-univ3.ts
```

## 3. Installation & Setup

1. **Clone** this repository:

2. **Install dependencies**:

Use of yarn is requiered.

```bash
yarn
```

## 4. How to Run

```bash

#######
SEPOLIA

npx hardhat run scripts/base-sepolia/deploy-vivi-aero.ts --network base-sepolia
npx hardhat run scripts/base-sepolia/deploy-vivi-univ2.ts --network base-sepolia
npx hardhat run scripts/base-sepolia/deploy-vivi-univ3.ts --network base-sepolia
#######

#######
MAINNET

npx hardhat run scripts/base-mainnet/deploy-vivi-aero.ts --network base-mainnet
npx hardhat run scripts/base-mainnet/deploy-vivi-univ2.ts --network base-mainnet
npx hardhat run scripts/base-mainnet/deploy-vivi-univ3.ts --network base-mainnet
#######
```

After deployment, you’ll see something like:

```
FeeSwapWrapper deployed to: 0xYourContractAddress
```

A _deployment_ folder in the scripts/base-mainnet or scripts/base-sepolia directory will be created with the deploment information to store each contract addresses in a separated file.

## 5. Example Hardhat Tasks

Hardhat provides built-in tasks and you can define more in `tasks/`. Some default commands:

```bash
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
```

- **`npx hardhat help`** shows general help.
- **`npx hardhat test`** runs your tests (if created).
- **`npx hardhat node`** starts a local dev network.

## 6. Dependencies

> Relevant sections from [package.json](./package.json):

- **Hardhat**: `^2.22.16`
- **OpenZeppelin Contracts**: `^5.1.0`
- **@uniswap/v2-periphery**: `^1.1.0-beta.0`
- **ethers**: `^5.6.2`
- **TypeScript**: `^5.6.3` (if using TS)

Additional dev tools:

- **dotenv** for environment variables.
- **hardhat-gas-reporter** for analyzing gas usage.
