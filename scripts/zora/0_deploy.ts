// scripts/base-mainnet/deploy-vivi-zora-multihop.ts

import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs
  const chainName = "base-mainnet"; // puedes ajustar el nombre que desees
  const feeReceiver = "0x31A57F2e2A5c293dE03AF73d0048aFd4F4f1Cde7";
  const uniswapRouterv3 = "0x2626664c2603336E57B271c5C0b26F421741e481";
  const WETH = "0x4200000000000000000000000000000000000006";
  const USDC = "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913";
  const ZORA = "0x1111111111166b7FE7bd91427724B487980aFc69";

  console.log("Starting deployment of VIVIZoraMultiHop...");
  console.log("Chain:", chainName);
  console.log("Fee Receiver:", feeReceiver);
  console.log("Uniswap V3 Router:", uniswapRouterv3);
  console.log("WETH:", WETH);
  console.log("USDC:", USDC);
  console.log("ZORA:", ZORA);

  // 2. Obtener la factoría del contrato VIVIZoraMultiHop
  const VIVIZoraMultiHop = await ethers.getContractFactory("VIVIZoraMultiHop");

  // 3. Desplegar
  console.log("Deploying contract...");
  const contract = await VIVIZoraMultiHop.deploy(
    uniswapRouterv3,
    feeReceiver,
    WETH,
    USDC,
    ZORA
  );

  await contract.deployed();

  console.log("VIVIZoraMultiHop deployed to:", contract.address);

  // 4. Verificar que las rutas están correctamente configuradas
  console.log("\nVerifying contract configuration...");

  const deployedFeeReceiver = await contract.feeReceiver();
  const deployedRouter = await contract.uniswapRouter();
  const deployedWETH = await contract.WETH();
  const deployedUSDC = await contract.USDC();
  const deployedZORA = await contract.ZORA();

  console.log("✓ Fee Receiver:", deployedFeeReceiver);
  console.log("✓ Uniswap Router:", deployedRouter);
  console.log("✓ WETH:", deployedWETH);
  console.log("✓ USDC:", deployedUSDC);
  console.log("✓ ZORA:", deployedZORA);

  // 5. Preparar datos para el archivo de salida
  const outputData = {
    contractName: "VIVIZoraMultiHop",
    chain: chainName,
    address: contract.address,
    deployer: (await ethers.getSigners())[0].address,
    deploymentTimestamp: new Date().toISOString(),
    configuration: {
      feeReceiver,
      uniswapRouterv3,
      WETH,
      USDC,
      ZORA,
    },
    routes: {
      buy: "ETH → USDC → ZORA → TOKEN",
      sell: "TOKEN → ZORA → USDC → ETH",
    },
    fees: {
      ethUsdc: 500, // 0.05%
      usdcZora: 3000, // 0.3%
      zoraToken: 10000, // 1%
    },
    maxFeeBps: 100, // 1%
  };

  // 6. Guardar en un archivo JSON
  const deploymentsDir = path.join(__dirname, "./deployments");
  // Ajusta la ruta según tu estructura de directorios
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const outFile = path.join(
    deploymentsDir,
    `deploy-VIVIZoraMultiHop-${chainName}.json`
  );

  fs.writeFileSync(outFile, JSON.stringify(outputData, null, 2), "utf-8");

  console.log(`\nDeployment info saved to ${outFile}`);

  // 7. Mostrar resumen final
  console.log("\n=== DEPLOYMENT SUMMARY ===");
  console.log(`Contract: VIVIZoraMultiHop`);
  console.log(`Address: ${contract.address}`);
  console.log(`Network: ${chainName}`);
  console.log(`Transaction hash: ${contract.deployTransaction.hash}`);
  console.log(`Gas used: ${contract.deployTransaction.gasLimit?.toString()}`);
  console.log("\n=== MULTI-HOP ROUTES ===");
  console.log("Buy:  ETH → USDC (0.05%) → ZORA (0.3%) → TOKEN (1%)");
  console.log("Sell: TOKEN → ZORA (1%) → USDC (0.3%) → ETH (0.05%)");
  console.log("\n✅ Deployment completed successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
