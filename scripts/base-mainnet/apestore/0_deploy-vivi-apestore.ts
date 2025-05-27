// scripts/base-mainnet/deploy-vivi-univ2.ts
import { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

async function main() {
  // 1. Config - inputs
  const chainName = "base-mainnet";

  // Get router and fee receiver from environment variables
  const apestoreRouter = process.env.APESTORE_ROUTER_ADDRESS;
  const feeReceiver = process.env.FEE_RECEIVER_ADDRESS;

  // Validate environment variables
  if (!apestoreRouter)
    throw new Error("APESTORE_ROUTER_ADDRESS not set in .env");
  if (!feeReceiver) throw new Error("FEE_RECEIVER_ADDRESS not set in .env");

  console.log(`Using ApeStore Router: ${apestoreRouter}`);
  console.log(`Using Fee Receiver: ${feeReceiver}`);

  // 2. Obtener la factoría del contrato
  const VIVIApestore = await ethers.getContractFactory("VIVIApeStore"); // Fixed contract name case

  // 3. Desplegar - pass both constructor parameters
  const contract = await VIVIApestore.deploy(apestoreRouter, feeReceiver);
  await contract.deployed();

  console.log("VIVIApeStore deployed to:", contract.address);

  // 4. Generar el objeto con info
  const outputData = {
    contractName: "VIVIApeStore",
    chain: chainName,
    address: contract.address,
    feeReceiver,
    apestoreRouter,
  };

  const deploymentsDir = path.join(__dirname, "./deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const outFile = path.join(
    deploymentsDir,
    `deploy-VIVIApeStore-${chainName}.json`
  );

  fs.writeFileSync(outFile, JSON.stringify(outputData, null, 2));

  console.log(`Deployment info saved to ${outFile}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
