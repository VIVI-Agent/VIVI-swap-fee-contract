Below is a **sample README** in English that provides an overview of your **FeeSwapWrapper** contract, deployment instructions using Hardhat, and additional notes. Feel free to modify any details to match your exact setup.

---

# bookie-swap-fee-contract

This repository contains a **Hardhat** project for deploying and interacting with a specialized Uniswap V2 wrapper contract, **FeeSwapWrapper**, that charges a small fee (in ETH) on swaps. The contract supports **tokens with fee on transfer** by leveraging Uniswap’s `*_SupportingFeeOnTransferTokens` functions.

---

## 1. Overview

- **Contract**: [FeeSwapWrapper.sol](./contracts/FeeSwapWrapper.sol)
- **Purpose**:
  1. Perform swaps on Uniswap V2 (e.g., Base Sepolia, Base Mainnet)
  2. Charge a small fee (in ETH)
  3. Handle “deflationary” tokens (fee on transfer) gracefully
- **Tech Stack**:
  - [Hardhat](https://hardhat.org/) for compilation, testing, and deployment
  - [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) for `Ownable` and `ReentrancyGuard`
  - [Uniswap V2 Periphery](https://github.com/Uniswap/v2-periphery) for router interfaces
  - [Ethers.js](https://docs.ethers.io/) for interacting with the contract
- **Networks**:
  - [Base Sepolia](https://sepolia.base.org/) for testing.
  - [Base Mainnet](https://base.org/) for production.

---

## 2. Project Structure

```
├── contracts
│   └── FeeSwapWrapper.sol        # Main contract
├── scripts
│   └── deploy.ts                 # Example deploy script
├── package.json
├── hardhat.config.ts (or .js)
└── README.md
```

Key files and folders:

- **contracts/FeeSwapWrapper.sol**: The core contract code.
- **scripts/deploy.ts**: Sample Hardhat script to deploy the contract.
- **hardhat.config.ts**: Configuration for Hardhat tasks, networks, plugins, etc.

---

## 3. Installation & Setup

1. **Clone** this repository:

2. **Install dependencies**:

Use of yarn is requiered.

```bash
yarn
```

3. **Configure Hardhat**:

   In `hardhat.config.ts` (or `.js`), set up any custom networks for **Base Sepolia** or **Base Mainnet**. Example:

   ```ts
   networks: {
     "base-sepolia": {
       url: "https://sepolia.base.org", // or your custom RPC
       accounts: [PRIVATE_KEY]
     },
     "base-mainnet": {
       url: "https://mainnet.base.org", // or your custom RPC
       accounts: [PRIVATE_KEY]
     },
     // ...
   },
   ```

   > **Note**: Store your `PRIVATE_KEY` in a `.env` or secrets manager, not in the repo.

---

## 4. The FeeSwapWrapper Contract

### Key Features

1. **Fee in ETH**

   - The contract charges a small fee (up to 1%) in ETH.
   - Fee is sent to `feeReceiver`, configurable by the owner.

2. **SwapTokensForETHWithFee**

   - Uses `swapExactTokensForETHSupportingFeeOnTransferTokens`.
   - Calculates real amount of tokens received, then does the swap.
   - Deducts ETH fee before sending the remainder to the recipient.

3. **SwapETHForTokensWithFee**

   - Swaps ETH → tokens (also supporting fee on transfer for tokens).
   - Takes an ETH fee upfront.

4. **Upgradable Router**

   - You can call `setRouter` (onlyOwner) if you want to switch the router in the future.

5. **Ownable**
   - Uses OpenZeppelin’s `Ownable` to secure admin functions.
   - The constructor sets the `owner` to the deployer by default.

### Deployment Parameters

- **`_router`**: Address of Uniswap V2 Router on the chosen network (e.g., Base Sepolia).
- **`_feeReceiver`**: Address that will receive the ETH fees.

### Events

- `SwapTokensForETH(sender, tokenIn, amountIn, ethReceived, ethAfterFee, feeAmount)`
- `SwapETHForTokens(sender, tokenOut, ethIn, tokensReceived, feeAmount)`
- `FeeReceiverUpdated(newFeeReceiver)`
- `RouterUpdated(newRouter)`

---

## 5. Deployment

**Example**: [scripts/deploy.ts](./scripts/deploy.ts)

```ts
import { ethers } from "hardhat";

async function main() {
  const feeReceiver = "0xf59E87c6B05d047aED4941ff00dD841BD0874D7f";
  const uniswapRouter = "0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24"; // Router on Base Sepolia

  // 1) Compile & get contract factory
  const FeeSwapWrapper = await ethers.getContractFactory("FeeSwapWrapper");

  // 2) Deploy with constructor args
  const contract = await FeeSwapWrapper.deploy(uniswapRouter, feeReceiver);
  await contract.deployed();

  console.log("FeeSwapWrapper deployed to:", contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

### How to Run

```bash
# Deploy to Base Sepolia
npx hardhat run scripts/deploy.ts --network base-sepolia

# Deploy to Base Mainnet (assuming config in hardhat.config)
npx hardhat run scripts/deploy.ts --network base-mainnet
```

After deployment, you’ll see something like:

```
FeeSwapWrapper deployed to: 0xYourContractAddress
```

Take note of the contract address.

---

## 6. Usage & Testing

1. **Interacting with the contract**:

   - Use `npx hardhat console --network base-sepolia` or similar.
   - Or integrate from a front-end or a script using Ethers.js or Viem.

2. **For local testing**:

   - You can run a Hardhat local node: `npx hardhat node`.
   - Deploy the contract to `localhost` then interact via scripts or console.

3. **Slippage & Fee**:

   - The contract enforces `feePercentage <= 1` (i.e., max 1%).
   - The `slippagePercent <= 50` is also a requirement.
   - If either fails, the transaction reverts.

4. **Deflationary Tokens**:
   - The contract calculates the real tokens transferred using `balanceOf` differences.
   - Uses `_SupportingFeeOnTransferTokens` router calls to handle fee-on-transfer tokens gracefully.

---

## 7. Example Hardhat Tasks

Hardhat provides built-in tasks and you can define more in `tasks/`. Some default commands:

```bash
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts --network base-sepolia
```

- **`npx hardhat help`** shows general help.
- **`npx hardhat test`** runs your tests (if created).
- **`npx hardhat node`** starts a local dev network.

---

## 8. Dependencies

> Relevant sections from [package.json](./package.json):

- **Hardhat**: `^2.22.16`
- **OpenZeppelin Contracts**: `^5.1.0`
- **@uniswap/v2-periphery**: `^1.1.0-beta.0`
- **ethers**: `^5.6.2`
- **TypeScript**: `^5.6.3` (if using TS)

Additional dev tools:

- **dotenv** for environment variables.
- **hardhat-gas-reporter** for analyzing gas usage.

---

## 9. Security Considerations

1. **FeeReceiver** has to be a trusted address.
2. **setRouter** can only be called by `owner`; ensure you trust the new router.
3. **Slippage**: Users set slippage up to 50%. If they incorrectly set it, the swap might revert or result in less favorable execution.
4. **Allowance** & **approvals**: The contract automatically approves the router for `type(uint256).max`; typical Uniswap pattern but be aware of unlimited approvals.

---

## 10. Contributing

1. **Clone this repo**
2. Create a new branch for your feature (`git checkout -b feature/my-update`).
3. **Commit** your changes, run tests if any.
4. **Open** a Pull Request.
