import { ethers } from "hardhat";

async function main() {
  console.log("🚀 Ejemplo práctico de uso de VIVIBatchTransfer");
  console.log("=".repeat(50));

  // Obtener signers
  const [deployer, user1, recipient1, recipient2, recipient3] =
    await ethers.getSigners();

  console.log("👤 Deployer:", deployer.address);
  console.log("👤 Usuario:", user1.address);
  console.log("👥 Recipients:", [
    recipient1.address,
    recipient2.address,
    recipient3.address,
  ]);

  // 1. Desplegar los contratos
  console.log("\n📦 PASO 1: Desplegando contratos...");

  // Desplegar VIVIBatchTransfer
  const VIVIBatchTransfer = await ethers.getContractFactory(
    "VIVIBatchTransfer"
  );
  const batchContract = await VIVIBatchTransfer.deploy();
  await batchContract.deployed();
  console.log("✅ VIVIBatchTransfer desplegado:", batchContract.address);

  // Desplegar MockERC20 para el ejemplo
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const token = await MockERC20.deploy(
    "VIVI Token",
    "VIVI",
    18,
    ethers.utils.parseEther("1000000") // 1M tokens
  );
  await token.deployed();
  console.log("✅ VIVI Token desplegado:", token.address);

  // 2. Configurar tokens para el usuario
  console.log("\n💰 PASO 2: Configurando tokens...");

  // Transferir tokens al usuario
  const userAmount = ethers.utils.parseEther("10000");
  await token.transfer(user1.address, userAmount);

  const userBalance = await token.balanceOf(user1.address);
  console.log(
    "✅ Balance del usuario:",
    ethers.utils.formatEther(userBalance),
    "VIVI"
  );

  // 3. Ejemplo 1: Batch Transfer Simple
  console.log("\n🎯 PASO 3: Ejemplo 1 - Batch Transfer Simple");
  console.log("-".repeat(40));

  const recipients = [
    recipient1.address,
    recipient2.address,
    recipient3.address,
  ];
  const amounts = [
    ethers.utils.parseEther("100"), // 100 VIVI
    ethers.utils.parseEther("200"), // 200 VIVI
    ethers.utils.parseEther("300"), // 300 VIVI
  ];

  // Calcular total necesario
  const totalAmount = amounts.reduce(
    (sum, amount) => sum.add(amount),
    ethers.BigNumber.from(0)
  );
  console.log(
    "💰 Total necesario:",
    ethers.utils.formatEther(totalAmount),
    "VIVI"
  );

  // Aprobar tokens al contrato
  console.log("🔓 Aprobando tokens al contrato...");
  await token.connect(user1).approve(batchContract.address, totalAmount);

  // Verificar allowance
  const allowance = await token.allowance(user1.address, batchContract.address);
  console.log("✅ Allowance:", ethers.utils.formatEther(allowance), "VIVI");

  // Ejecutar batch transfer
  console.log("🚀 Ejecutando batch transfer...");
  const tx1 = await batchContract
    .connect(user1)
    .batchTransferSimple(token.address, recipients, amounts);

  const receipt1 = await tx1.wait();
  console.log("✅ Transacción completada!");
  console.log("⛽ Gas usado:", receipt1.gasUsed.toString());

  // Verificar balances
  for (let i = 0; i < recipients.length; i++) {
    const balance = await token.balanceOf(recipients[i]);
    console.log(
      `📊 Balance ${recipients[i]}: ${ethers.utils.formatEther(balance)} VIVI`
    );
  }

  // 4. Ejemplo 2: Batch Transfer Equal
  console.log("\n🎯 PASO 4: Ejemplo 2 - Batch Transfer Equal");
  console.log("-".repeat(40));

  const amountEach = ethers.utils.parseEther("50"); // 50 VIVI cada uno
  const totalEqual = amountEach.mul(recipients.length);

  console.log(
    "💰 Cantidad por recipient:",
    ethers.utils.formatEther(amountEach),
    "VIVI"
  );
  console.log(
    "💰 Total necesario:",
    ethers.utils.formatEther(totalEqual),
    "VIVI"
  );

  // Aprobar tokens adicionales
  await token.connect(user1).approve(batchContract.address, totalEqual);

  // Ejecutar batch transfer equal
  console.log("🚀 Ejecutando batch transfer equal...");
  const tx2 = await batchContract
    .connect(user1)
    .batchTransferEqual(token.address, recipients, amountEach);

  const receipt2 = await tx2.wait();
  console.log("✅ Transacción completada!");
  console.log("⛽ Gas usado:", receipt2.gasUsed.toString());

  // Verificar balances finales
  console.log("\n📊 Balances finales:");
  for (let i = 0; i < recipients.length; i++) {
    const balance = await token.balanceOf(recipients[i]);
    console.log(
      `👤 ${recipients[i]}: ${ethers.utils.formatEther(balance)} VIVI`
    );
  }

  const finalUserBalance = await token.balanceOf(user1.address);
  console.log(
    `👤 Usuario final: ${ethers.utils.formatEther(finalUserBalance)} VIVI`
  );

  // 5. Ejemplo 3: Configuración de administrador
  console.log("\n🎯 PASO 5: Ejemplo 3 - Funciones de Administración");
  console.log("-".repeat(40));

  // Verificar configuración actual
  const currentOwner = await batchContract.owner();
  const maxRecipients = await batchContract.maxRecipientsPerBatch();
  const onlyAuthorized = await batchContract.onlyAuthorizedTokens();

  console.log("👑 Owner actual:", currentOwner);
  console.log("👥 Max recipients:", maxRecipients.toString());
  console.log("🔐 Solo tokens autorizados:", onlyAuthorized);

  // Cambiar configuración (solo owner puede hacer esto)
  console.log("\n🔧 Cambiando configuración...");

  // Cambiar límite de recipients
  await batchContract.connect(deployer).setMaxRecipientsPerBatch(1000);
  const newMaxRecipients = await batchContract.maxRecipientsPerBatch();
  console.log("✅ Nuevo límite de recipients:", newMaxRecipients.toString());

  // Activar modo solo tokens autorizados
  await batchContract.connect(deployer).setOnlyAuthorizedTokens(true);
  console.log("✅ Modo solo tokens autorizados activado");

  // Autorizar nuestro token
  await batchContract.connect(deployer).authorizeToken(token.address);
  console.log("✅ Token VIVI autorizado");

  // 6. Análisis de costos
  console.log("\n📊 PASO 6: Análisis de Costos");
  console.log("-".repeat(40));

  // Comparar costos
  const gasPerTransfer1 = receipt1.gasUsed.div(recipients.length);
  const gasPerTransfer2 = receipt2.gasUsed.div(recipients.length);

  console.log("⛽ Gas por transfer (Simple):", gasPerTransfer1.toString());
  console.log("⛽ Gas por transfer (Equal):", gasPerTransfer2.toString());

  // Estimar costo para diferentes tamaños de batch
  console.log("\n📈 Estimación de gas para diferentes tamaños:");
  for (const batchSize of [1, 5, 10, 25, 50, 100]) {
    try {
      const dummyRecipients = Array(batchSize).fill(recipient1.address);
      const dummyAmounts = Array(batchSize).fill(ethers.utils.parseEther("1"));

      const gasEstimate = await batchContract
        .connect(user1)
        .estimateGas.batchTransferSimple(
          token.address,
          dummyRecipients,
          dummyAmounts
        );

      const gasPerTransfer = gasEstimate.div(batchSize);
      console.log(
        `📊 ${batchSize} transfers: ${gasEstimate.toString()} gas total (${gasPerTransfer.toString()} por transfer)`
      );
    } catch (error) {
      console.log(`❌ ${batchSize} transfers: Error en estimación`);
    }
  }

  // 7. Resumen final
  console.log("\n🎉 RESUMEN FINAL");
  console.log("=".repeat(50));
  console.log("✅ Contratos desplegados exitosamente");
  console.log("✅ Batch transfers ejecutados correctamente");
  console.log("✅ Funciones de administración configuradas");
  console.log("✅ Análisis de costos completado");

  console.log("\n📋 Direcciones importantes:");
  console.log(`🏦 VIVIBatchTransfer: ${batchContract.address}`);
  console.log(`🪙 VIVI Token: ${token.address}`);

  console.log("\n📝 Casos de uso demostrados:");
  console.log("• Transferencias con cantidades diferentes");
  console.log("• Transferencias con cantidades iguales");
  console.log("• Configuración de administrador");
  console.log("• Análisis de eficiencia de gas");

  console.log("\n💡 Próximos pasos:");
  console.log("• Desplegar en testnet para pruebas");
  console.log("• Verificar el contrato en el explorador");
  console.log("• Integrar en tu dApp o script");

  return {
    batchContract: batchContract.address,
    token: token.address,
    gasUsed: {
      batchSimple: receipt1.gasUsed.toString(),
      batchEqual: receipt2.gasUsed.toString(),
    },
  };
}

// Ejecutar el ejemplo
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("❌ Error en el ejemplo:");
      console.error(error);
      process.exit(1);
    });
}

export { main as runExample };
