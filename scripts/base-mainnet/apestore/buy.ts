// scripts/testApeStoreBuy.ts
import { ethers } from "hardhat";
import axios from "axios";
import dotenv from "dotenv";
dotenv.config();

const WRAPPER_ADDRESS = process.env.APESTORE_WRAPPER!; // tu contrato desplegado
const TOKEN = "0xad2ef018d8252b61940b3363b23ff166f60d9fed";
const CHAIN_ID = 8453;
const TOTAL_ETH = ethers.utils.parseEther("0.0001");

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
  const contract = await ethers.getContractAt(
    "ApeStoreWrapper",
    WRAPPER_ADDRESS,
    signer
  );

  const ethForRouter = TOTAL_ETH;

  console.log("Getting token ID and signature...");
  const tokenId = await getTokenId(TOKEN);
  const signature = await getSignature(
    tokenId,
    WRAPPER_ADDRESS,
    ethForRouter.toString()
  );

  console.log("Executing buy...");
  const tx = await contract.executeBuy(TOKEN, ethForRouter, 0, signature, {
    value: TOTAL_ETH,
  });

  console.log("TX Hash:", tx.hash);
  const receipt = await tx.wait();
  console.log("✅ Buy confirmed in block:", receipt.blockNumber);
}

main().catch((err) => {
  console.error("❌ Error executing buy:", err);
  process.exit(1);
});
