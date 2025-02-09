// scripts/base-sepolia/deploy-vivi-aero.ts
import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs

  const chainName = "base-sepolia";
  const feeReceiver = "0x8Fd7a6a86EacFe6b159fd253f9de3895B8e1B72C"; // dirección que recibirá las fees
  const uniswapRouter = "0x1689E7B1F10000AE47eBfE339a4f69dECd19F602"; // dirección del router en base sepolia, no aero este es univ2, solo para test deploy
  const WETH = "0x4200000000000000000000000000000000000006";

  // 2. Obtener la factoría del contrato
  const VIVIAerodrome = await ethers.getContractFactory("VIVIAerodrome");

  // 3. Desplegar
  const contract = await VIVIAerodrome.deploy(uniswapRouter, feeReceiver, WETH);
  await contract.deployed();

  console.log("VIVIAerodrome deployed to:", contract.address);

  // 4. Generar el objeto con info
  const outputData = {
    contractName: "VIVIAerodrome",
    chain: chainName,
    address: contract.address,
    feeReceiver,
    uniswapRouter,
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
