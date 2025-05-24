// scripts/testApeStoreBuy.ts
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import axios from "axios";
import dotenv from "dotenv";
dotenv.config();

// Read environment variables
const VIVI_APESTORE_ADDRESS = process.env.VIVI_APESTORE_CONTRACT!;
const APESTORE_ROUTER = process.env.APESTORE_ROUTER!;
const FEE_RECEIVER = process.env.FEE_RECEIVER!;

if (!VIVI_APESTORE_ADDRESS || !APESTORE_ROUTER || !FEE_RECEIVER) {
  throw new Error("Missing required environment variables");
}

// Constants
const TOKEN = "0xad2ef018d8252b61940b3363b23ff166f60d9fed"; // Token to buy
const CHAIN_ID = 8453; // Base Chain ID
const TOTAL_ETH = ethers.utils.parseEther("0.0001"); // Amount of ETH to spend
const FEE_BPS = 100; // 1% fee
const MIN_OUT = 0; // Minimum amount of tokens to receive (0 = no minimum)

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

  console.log(`Getting token ID and signature for token: ${TOKEN}`);
  const tokenId = await getTokenId(TOKEN);
  console.log(`Token ID: ${tokenId}`);

  // Get signature from ApeStore API
  const signature = await getSignature(
    tokenId,
    VIVI_APESTORE_ADDRESS,
    TOTAL_ETH.toString()
  );
  console.log(`Signature obtained: ${signature.substring(0, 20)}...`);

  // Create the BuyParams object that matches the contract struct
  const buyParams = {
    token: TOKEN,
    minOut: MIN_OUT,
    signature: signature,
    recipient: signer.address, // Tokens will be sent back to the signer
  };

  console.log(
    `Executing buy with ${ethers.utils.formatEther(TOTAL_ETH)} ETH...`
  );
  console.log(`Fee BPS: ${FEE_BPS} (${FEE_BPS / 100}%)`);

  // Call the VIVIBuy function with the correct parameters
  const tx = await contract.VIVIBuy(buyParams, FEE_BPS, {
    value: TOTAL_ETH,
    gasLimit: 1000000, // Set appropriate gas limit
  });

  console.log(`Transaction submitted with hash: ${tx.hash}`);

  // Wait for the transaction to be confirmed
  console.log("Waiting for transaction confirmation...");
  const receipt = await tx.wait();

  console.log(`✅ Buy transaction confirmed in block: ${receipt.blockNumber}`);
  console.log(`Gas used: ${receipt.gasUsed.toString()}`);

  // Try to extract any event logs
  if (receipt.events && receipt.events.length > 0) {
    try {
      interface BuyEventArgs {
        user: string;
        token: string;
        ethIn: BigNumber;
        ethInAfterFee: BigNumber;
        tokensOut: BigNumber;
        feeAmount: BigNumber;
      }

      interface BuyEvent {
        event?: string;
        args?: BuyEventArgs;
        [key: string]: any;
      }

      const buyEvent: BuyEvent | undefined = receipt.events.find(
        (event: BuyEvent) => event.event === "Buy"
      );
      if (buyEvent && buyEvent.args) {
        console.log("Buy event details:");
        console.log(`- User: ${buyEvent.args.user}`);
        console.log(`- Token: ${buyEvent.args.token}`);
        console.log(
          `- ETH In: ${ethers.utils.formatEther(buyEvent.args.ethIn)} ETH`
        );
        console.log(
          `- ETH After Fee: ${ethers.utils.formatEther(
            buyEvent.args.ethInAfterFee
          )} ETH`
        );
        console.log(`- Tokens Out: ${buyEvent.args.tokensOut.toString()}`);
        console.log(
          `- Fee Amount: ${ethers.utils.formatEther(
            buyEvent.args.feeAmount
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
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Error executing buy:", err);
    process.exit(1);
  });
