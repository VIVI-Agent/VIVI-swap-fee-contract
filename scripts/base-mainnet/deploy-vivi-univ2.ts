// scripts/base-mainnet/deploy-vivi-univ2.ts
import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs
  const chainName = "base-mainnet";
  const feeReceiver = "0x31A57F2e2A5c293dE03AF73d0048aFd4F4f1Cde7";
  const uniswapRouter = "0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24";

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

  const deploymentsDir = path.join(__dirname, "./deployments");
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
