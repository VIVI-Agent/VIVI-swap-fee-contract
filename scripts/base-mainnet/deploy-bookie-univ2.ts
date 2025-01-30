// scripts/base-mainnet/deploy-bookie-univ2.ts
import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Config - inputs
  const chainName = "base-mainnet";
  const feeReceiver = "0xf59E87c6B05d047aED4941ff00dD841BD0874D7f";
  const uniswapRouter = "0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24";

  // 2. Obtener la factoría del contrato
  const BookieSwapWrapperUniV2 = await ethers.getContractFactory(
    "BookieSwapWrapperUniV2"
  );

  // 3. Desplegar
  const contract = await BookieSwapWrapperUniV2.deploy(
    uniswapRouter,
    feeReceiver
  );
  await contract.deployed();

  console.log("BookieSwapWrapperUniV2 deployed to:", contract.address);

  // 4. Generar el objeto con info
  const outputData = {
    contractName: "BookieSwapWrapperUniV2",
    chain: chainName,
    address: contract.address,
    feeReceiver,
    uniswapRouter,
  };

  const deploymentsDir = path.join(__dirname, "../../deployments/mainnet");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const outFile = path.join(
    deploymentsDir,
    `deploy-BookieSwapWrapperUniV2-${chainName}.json`
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
