// scripts/base-mainnet/deploy-vivi-univ2.ts
import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs
  const chainName = "base-mainnet";
  const feeReceiver = "0x5b2d81222EEc58Ce26779BdB043a828041Cf7420";
  const apestoreRouter = "0xc750af290bb41ca5dec04f22cd1318e940dd826a";

  // 2. Obtener la factoría del contrato
  const ApeStoreWrapper = await ethers.getContractFactory("ApeStoreWrapper");

  // 3. Desplegar
  const contract = await ApeStoreWrapper.deploy(apestoreRouter);
  await contract.deployed();

  console.log("ApeStoreWrapper deployed to:", contract.address);

  // 4. Generar el objeto con info
  const outputData = {
    contractName: "ApeStoreWrapper",
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
    `deploy-ApeStoreWrapper-${chainName}.json`
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
