import { ethers } from "hardhat";

async function main() {
  console.log("🧪 Verificación rápida de VIVIBatchTransfer...");

  // Obtener signers
  const [owner] = await ethers.getSigners();
  console.log("👤 Deployer:", owner.address);

  // Desplegar VIVIBatchTransfer
  console.log("\n📦 Desplegando VIVIBatchTransfer...");
  const VIVIBatchTransfer = await ethers.getContractFactory(
    "VIVIBatchTransfer"
  );
  const batchContract = await VIVIBatchTransfer.deploy();
  await batchContract.deployed();
  console.log("✅ VIVIBatchTransfer desplegado en:", batchContract.address);

  // Verificar configuración inicial
  const ownerAddress = await batchContract.owner();
  const maxRecipients = await batchContract.maxRecipientsPerBatch();
  const onlyAuthorized = await batchContract.onlyAuthorizedTokens();

  console.log("\n📋 Configuración inicial:");
  console.log("👑 Owner:", ownerAddress);
  console.log("👥 Max recipients:", maxRecipients.toString());
  console.log("🔐 Solo tokens autorizados:", onlyAuthorized);

  // Desplegar MockERC20
  console.log("\n🪙 Desplegando MockERC20...");
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const mockToken = await MockERC20.deploy(
    "Test Token",
    "TEST",
    18,
    ethers.utils.parseEther("1000000")
  );
  await mockToken.deployed();
  console.log("✅ MockERC20 desplegado en:", mockToken.address);

  // Verificar token
  const tokenName = await mockToken.name();
  const tokenSymbol = await mockToken.symbol();
  const tokenDecimals = await mockToken.decimals();
  const totalSupply = await mockToken.totalSupply();

  console.log("\n🪙 Información del token:");
  console.log("📛 Nombre:", tokenName);
  console.log("🔤 Símbolo:", tokenSymbol);
  console.log("🔢 Decimales:", tokenDecimals);
  console.log("💰 Total Supply:", ethers.utils.formatEther(totalSupply));

  console.log("\n🎉 ¡Verificación completada exitosamente!");
  console.log("\n📋 Resumen:");
  console.log("🏦 VIVIBatchTransfer:", batchContract.address);
  console.log("🪙 MockERC20:", mockToken.address);

  return {
    batchContract: batchContract.address,
    mockToken: mockToken.address,
  };
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error:", error);
    process.exit(1);
  });
