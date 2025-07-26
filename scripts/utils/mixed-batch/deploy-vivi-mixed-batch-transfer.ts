import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  console.log("🚀 Desplegando VIVIMixedBatchTransfer...");

  // Obtener el deployer
  const [deployer] = await ethers.getSigners();
  console.log("👤 Desplegando con la cuenta:", deployer.address);

  // Desplegar el contrato
  console.log("\n📦 Compilando y desplegando contrato...");
  const VIVIMixedBatchTransfer = await ethers.getContractFactory(
    "VIVIMixedBatchTransfer"
  );

  const contract = await VIVIMixedBatchTransfer.deploy();
  await contract.deployed();

  console.log("✅ VIVIMixedBatchTransfer desplegado en:", contract.address);
  console.log("🔗 Transaction hash:", contract.deployTransaction.hash);

  // Esperar confirmaciones
  console.log("⏳ Esperando confirmaciones...");
  await contract.deployTransaction.wait(2);
  console.log("✅ Contrato confirmado!");

  // Obtener información del contrato
  const owner = await contract.owner();
  const maxRecipients = await contract.maxRecipientsPerBatch();

  console.log("\n📋 Información del contrato:");
  console.log("👑 Owner:", owner);
  console.log("👥 Max destinatarios por batch:", maxRecipients.toString());

  // Guardar información del deployment
  const network = await ethers.provider.getNetwork();
  const deploymentInfo = {
    contractName: "VIVIMixedBatchTransfer",
    contractAddress: contract.address,
    deployerAddress: deployer.address,
    transactionHash: contract.deployTransaction.hash,
    blockNumber: contract.deployTransaction.blockNumber,
    network: {
      name: network.name,
      chainId: network.chainId,
    },
    deploymentDate: new Date().toISOString(),
    contractInfo: {
      owner: owner,
      maxRecipientsPerBatch: maxRecipients.toString(),
    },
  };

  console.log("📋 Deployment Info:", deploymentInfo);

  // Crear directorio de deployments si no existe
  const deploymentsDir = path.join(__dirname, "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  // Guardar información del deployment
  const filename = `deploy-VIVIMixedBatchTransfer-${
    network.name
  }-${Date.now()}.json`;
  const filepath = path.join(deploymentsDir, filename);
  fs.writeFileSync(filepath, JSON.stringify(deploymentInfo, null, 2));

  console.log("\n💾 Información del deployment guardada en:", filepath);

  // Mostrar comandos útiles
  console.log("\n🛠️  Comandos útiles:");
  console.log(
    `npx hardhat verify --network ${network.name} ${contract.address}`
  );

  console.log("\n🎉 ¡Deployment completado exitosamente!");

  return {
    contract,
    deploymentInfo,
  };
}

// Manejo de errores
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error durante el deployment:");
    console.error(error);
    process.exit(1);
  });
