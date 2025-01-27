// scripts/base-mainnet/deploy-bookie-aero.ts
import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs

  const chainName = "base-mainnet";
  const feeReceiver = "0xf59E87c6B05d047aED4941ff00dD841BD0874D7f"; // dirección que recibirá las fees
  const aeroRouter = "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43"; // dirección del router en base sepolia

  // 2. Obtener la factoría del contrato
  const BookieSwapWrapperAerodrome = await ethers.getContractFactory(
    "BookieSwapWrapperAerodrome"
  );

  // 3. Desplegar
  const contract = await BookieSwapWrapperAerodrome.deploy(
    aeroRouter,
    feeReceiver
  );
  await contract.deployed();

  console.log("BookieSwapWrapperAerodrome deployed to:", contract.address);

  // 4. Generar el objeto con info
  const outputData = {
    contractName: "BookieSwapWrapperAerodrome",
    chain: chainName,
    address: contract.address,
    feeReceiver,
    aeroRouter,
  };

  const deploymentsDir = path.join(__dirname, "../../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const outFile = path.join(
    deploymentsDir,
    `deploy-BookieSwapWrapperAerodrome-${chainName}.json`
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
