// scripts/generate-wallet.ts
import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

function generateWallet() {
  // Generar wallet aleatoria
  const wallet = ethers.Wallet.createRandom();

  return {
    address: wallet.address,
    privateKey: wallet.privateKey,
    mnemonic: wallet.mnemonic?.phrase || "No mnemonic available",
  };
}

function saveWalletToFile(walletData: any, filename?: string) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const defaultFilename = `wallet-${timestamp}.json`;
  const finalFilename = filename || defaultFilename;

  const walletsDir = path.join(__dirname, "../wallets");

  // Crear directorio si no existe
  if (!fs.existsSync(walletsDir)) {
    fs.mkdirSync(walletsDir, { recursive: true });
  }

  const filePath = path.join(walletsDir, finalFilename);

  // Guardar wallet
  fs.writeFileSync(filePath, JSON.stringify(walletData, null, 2));

  return filePath;
}

async function main() {
  console.log("🔐 Generando nueva wallet...\n");

  // Generar wallet
  const walletData = generateWallet();

  // Mostrar información
  console.log("=== NUEVA WALLET GENERADA ===");
  console.log(`Address:      ${walletData.address}`);
  console.log(`Private Key:  ${walletData.privateKey}`);
  console.log(`Mnemonic:     ${walletData.mnemonic}`);

  // Preguntar si guardar en archivo (simulado - en producción podrías usar readline)
  const shouldSave = true; // Cambiar a false si no quieres guardar

  if (shouldSave) {
    try {
      const filePath = saveWalletToFile(walletData);
      console.log(`\n✅ Wallet guardada en: ${filePath}`);
    } catch (error) {
      console.error("❌ Error guardando wallet:", error);
    }
  }

  console.log("\n⚠️  IMPORTANTE:");
  console.log("- Guarda tu private key en un lugar seguro");
  console.log("- NUNCA compartas tu private key con nadie");
  console.log(
    "- Esta wallet NO tiene fondos, necesitas enviarle ETH para usarla"
  );
  console.log("- El archivo guardado contiene información sensible");

  // Verificación de la wallet
  console.log("\n🧪 Verificación:");
  const recoveredWallet = new ethers.Wallet(walletData.privateKey);
  console.log(`Address recuperada: ${recoveredWallet.address}`);
  console.log(
    `✅ Verificación ${
      walletData.address === recoveredWallet.address ? "EXITOSA" : "FALLIDA"
    }`
  );
}

// Función adicional para generar múltiples wallets
async function generateMultipleWallets(count: number = 5) {
  console.log(`🔐 Generando ${count} wallets...\n`);

  const wallets = [];

  for (let i = 0; i < count; i++) {
    const wallet = generateWallet();
    wallets.push(wallet);

    console.log(`Wallet ${i + 1}:`);
    console.log(`  Address:     ${wallet.address}`);
    console.log(`  Private Key: ${wallet.privateKey}`);
    console.log("");
  }

  // Guardar todas en un archivo
  try {
    const filePath = saveWalletToFile(
      { wallets, count, generated: new Date().toISOString() },
      "multiple-wallets.json"
    );
    console.log(`✅ ${count} wallets guardadas en: ${filePath}`);
  } catch (error) {
    console.error("❌ Error guardando wallets:", error);
  }

  return wallets;
}

// Función para generar wallet desde mnemonic específico
function generateFromMnemonic(mnemonic: string, index: number = 0) {
  try {
    const wallet = ethers.Wallet.fromMnemonic(
      mnemonic,
      `m/44'/60'/0'/0/${index}`
    );

    return {
      address: wallet.address,
      privateKey: wallet.privateKey,
      mnemonic: mnemonic,
      index: index,
    };
  } catch (error) {
    console.error("❌ Error generando wallet desde mnemonic:", error);
    throw error;
  }
}

// Ejecutar script
if (require.main === module) {
  const args = process.argv.slice(2);

  if (args.includes("--multiple")) {
    const countIndex = args.indexOf("--count");
    const count = countIndex !== -1 ? parseInt(args[countIndex + 1]) || 5 : 5;
    generateMultipleWallets(count);
  } else if (args.includes("--from-mnemonic")) {
    const mnemonicIndex = args.indexOf("--mnemonic");
    const indexIndex = args.indexOf("--index");

    if (mnemonicIndex === -1 || !args[mnemonicIndex + 1]) {
      console.error(
        "❌ Debes proporcionar un mnemonic con --mnemonic 'tu mnemonic aqui'"
      );
      process.exit(1);
    }

    const mnemonic = args[mnemonicIndex + 1];
    const index = indexIndex !== -1 ? parseInt(args[indexIndex + 1]) || 0 : 0;

    console.log("🔐 Generando wallet desde mnemonic...\n");
    const wallet = generateFromMnemonic(mnemonic, index);

    console.log("=== WALLET DESDE MNEMONIC ===");
    console.log(`Address:      ${wallet.address}`);
    console.log(`Private Key:  ${wallet.privateKey}`);
    console.log(`Index:        ${wallet.index}`);
    console.log(`Mnemonic:     ${wallet.mnemonic}`);
  } else {
    main().catch((error) => {
      console.error("❌ Error:", error);
      process.exit(1);
    });
  }
}

export { generateWallet, generateMultipleWallets, generateFromMnemonic };
