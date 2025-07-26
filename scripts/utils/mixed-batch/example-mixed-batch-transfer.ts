import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  console.log("🧪 Probando contrato VIVIMixedBatchTransfer...");

  // Obtener signers
  const signers = await ethers.getSigners();
  const deployer = signers[0];

  // Para redes de testnet/mainnet, usaremos direcciones hardcodeadas para los destinatarios
  // En localhost tendríamos más signers disponibles
  let recipients: string[];
  let isLocalhost = false;

  if (signers.length >= 4) {
    // Localhost - usar signers reales
    recipients = [signers[1].address, signers[2].address, signers[3].address];
    isLocalhost = true;
    console.log("👤 Deployer:", deployer.address);
    console.log("👤 Destinatarios (signers reales):", recipients);
  } else {
    // Testnet/Mainnet - usar direcciones de ejemplo
    recipients = [
      "0x1234567890123456789012345678901234567890",
      "0x2345678901234567890123456789012345678901",
      "0x3456789012345678901234567890123456789012",
    ];
    console.log("👤 Deployer:", deployer.address);
    console.log("👤 Destinatarios (direcciones de ejemplo):", recipients);
    console.log("⚠️  Nota: Usando direcciones de ejemplo para la demostración");
  }

  // Cargar información del deployment
  const network = await ethers.provider.getNetwork();
  const deploymentFiles = fs
    .readdirSync(path.join(__dirname, "deployments"))
    .filter((file) =>
      file.startsWith(`deploy-VIVIMixedBatchTransfer-${network.name}`)
    )
    .sort()
    .reverse(); // Obtener el más reciente

  if (deploymentFiles.length === 0) {
    console.log(
      "❌ Archivo de deployment no encontrado. Por favor despliega el contrato primero."
    );
    return;
  }

  const deploymentFile = path.join(
    __dirname,
    "deployments",
    deploymentFiles[0]
  );
  const deploymentInfo = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
  const contractAddress = deploymentInfo.contractAddress;

  // Obtener instancia del contrato
  const VIVIMixedBatchTransfer = await ethers.getContractFactory(
    "VIVIMixedBatchTransfer"
  );
  const contract = VIVIMixedBatchTransfer.attach(contractAddress);

  console.log("📍 Dirección del contrato:", contractAddress);

  // Desplegar un token ERC20 mock para pruebas
  console.log("\n🪙 Desplegando token ERC20 mock para pruebas...");
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const mockToken = await MockERC20.deploy(
    "Test Token",
    "TEST",
    ethers.utils.parseEther("1000000")
  );
  await mockToken.deployed();
  const tokenAddress = mockToken.address;
  console.log("✅ Token mock desplegado en:", tokenAddress);

  // Mint tokens al deployer
  const mintAmount = ethers.utils.parseEther("10000");
  await mockToken.mint(deployer.address, mintAmount);
  console.log(
    "💰 Minteados",
    ethers.utils.formatEther(mintAmount),
    "tokens TEST al deployer"
  );

  // Aprobar al contrato para gastar tokens
  const approveAmount = ethers.utils.parseEther("1000");
  await mockToken.approve(contractAddress, approveAmount);
  console.log(
    "✅ Aprobados",
    ethers.utils.formatEther(approveAmount),
    "tokens TEST para el contrato"
  );

  // Ejemplo 1: Transferencia mixta en lote con cantidades iguales
  console.log(
    "\n📦 Ejemplo 1: Transferencia mixta en lote con cantidades iguales"
  );
  const tokenAmountEach = ethers.utils.parseEther("10"); // 10 tokens TEST cada uno
  const ethAmountEach = ethers.utils.parseEther("0.001"); // 0.1 ETH cada uno

  // Calcular totales usando la nueva función
  const [totalTokens, totalEth] = await contract.calculateTotalAmounts(
    recipients.length,
    tokenAmountEach,
    ethAmountEach
  );
  console.log(
    "💡 Total tokens necesarios:",
    ethers.utils.formatEther(totalTokens),
    "TEST"
  );
  console.log(
    "💡 Total ETH necesario:",
    ethers.utils.formatEther(totalEth),
    "ETH"
  );

  // Verificar balances antes (solo si estamos en localhost con signers reales)
  if (isLocalhost) {
    console.log("\n📊 Balances antes de la transferencia:");
    for (let i = 0; i < 3; i++) {
      const recipientAddress = recipients[i];
      const tokenBalance = await mockToken.balanceOf(recipientAddress);
      const ethBalance = await ethers.provider.getBalance(recipientAddress);
      console.log(
        `  ${recipientAddress}: ${ethers.utils.formatEther(
          tokenBalance
        )} TEST, ${ethers.utils.formatEther(ethBalance)} ETH`
      );
    }
  } else {
    console.log(
      "\n📊 Saltando verificación de balances (usando direcciones de ejemplo)"
    );
  }

  // Realizar transferencia mixta en lote
  console.log("\n🚀 Realizando transferencia mixta en lote...");
  try {
    const tx = await contract.mixedBatchTransferEqual(
      tokenAddress,
      recipients,
      tokenAmountEach,
      ethAmountEach,
      {
        value: totalEth, // Enviar el ETH requerido
      }
    );
    await tx.wait();
    console.log("✅ ¡Transferencia mixta en lote completada!");
  } catch (error: any) {
    console.log(
      "⚠️  Error esperado en testnet (direcciones de ejemplo):",
      error.message
    );
  }

  // Verificar balances después (solo si estamos en localhost)
  if (isLocalhost) {
    console.log("\n📊 Balances después de la transferencia:");
    for (let i = 0; i < 3; i++) {
      const recipientAddress = recipients[i];
      const tokenBalance = await mockToken.balanceOf(recipientAddress);
      const ethBalance = await ethers.provider.getBalance(recipientAddress);
      console.log(
        `  ${recipientAddress}: ${ethers.utils.formatEther(
          tokenBalance
        )} TEST, ${ethers.utils.formatEther(ethBalance)} ETH`
      );
    }
  }

  console.log("\n🎉 ¡Ejemplo completado!");

  if (!isLocalhost) {
    console.log("\n💡 Nota: Para probar con transferencias reales:");
    console.log("   1. Ejecuta en localhost con `npx hardhat node`");
    console.log(
      "   2. O usa direcciones reales de destinatarios en lugar de las de ejemplo"
    );
  }
}

// Manejo de errores
main()
  .then(() => {
    console.log("✅ ¡Pruebas completadas!");
    process.exit(0);
  })
  .catch((error: any) => {
    console.error("❌ Pruebas fallaron:", error);
    process.exit(1);
  });
