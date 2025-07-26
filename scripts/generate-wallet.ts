import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

async function generateWallet() {
  try {
    // Generate a new random wallet
    const wallet = ethers.Wallet.createRandom();

    // Get wallet information
    const address = wallet.address;
    const privateKey = wallet.privateKey;
    const mnemonic = wallet.mnemonic?.phrase;

    // Create wallet info object
    const walletInfo = {
      address: address,
      privateKey: privateKey,
      mnemonic: mnemonic,
      generatedAt: new Date().toISOString(),
    };

    // Display wallet information
    console.log("🔐 Wallet Generated Successfully!");
    console.log("==================================");
    console.log(`📧 Address: ${address}`);
    console.log(`🔑 Private Key: ${privateKey}`);
    if (mnemonic) {
      console.log(`📝 Mnemonic: ${mnemonic}`);
    }
    console.log(`⏰ Generated at: ${walletInfo.generatedAt}`);
    console.log("==================================");

    // Create deployments directory if it doesn't exist
    const deploymentsDir = path.join(__dirname, "deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    // Save wallet info to file
    const timestamp = Date.now();
    const filename = `wallet-${timestamp}.json`;
    const filepath = path.join(deploymentsDir, filename);

    fs.writeFileSync(filepath, JSON.stringify(walletInfo, null, 2));
    console.log(`💾 Wallet info saved to: ${filepath}`);

    // Create .env template
    const envTemplate = `# Generated wallet private key
PRIVATE_KEY=${privateKey}

# Network RPC URLs (uncomment and modify as needed)
# BASE_MAINNET_RPC=https://mainnet.base.org
# BASE_SEPOLIA_RPC=https://sepolia.base.org

# Etherscan API Key (for contract verification)
# ETHERSCAN_API_KEY=your_etherscan_api_key_here
`;

    const envPath = path.join(__dirname, "..", ".env.example");
    fs.writeFileSync(envPath, envTemplate);
    console.log(`📄 .env.example template created at: ${envPath}`);

    console.log("\n⚠️  IMPORTANT SECURITY NOTES:");
    console.log("1. Keep your private key secure and never share it");
    console.log("2. Copy the private key to your .env file");
    console.log("3. Never commit .env files to version control");
    console.log("4. Consider using a hardware wallet for production");
  } catch (error) {
    console.error("❌ Error generating wallet:", error);
    process.exit(1);
  }
}

// Run the script
generateWallet()
  .then(() => {
    console.log("\n✅ Wallet generation completed!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Script failed:", error);
    process.exit(1);
  });
