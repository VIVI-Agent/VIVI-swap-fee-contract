// scripts/virtuals/0_deploy.ts

import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs
  const chainName = "base-mainnet"; // puedes ajustar el nombre que desees
  const feeReceiver = "0x31A57F2e2A5c293dE03AF73d0048aFd4F4f1Cde7";
  const uniswapRouterv2 = "0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24"; // Uniswap V2 Router on Base
  const WETH = "0x4200000000000000000000000000000000000006";
  const VIRTUAL = "0x0b3e328455c4059eeb9e3f84b5543f74e24e7e1b";

  console.log("Starting deployment of VIVIVirtualsHop...");
  console.log("Chain:", chainName);
  console.log("Fee Receiver:", feeReceiver);
  console.log("Uniswap V2 Router:", uniswapRouterv2);
  console.log("WETH:", WETH);
  console.log("VIRTUAL:", VIRTUAL);

  // 2. Obtener la factoría del contrato VIVIVirtualsHop
  const VIVIVirtualsHop = await ethers.getContractFactory("VIVIVirtualsHop");

  // 3. Desplegar
  console.log("Deploying contract...");
  const contract = await VIVIVirtualsHop.deploy(
    uniswapRouterv2,
    feeReceiver,
    WETH,
    VIRTUAL
  );

  await contract.deployed();

  console.log("VIVIVirtualsHop deployed to:", contract.address);

  // 4. Verificar que las rutas están correctamente configuradas
  console.log("\nVerifying contract configuration...");

  const deployedFeeReceiver = await contract.feeReceiver();
  const deployedRouter = await contract.uniswapRouter();
  const deployedWETH = await contract.WETH();
  const deployedVIRTUAL = await contract.VIRTUAL();

  console.log("✓ Fee Receiver:", deployedFeeReceiver);
  console.log("✓ Uniswap Router:", deployedRouter);
  console.log("✓ WETH:", deployedWETH);
  console.log("✓ VIRTUAL:", deployedVIRTUAL);

  // 5. Preparar datos para el archivo de salida
  const outputData = {
    contractName: "VIVIVirtualsHop",
    chain: chainName,
    address: contract.address,
    deployer: (await ethers.getSigners())[0].address,
    deploymentTimestamp: new Date().toISOString(),
    configuration: {
      feeReceiver,
      uniswapRouterv2,
      WETH,
      VIRTUAL,
    },
    routes: {
      buy: "ETH → VIRTUAL → TOKEN",
      sell: "TOKEN → VIRTUAL → ETH",
    },
    fees: {
      protocolVersion: "UniswapV2",
      description: "Uses Uniswap V2 pool fees automatically",
    },
    maxFeeBps: 100, // 1%
    virtualPool: "0x9c087eb773291e50cf6c6a90ef0f4500e349b903", // VIRTUAL/WETH pool
  };

  // 6. Guardar en un archivo JSON
  const deploymentsDir = path.join(__dirname, "./deployments");
  // Ajusta la ruta según tu estructura de directorios
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const outFile = path.join(
    deploymentsDir,
    `deploy-VIVIVirtualsHop-${chainName}.json`
  );

  fs.writeFileSync(outFile, JSON.stringify(outputData, null, 2), "utf-8");

  console.log(`\nDeployment info saved to ${outFile}`);

  // 7. Mostrar resumen final
  console.log("\n=== DEPLOYMENT SUMMARY ===");
  console.log(`Contract: VIVIVirtualsHop`);
  console.log(`Address: ${contract.address}`);
  console.log(`Network: ${chainName}`);
  console.log(`Transaction hash: ${contract.deployTransaction.hash}`);
  console.log(`Gas used: ${contract.deployTransaction.gasLimit?.toString()}`);
  console.log("\n=== MULTI-HOP ROUTES ===");
  console.log("Buy:  ETH → VIRTUAL → TOKEN (Uniswap V2)");
  console.log("Sell: TOKEN → VIRTUAL → ETH (Uniswap V2)");
  console.log(`Pool: VIRTUAL/WETH at ${outputData.virtualPool}`);
  console.log("\n✅ Deployment completed successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
