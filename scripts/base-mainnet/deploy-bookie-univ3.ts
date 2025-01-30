// scripts/base-sepolia/deploy-bookie-univ3.ts

import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs
  const chainName = "base-mainnet"; // puedes ajustar el nombre que desees
  const feeReceiver = "0xf59E87c6B05d047aED4941ff00dD841BD0874D7f";
  const uniswapRouterv3 = "0x2626664c2603336E57B271c5C0b26F421741e481";
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
  const deploymentsDir = path.join(__dirname, "../../deployments/mainnet");
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
