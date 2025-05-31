// scripts/virtuals/1_buy_example.ts

import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  // 1. Cargar información del contrato desplegado
  const deploymentFile = path.join(
    __dirname,
    "./deployments/deploy-VIVIVirtualsHop-base-mainnet.json"
  );

  if (!fs.existsSync(deploymentFile)) {
    console.error(
      "❌ Deployment file not found. Please deploy the contract first."
    );
    console.error(
      "Run: npx hardhat run scripts/virtuals/0_deploy.ts --network base-mainnet"
    );
    process.exit(1);
  }

  const deploymentData = JSON.parse(fs.readFileSync(deploymentFile, "utf-8"));
  const contractAddress = deploymentData.address;

  console.log("🚀 VIVIVirtualsBuy Example");
  console.log("Contract Address:", contractAddress);

  // 2. Conectar al contrato
  const VIVIVirtualsHop = await ethers.getContractFactory("VIVIVirtualsHop");
  const contract = VIVIVirtualsHop.attach(contractAddress);

  // 3. Configurar parámetros de ejemplo
  const [signer] = await ethers.getSigners();

  // Token de ejemplo - reemplaza con el token que quieras comprar
  const targetToken = "0x80CA9EdCE4583B8043351A1046F18244b24eF869"; // TOKEN ADDRESS
  const ethAmountToSpend = ethers.utils.parseEther("0.001"); // 0.01 ETH
  const feeBps = 50; // 0.5% fee
  const slippagePercent = 3; // 3% slippage tolerance

  const params = {
    tokenTarget: targetToken,
    recipient: signer.address,
    deadline: Math.floor(Date.now() / 1000) + 300, // 5 minutos
    slippagePercent: 3, // 3% slippage tolerance (V2 style)
    amountIn: 0, // Not used for buy
  };

  console.log("\n📊 Transaction Parameters:");
  console.log("Target Token:", params.tokenTarget);
  console.log("ETH Amount:", ethers.utils.formatEther(ethAmountToSpend));
  console.log("Fee:", `${feeBps / 100}%`);
  console.log("Max Slippage:", `${slippagePercent}%`);

  // 4. Estimar gas
  try {
    console.log("\n⏱️  Estimating gas...");
    const gasEstimate = await contract.estimateGas.VIVIVirtualsBuy(
      params,
      feeBps,
      { value: ethAmountToSpend }
    );
    console.log("Estimated Gas:", gasEstimate.toString());

    // Descomenta estas líneas para ejecutar realmente
    const tx = await contract.VIVIVirtualsBuy(params, feeBps, {
      value: ethAmountToSpend,
      gasLimit: gasEstimate.mul(120).div(100),
    });

    console.log("Transaction hash:", tx.hash);
    console.log("⏳ Waiting for confirmation...");

    const receipt = await tx.wait();
    console.log("✅ Transaction confirmed in block:", receipt.blockNumber);

    // Buscar eventos
    const buyEvent = receipt.events?.find(
      (e: { event: string }) => e.event === "Buy"
    );
    if (buyEvent) {
      console.log("\n📈 Buy Event Details:");
      console.log("User:", buyEvent.args?.user);
      console.log("Token Out:", buyEvent.args?.tokenOut);
      console.log(
        "ETH In:",
        ethers.utils.formatEther(buyEvent.args?.ethIn || 0)
      );
      console.log(
        "ETH After Fee:",
        ethers.utils.formatEther(buyEvent.args?.ethInAfterFee || 0)
      );
      console.log("Tokens Out:", buyEvent.args?.tokensOut?.toString());
      console.log(
        "Fee Amount:",
        ethers.utils.formatEther(buyEvent.args?.feeAmount || 0)
      );
    }
  } catch (error) {
    console.error("❌ Error:", error);
  }

  console.log("\n🎯 Route: ETH → VIRTUAL → TARGET_TOKEN");
  console.log("💡 Tip: Update targetToken address before executing");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
