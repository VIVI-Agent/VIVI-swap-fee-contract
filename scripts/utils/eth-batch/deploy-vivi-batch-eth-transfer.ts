import { ethers } from "hardhat";
import { writeFileSync, mkdirSync } from "fs";
import { join } from "path";

async function main() {
  console.log("Desplegando VIVIBatchETHTransfer...");

  // Obtener el deployer
  const [deployer] = await ethers.getSigners();
  console.log("Desplegando con cuenta:", deployer.address);
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Balance de cuenta:", ethers.utils.formatEther(balance));

  // Desplegar el contrato
  const VIVIBatchETHTransfer = await ethers.getContractFactory(
    "VIVIBatchETHTransfer"
  );
  const contract = await VIVIBatchETHTransfer.deploy();

  await contract.waitForDeployment();
  const contractAddress = await contract.getAddress();

  console.log("VIVIBatchETHTransfer desplegado en:", contractAddress);

  // Obtener información del contrato
  const maxRecipientsPerBatch = await contract.maxRecipientsPerBatch();
  const owner = await contract.owner();

  console.log("Información del contrato:");
  console.log("- Address:", contractAddress);
  console.log("- Owner:", owner);
  console.log("- Max recipients per batch:", maxRecipientsPerBatch.toString());

  // Guardar información del despliegue
  const network = await ethers.provider.getNetwork();
  const deploymentInfo = {
    network: network.name,
    chainId: network.chainId.toString(),
    contractAddress: contractAddress,
    deployerAddress: deployer.address,
    owner: owner,
    maxRecipientsPerBatch: maxRecipientsPerBatch.toString(),
    deploymentTime: new Date().toISOString(),
    transactionHash: contract.deploymentTransaction()?.hash,
  };

  // Crear directorio si no existe
  const deploymentsDir = join(__dirname, "deployments");
  try {
    mkdirSync(deploymentsDir, { recursive: true });
  } catch (error) {
    // El directorio ya existe
  }

  // Guardar en archivo JSON
  const filename = `deploy-VIVIBatchETHTransfer-${
    network.name
  }-${Date.now()}.json`;
  const filepath = join(deploymentsDir, filename);
  writeFileSync(filepath, JSON.stringify(deploymentInfo, null, 2));

  console.log(`Información del despliegue guardada en: ${filepath}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
