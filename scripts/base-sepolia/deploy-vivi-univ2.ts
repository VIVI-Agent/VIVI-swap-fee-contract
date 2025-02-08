// scripts/base-sepolia/deploy-bookie-univ2.ts
import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs
  const chainName = "base-sepolia";
  const feeReceiver = "0x8Fd7a6a86EacFe6b159fd253f9de3895B8e1B72C";
  const uniswapRouter = "0x1689E7B1F10000AE47eBfE339a4f69dECd19F602";

  // 2. Obtener la factoría del contrato
  const VIVIUniswapV2 = await ethers.getContractFactory("VIVIUniswapV2");

  // 3. Desplegar
  const contract = await VIVIUniswapV2.deploy(uniswapRouter, feeReceiver);
  await contract.deployed();

  console.log("VIVIUniswapV2 deployed to:", contract.address);

  // 4. Generar el objeto con info
  const outputData = {
    contractName: "VIVIUniswapV2",
    chain: chainName,
    address: contract.address,
    feeReceiver,
    uniswapRouter,
  };

  const deploymentsDir = path.join(__dirname, "../../deployments/sepolia");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const outFile = path.join(
    deploymentsDir,
    `deploy-VIVIUniswapV2-${chainName}.json`
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
