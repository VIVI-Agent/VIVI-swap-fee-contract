// scripts/base-sepolia/deploy-bookie-univ3.ts

import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs
  const chainName = "base-sepolia"; // puedes ajustar el nombre que desees
  const feeReceiver = "0x8Fd7a6a86EacFe6b159fd253f9de3895B8e1B72C";
  const uniswapRouterv3 = "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4";
  const WETH = "0x4200000000000000000000000000000000000006";

  // 2. Obtener la factoría del contrato BookieSwapWrapperUniV3
  const BookieSwapWrapperUniV3 = await ethers.getContractFactory(
    "BookieSwapWrapperUniV3"
  );

  // 3. Desplegar
  const contract = await BookieSwapWrapperUniV3.deploy(
    uniswapRouterv3,
    feeReceiver,
    WETH
  );
  await contract.deployed();

  console.log("BookieSwapWrapperUniV3 deployed to:", contract.address);

  // 4. Preparar datos para el archivo de salida
  const outputData = {
    contractName: "BookieSwapWrapperUniV3",
    chain: chainName,
    address: contract.address,
    feeReceiver,
    uniswapRouterv3,
    WETH,
  };

  // 5. Guardar en un archivo JSON
  const deploymentsDir = path.join(__dirname, "../../deployments");
  // Ajusta la ruta según tu estructura de directorios
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const outFile = path.join(
    deploymentsDir,
    `deploy-BookieSwapWrapperUniV3-${chainName}.json`
  );

  fs.writeFileSync(outFile, JSON.stringify(outputData, null, 2), "utf-8");

  console.log(`Deployment info saved to ${outFile}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
