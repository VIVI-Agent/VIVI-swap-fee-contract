import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import axios from "axios";
import dotenv from "dotenv";
dotenv.config();

// Read environment variables
const VIVI_APESTORE_ADDRESS = process.env.VIVI_APESTORE_CONTRACT!;
const TOKEN = "0xad2ef018d8252b61940b3363b23ff166f60d9fed"; // Token to SELL

if (!VIVI_APESTORE_ADDRESS) {
  throw new Error("Missing required environment variables");
}

// Constants
const CHAIN_ID = 8453; // Base Chain ID
const FEE_BPS = 100; // 1% fee
const MIN_OUT = 0; // Minimum ETH to receive (0 = no minimum)
const PERCENTAGE_TO_SELL = 100; // Percentage of token balance to sell (100 = entire balance)

async function getTokenId(token: string): Promise<number> {
  const url = `https://api.ape.store/token/${CHAIN_ID}/${token}`;
  const headers = {
    Authorization: `Bearer ${process.env.APESTORE_API_KEY}`,
  };
  const res = await axios.get(url, { headers });
  return res.data.id;
}

async function getSignature(
  tokenId: number,
  wrapper: string,
  amount: string
): Promise<string> {
  const res = await axios.post(
    `https://api.ape.store/transaction`,
    {
      tokenId,
      address: wrapper,
      amount,
    },
    {
      headers: {
        Authorization: `Bearer ${process.env.APESTORE_API_KEY}`,
      },
    }
  );
  return res.data;
}

async function main() {
  const [signer] = await ethers.getSigners();
  console.log(`Using signer address: ${signer.address}`);
  console.log(`Using VIVIApeStore contract: ${VIVI_APESTORE_ADDRESS}`);

  // Get contract instance
  const contract = await ethers.getContractAt(
    "VIVIApeStore",
    VIVI_APESTORE_ADDRESS,
    signer
  );

  // Get token contract
  const tokenContract = await ethers.getContractAt(
    [
      "function balanceOf(address) view returns (uint256)",
      "function allowance(address,address) view returns (uint256)",
      "function symbol() view returns (string)",
      "function decimals() view returns (uint8)",
    ],
    TOKEN,
    signer
  );

  // Get token info
  const symbol = await tokenContract.symbol();
  const decimals = await tokenContract.decimals();

  // Get token balance and calculate sell amount
  const balance = await tokenContract.balanceOf(signer.address);

  if (balance.eq(0)) {
    console.error("You don't have any tokens to sell!");
    return;
  }

  const sellAmount = balance.mul(PERCENTAGE_TO_SELL).div(100);

  console.log(
    `Your ${symbol} balance: ${ethers.utils.formatUnits(balance, decimals)}`
  );
  console.log(
    `Amount to sell: ${ethers.utils.formatUnits(
      sellAmount,
      decimals
    )} ${symbol} (${PERCENTAGE_TO_SELL}% of balance)`
  );

  // Check allowance
  const allowance = await tokenContract.allowance(
    signer.address,
    VIVI_APESTORE_ADDRESS
  );

  if (allowance.lt(sellAmount)) {
    console.error(
      "Insufficient allowance. Please run the approval script first!"
    );
    console.log(
      `Current allowance: ${ethers.utils.formatUnits(
        allowance,
        decimals
      )} ${symbol}`
    );
    console.log(
      `Required: ${ethers.utils.formatUnits(sellAmount, decimals)} ${symbol}`
    );
    return;
  }

  // Get signature from ApeStore API
  console.log(`Getting token ID and signature for token: ${TOKEN}`);
  const tokenId = await getTokenId(TOKEN);
  console.log(`Token ID: ${tokenId}`);

  const signature = await getSignature(
    tokenId,
    VIVI_APESTORE_ADDRESS,
    sellAmount.toString()
  );
  console.log(`Signature obtained: ${signature.substring(0, 20)}...`);

  // Create the SellParams object that matches the contract struct
  const sellParams = {
    token: TOKEN,
    amount: sellAmount,
    minOut: MIN_OUT,
    signature: signature,
    recipient: signer.address, // ETH will be sent back to the signer
  };

  console.log(
    `Executing sell of ${ethers.utils.formatUnits(
      sellAmount,
      decimals
    )} ${symbol}...`
  );
  console.log(`Fee BPS: ${FEE_BPS} (${FEE_BPS / 100}%)`);

  // Call the VIVISell function with the correct parameters
  const tx = await contract.VIVISell(sellParams, FEE_BPS, {
    gasLimit: 1000000, // Set appropriate gas limit
  });

  console.log(`Transaction submitted with hash: ${tx.hash}`);

  // Wait for the transaction to be confirmed
  console.log("Waiting for transaction confirmation...");
  const receipt = await tx.wait();

  console.log(`✅ Sell transaction confirmed in block: ${receipt.blockNumber}`);
  console.log(`Gas used: ${receipt.gasUsed.toString()}`);

  // Try to extract any event logs
  if (receipt.events && receipt.events.length > 0) {
    try {
      interface SellEventArgs {
        user: string;
        token: string;
        tokensIn: BigNumber;
        ethOut: BigNumber;
        ethOutAfterFee: BigNumber;
        feeAmount: BigNumber;
      }

      interface SellEvent {
        event?: string;
        args?: SellEventArgs;
        [key: string]: any;
      }

      const sellEvent: SellEvent | undefined = receipt.events.find(
        (event: SellEvent) => event.event === "Sell"
      );

      if (sellEvent && sellEvent.args) {
        console.log("Sell event details:");
        console.log(`- User: ${sellEvent.args.user}`);
        console.log(`- Token: ${sellEvent.args.token}`);
        console.log(
          `- Tokens Sold: ${ethers.utils.formatUnits(
            sellEvent.args.tokensIn,
            decimals
          )} ${symbol}`
        );
        console.log(
          `- ETH Received (before fee): ${ethers.utils.formatEther(
            sellEvent.args.ethOut
          )} ETH`
        );
        console.log(
          `- ETH Received (after fee): ${ethers.utils.formatEther(
            sellEvent.args.ethOutAfterFee
          )} ETH`
        );
        console.log(
          `- Fee Amount: ${ethers.utils.formatEther(
            sellEvent.args.feeAmount
          )} ETH`
        );
      }
    } catch (error) {
      if (error instanceof Error) {
        console.log("Could not parse event logs:", error.message);
      } else {
        console.log("Could not parse event logs:", error);
      }
    }
  }

  // Show final token balance
  const newBalance = await tokenContract.balanceOf(signer.address);
  console.log(
    `\nYour new ${symbol} balance: ${ethers.utils.formatUnits(
      newBalance,
      decimals
    )}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Error executing sell:", err);
    process.exit(1);
  });
