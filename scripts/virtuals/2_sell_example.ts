// scripts/virtuals/2_sell_example.ts

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

  console.log("🚀 VIVIVirtualsSell Example");
  console.log("Contract Address:", contractAddress);

  // 2. Conectar al contrato
  const VIVIVirtualsHop = await ethers.getContractFactory("VIVIVirtualsHop");
  const contract = VIVIVirtualsHop.attach(contractAddress);

  // 3. Configurar parámetros de ejemplo
  const [signer] = await ethers.getSigners();

  // Token de ejemplo - reemplaza con el token que quieras vender
  const targetToken = "0x80CA9EdCE4583B8043351A1046F18244b24eF869"; // TOKEN ADDRESS
  let tokenAmount = ethers.utils.parseUnits("122", 18); // Will be adjusted based on actual balance
  const feeBps = 50; // 0.5% fee
  const slippagePercent = 40; // 40% slippage tolerance

  console.log("\n📊 Initial Parameters:");
  console.log("Target Token:", targetToken);
  console.log(
    "Initial Token Amount:",
    ethers.utils.formatUnits(tokenAmount, 18)
  );
  console.log("Fee:", `${feeBps / 100}%`);
  console.log("Max Slippage:", `${slippagePercent}%`);

  // 4. Verificar balance y allowance
  console.log("\n🔍 Checking token balance and allowance...");

  // Crear la interfaz IERC20 directamente
  const erc20Abi = [
    "function balanceOf(address owner) view returns (uint256)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)",
  ];
  const tokenContract = new ethers.Contract(targetToken, erc20Abi, signer);

  try {
    const balance = await tokenContract.balanceOf(signer.address);
    const allowance = await tokenContract.allowance(
      signer.address,
      contractAddress
    );

    console.log("Token Balance:", ethers.utils.formatUnits(balance, 18));
    console.log("Current Allowance:", ethers.utils.formatUnits(allowance, 18));

    // Use actual balance if it's less than the desired amount
    if (balance.lt(tokenAmount)) {
      console.log(
        `⚠️  Adjusting amount from ${ethers.utils.formatUnits(
          tokenAmount,
          18
        )} to actual balance: ${ethers.utils.formatUnits(balance, 18)}`
      );
      tokenAmount = balance;
    }

    if (balance.isZero()) {
      console.error("❌ No token balance available");
      return;
    }

    if (allowance.lt(tokenAmount)) {
      console.log(
        "⚠️  Insufficient allowance. Approving tokens automatically..."
      );

      try {
        console.log("🔓 Approving tokens...");
        const approveTx = await tokenContract.approve(
          contractAddress,
          tokenAmount
        );
        console.log("⏳ Waiting for approval confirmation...");
        const approveReceipt = await approveTx.wait();
        console.log("✅ Tokens approved successfully!");
        console.log("Approval transaction hash:", approveTx.hash);
      } catch (approveError: any) {
        console.error("❌ Failed to approve tokens:", approveError.message);
        return;
      }
    } else {
      console.log("✅ Sufficient allowance already exists");
    }
  } catch (error: any) {
    console.error("❌ Error checking token:", error.message);
    console.log(
      "💡 Make sure the token address is correct and you have balance"
    );
    return;
  }

  // Create params object after balance adjustment
  const params = {
    tokenTarget: targetToken,
    recipient: signer.address,
    deadline: Math.floor(Date.now() / 1000) + 300, // 5 minutos
    slippagePercent: slippagePercent, // V2 style slippage
    amountIn: tokenAmount,
  };

  console.log("\n📊 Final Transaction Parameters:");
  console.log("Target Token:", params.tokenTarget);
  console.log("Token Amount:", ethers.utils.formatUnits(tokenAmount, 18));
  console.log("Fee:", `${feeBps / 100}%`);
  console.log("Max Slippage:", `${slippagePercent}%`);

  // 5. Estimar gas
  try {
    // Descomenta estas líneas para ejecutar realmente
    const tx = await contract.VIVIVirtualsSell(params, feeBps);

    console.log("Transaction hash:", tx.hash);
    console.log("⏳ Waiting for confirmation...");

    const receipt = await tx.wait();
    console.log("✅ Transaction confirmed in block:", receipt.blockNumber);

    // Buscar eventos
    const sellEvent = receipt.events?.find((e: any) => e.event === "Sell");
    if (sellEvent) {
      console.log("\n📉 Sell Event Details:");
      console.log("User:", sellEvent.args?.user);
      console.log("Token In:", sellEvent.args?.tokenIn);
      console.log("Tokens In:", sellEvent.args?.tokensIn?.toString());
      console.log(
        "ETH Out:",
        ethers.utils.formatEther(sellEvent.args?.ethOut || 0)
      );
      console.log(
        "ETH After Fee:",
        ethers.utils.formatEther(sellEvent.args?.ethOutAfterFee || 0)
      );
      console.log(
        "Fee Amount:",
        ethers.utils.formatEther(sellEvent.args?.feeAmount || 0)
      );
    }
  } catch (error) {
    console.error("❌ Error:", error);
  }

  console.log("\n🎯 Route: TARGET_TOKEN → VIRTUAL → ETH");
  console.log("💡 Tips:");
  console.log("  - Update targetToken address before executing");
  console.log("  - Make sure you have tokens and have approved the contract");
  console.log("  - Set appropriate amountOutMin for slippage protection");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
