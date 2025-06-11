import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  console.log("🔍 Verificando deployment de VIVIMixedBatchTransfer...");

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

  console.log("📍 Dirección del contrato:", contractAddress);
  console.log("🌐 Red:", network.name);

  // Obtener instancia del contrato
  const VIVIMixedBatchTransfer = await ethers.getContractFactory(
    "VIVIMixedBatchTransfer"
  );
  const contract = VIVIMixedBatchTransfer.attach(contractAddress);

  try {
    // Verify basic contract properties
    console.log("\n🔧 Verifying contract properties...");

    const owner = await contract.owner();
    console.log("👑 Owner:", owner);

    const maxRecipients = await contract.maxRecipientsPerBatch();
    console.log("📊 Max recipients per batch:", maxRecipients.toString());

    // Probar funciones de vista
    console.log("\n🧪 Probando funciones de vista...");

    // Probar calculateTotalAmounts con la nueva función
    const [totalTokens, totalEth] = await contract.calculateTotalAmounts(
      2, // 2 recipients
      ethers.utils.parseEther("10"), // 10 tokens each
      ethers.utils.parseEther("0.1") // 0.1 ETH each
    );
    console.log(
      "💰 Total tokens (prueba):",
      ethers.utils.formatEther(totalTokens)
    );
    console.log("💰 Total ETH (prueba):", ethers.utils.formatEther(totalEth));

    // Probar canPerformMixedBatchTransfer
    const [deployer] = await ethers.getSigners();
    const testTokenAddress = "0x1234567890123456789012345678901234567890"; // Dirección dummy
    const canPerform = await contract.canPerformMixedBatchTransfer(
      deployer.address,
      testTokenAddress,
      totalTokens,
      totalEth
    );
    console.log("🔍 Can perform transfer (prueba):", canPerform);

    // Verificar tamaño del código del contrato
    const code = await ethers.provider.getCode(contractAddress);
    console.log("📏 Tamaño del código del contrato:", code.length, "bytes");

    // Verificar si el contrato tiene balance de ETH
    const ethBalance = await ethers.provider.getBalance(contractAddress);
    console.log(
      "💎 Balance ETH del contrato:",
      ethers.utils.formatEther(ethBalance),
      "ETH"
    );

    console.log("\n✅ ¡Verificación del contrato completada exitosamente!");
    console.log("🎯 El contrato está desplegado y funcional");

    // Mostrar resumen del deployment
    console.log("\n📋 Resumen del Deployment:");
    console.log("  Nombre del Contrato: VIVIMixedBatchTransfer");
    console.log("  Dirección del Contrato:", contractAddress);
    console.log("  Red:", network.name);
    console.log("  Owner:", owner);
    console.log("  Max Destinatarios por Batch:", maxRecipients.toString());
    console.log("  Bloque de Deployment:", deploymentInfo.deploymentBlock);
    console.log("  Fecha de Deployment:", deploymentInfo.deploymentDate);

    return {
      contractAddress,
      owner,
      maxRecipients: maxRecipients.toString(),
      isValid: true,
    };
  } catch (error: any) {
    console.error("❌ Verificación del contrato falló:", error);
    return {
      contractAddress,
      isValid: false,
      error: error.message,
    };
  }
}

// Manejo de errores
main()
  .then((result) => {
    if (result?.isValid) {
      console.log("🎉 ¡Verificación completada exitosamente!");
    } else {
      console.log("❌ ¡Verificación falló!");
    }
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Error de verificación:", error);
    process.exit(1);
  });
