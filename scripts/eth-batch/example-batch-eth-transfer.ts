import { ethers } from "hardhat";

// Configuración del ejemplo
const CONTRACT_ADDRESS = ""; // Coloca aquí la dirección del contrato desplegado
const TEST_RECIPIENTS = [
  "0x742d35Cc6634C0532925a3b8D4C0d5AF8E20a1A4", // Reemplaza con direcciones reales
  "0x8ba1f109551bD432803012645Hac136c5c4b2Eba",
  "0x0000000000000000000000000000000000000001",
];

async function main() {
  if (!CONTRACT_ADDRESS) {
    console.error("❌ Por favor configura CONTRACT_ADDRESS en el script");
    return;
  }

  console.log("🚀 Ejemplo de VIVIBatchETHTransfer");
  console.log("================================");

  // Obtener signers
  const [deployer] = await ethers.getSigners();
  console.log("🔑 Usando cuenta:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance inicial:", ethers.utils.formatEther(balance), "ETH");

  // Conectar al contrato
  const VIVIBatchETHTransfer = await ethers.getContractFactory(
    "VIVIBatchETHTransfer"
  );
  const contract = VIVIBatchETHTransfer.attach(CONTRACT_ADDRESS);

  console.log("📄 Contrato conectado en:", CONTRACT_ADDRESS);

  // Verificar información del contrato
  const maxRecipients = await contract.maxRecipientsPerBatch();
  const owner = await contract.owner();

  console.log("ℹ️  Información del contrato:");
  console.log("   - Owner:", owner);
  console.log("   - Max recipients per batch:", maxRecipients.toString());

  // Ejemplo 1: Batch transfer con cantidades iguales
  console.log("\n📤 Ejemplo 1: Batch Transfer - Cantidades Iguales");
  console.log("===============================================");

  const ethAmountEach = ethers.utils.parseEther("0.001"); // 0.001 ETH por recipient
  const totalEthRequired = await contract.calculateTotalEthAmount(
    TEST_RECIPIENTS.length,
    ethAmountEach
  );

  console.log("🔢 Parámetros:");
  console.log("   - Recipients:", TEST_RECIPIENTS.length);
  console.log(
    "   - ETH por recipient:",
    ethers.utils.formatEther(ethAmountEach),
    "ETH"
  );
  console.log(
    "   - Total ETH requerido:",
    ethers.utils.formatEther(totalEthRequired),
    "ETH"
  );

  // Verificar si puede realizar la transferencia
  const canPerform = await contract.canPerformBatchTransfer(
    deployer.address,
    totalEthRequired
  );
  console.log("✅ Puede realizar transferencia:", canPerform);

  if (canPerform) {
    try {
      console.log("🔄 Ejecutando batchETHTransferEqual...");

      const tx = await contract.batchETHTransferEqual(
        TEST_RECIPIENTS,
        ethAmountEach,
        { value: totalEthRequired }
      );

      console.log("📋 Hash de transacción:", tx.hash);
      const receipt = await tx.wait();
      console.log("✅ Transacción confirmada en bloque:", receipt?.blockNumber);

      // Buscar el evento emitido
      const event = receipt?.logs.find((log: any) => {
        try {
          const parsed = contract.interface.parseLog({
            topics: log.topics as string[],
            data: log.data,
          });
          return parsed?.name === "BatchETHTransferCompleted";
        } catch {
          return false;
        }
      });

      if (event) {
        const parsed = contract.interface.parseLog({
          topics: event.topics as string[],
          data: event.data,
        });
        console.log("🎉 Evento BatchETHTransferCompleted:");
        console.log("   - Sender:", parsed?.args.sender);
        console.log(
          "   - Total ETH:",
          ethers.utils.formatEther(parsed?.args.totalEthAmount),
          "ETH"
        );
        console.log("   - Recipients:", parsed?.args.recipientCount.toString());
      }
    } catch (error: any) {
      console.error("❌ Error en batchETHTransferEqual:", error.message);
    }
  }

  // Ejemplo 2: Batch transfer con cantidades personalizadas
  console.log("\n📤 Ejemplo 2: Batch Transfer - Cantidades Personalizadas");
  console.log("====================================================");

  const customAmounts = [
    ethers.utils.parseEther("0.001"), // 0.001 ETH
    ethers.utils.parseEther("0.002"), // 0.002 ETH
    ethers.utils.parseEther("0.0005"), // 0.0005 ETH
  ];

  const totalCustomEth = await contract.calculateTotalEthAmountCustom(
    customAmounts
  );

  console.log("🔢 Parámetros personalizados:");
  console.log("   - Recipients:", TEST_RECIPIENTS.length);
  customAmounts.forEach((amount, i) => {
    console.log(
      `   - Recipient ${i + 1}: ${ethers.utils.formatEther(amount)} ETH`
    );
  });
  console.log(
    "   - Total ETH requerido:",
    ethers.utils.formatEther(totalCustomEth),
    "ETH"
  );

  const canPerformCustom = await contract.canPerformBatchTransfer(
    deployer.address,
    totalCustomEth
  );
  console.log(
    "✅ Puede realizar transferencia personalizada:",
    canPerformCustom
  );

  if (canPerformCustom) {
    try {
      console.log("🔄 Ejecutando batchETHTransferCustom...");

      const tx = await contract.batchETHTransferCustom(
        TEST_RECIPIENTS,
        customAmounts,
        { value: totalCustomEth }
      );

      console.log("📋 Hash de transacción:", tx.hash);
      const receipt = await tx.wait();
      console.log("✅ Transacción confirmada en bloque:", receipt?.blockNumber);
    } catch (error: any) {
      console.error("❌ Error en batchETHTransferCustom:", error.message);
    }
  }

  // Mostrar balances finales
  console.log("\n💰 Balances finales:");
  console.log("===================");

  const finalBalance = await ethers.provider.getBalance(deployer.address);
  console.log("👤 Deployer:", ethers.utils.formatEther(finalBalance), "ETH");

  for (let i = 0; i < TEST_RECIPIENTS.length; i++) {
    try {
      const recipientBalance = await ethers.provider.getBalance(
        TEST_RECIPIENTS[i]
      );
      console.log(
        `👤 Recipient ${i + 1}: ${ethers.utils.formatEther(
          recipientBalance
        )} ETH`
      );
    } catch (error) {
      console.log(`👤 Recipient ${i + 1}: Error obteniendo balance`);
    }
  }

  console.log("\n🎯 Ejemplo completado!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
