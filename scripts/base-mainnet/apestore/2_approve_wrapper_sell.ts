// scripts/approveViviApeStore.ts
import { ethers } from "hardhat";
import axios from "axios";
import dotenv from "dotenv";
import { BigNumber, BigNumberish, ContractTransaction } from "ethers";
dotenv.config();

// Read environment variables
const VIVI_APESTORE_ADDRESS = process.env.VIVI_APESTORE_CONTRACT!;
const TOKEN = "0xad2ef018d8252b61940b3363b23ff166f60d9fed"; // Token address to approve
const CHAIN_ID = 8453; // Base Chain ID

// Token amount to approve - approve maximum possible to avoid needing to approve again
const APPROVAL_AMOUNT = ethers.constants.MaxUint256;

// Import necessary interfaces
interface IERC20 {
  balanceOf(address: string): Promise<BigNumber>;
  allowance(owner: string, spender: string): Promise<BigNumber>;
  approve(spender: string, amount: BigNumberish): Promise<ContractTransaction>;
  symbol(): Promise<string>;
  decimals(): Promise<number>;
}

async function main() {
  const [signer] = await ethers.getSigners();
  console.log(`Using signer address: ${signer.address}`);
  console.log(`Using VIVIApeStore contract: ${VIVI_APESTORE_ADDRESS}`);
  console.log(`Token to approve: ${TOKEN}`);

  // Get token contract instance
  const tokenContract = (await ethers.getContractAt(
    [
      "function balanceOf(address) view returns (uint256)",
      "function allowance(address,address) view returns (uint256)",
      "function approve(address,uint256) returns (bool)",
      "function symbol() view returns (string)",
      "function decimals() view returns (uint8)",
    ],
    TOKEN,
    signer
  )) as unknown as IERC20;

  // Get token info
  const symbol = await tokenContract.symbol();
  const decimals = await tokenContract.decimals();

  // Get current balance
  const balance = await tokenContract.balanceOf(signer.address);
  console.log(
    `Your ${symbol} balance: ${ethers.utils.formatUnits(balance, decimals)}`
  );

  // Check current allowance
  const currentAllowance = await tokenContract.allowance(
    signer.address,
    VIVI_APESTORE_ADDRESS
  );

  console.log(
    `Current allowance for VIVIApeStore: ${ethers.utils.formatUnits(
      currentAllowance,
      decimals
    )} ${symbol}`
  );

  if (
    currentAllowance.gt(0) &&
    !currentAllowance.eq(ethers.constants.MaxUint256)
  ) {
    console.log(
      "You already have an allowance, but it's not infinite. Will approve max amount."
    );
  } else if (currentAllowance.eq(ethers.constants.MaxUint256)) {
    console.log(
      "You already have approved maximum amount. No need to approve again."
    );
    return;
  }

  // Execute approval transaction
  console.log(`Approving VIVIApeStore to spend your ${symbol}...`);
  const tx = await tokenContract.approve(
    VIVI_APESTORE_ADDRESS,
    APPROVAL_AMOUNT
  );

  console.log(`Approval transaction submitted: ${tx.hash}`);
  console.log(`Waiting for transaction confirmation...`);

  // Wait for confirmation
  const receipt = await tx.wait();
  console.log(`✅ Approval confirmed in block: ${receipt.blockNumber}`);
  console.log(`Gas used: ${receipt.gasUsed.toString()}`);

  // Verify the new allowance
  const newAllowance = await tokenContract.allowance(
    signer.address,
    VIVI_APESTORE_ADDRESS
  );

  console.log(
    `New allowance for VIVIApeStore: ${
      newAllowance.eq(ethers.constants.MaxUint256)
        ? "UNLIMITED"
        : ethers.utils.formatUnits(newAllowance, decimals)
    } ${symbol}`
  );

  console.log(
    "\n✅ Token approved! Now you can proceed with the sell operation."
  );
  console.log(
    "Next step: Run the sell script to sell your tokens through VIVIApeStore"
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Error executing token approval:", err);
    process.exit(1);
  });
