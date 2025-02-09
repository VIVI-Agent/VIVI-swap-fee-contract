// scripts/base-mainnet/deploy-vivi-aero.ts
import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs

  const chainName = "base-mainnet";
  const feeReceiver = "0xf59E87c6B05d047aED4941ff00dD841BD0874D7f"; // dirección que recibirá las fees
  const aeroRouter = "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43"; // dirección del router en base sepolia
  const WETH = "0x4200000000000000000000000000000000000006";

  // 2. Obtener la factoría del contrato
  const VIVIAerodrome = await ethers.getContractFactory("VIVIAerodrome");

  // 3. Desplegar
  const contract = await VIVIAerodrome.deploy(aeroRouter, feeReceiver, WETH);
  await contract.deployed();

  console.log("VIVIAerodrome deployed to:", contract.address);

  // 4. Generar el objeto con info
  const outputData = {
    contractName: "VIVIAerodrome",
    chain: chainName,
    address: contract.address,
    feeReceiver,
    aeroRouter,
  };

  const deploymentsDir = path.join(__dirname, "./deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const outFile = path.join(
    deploymentsDir,
    `deploy-VIVIAerodrome-${chainName}.json`
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
