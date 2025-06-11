// scripts/base-mainnet/deploy-vivi-bot-batch-funder.ts

import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  console.log("🚀 Deploying VIVIBotBatchFunder to Base mainnet...");

  // 1. Config - inputs
  const chainName = "base-mainnet";

  // 2. Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📍 Deploying with account:", deployer.address);
  console.log(
    "💰 Account balance:",
    ethers.utils.formatEther(await deployer.getBalance()),
    "ETH"
  );

  // 3. Get contract factory and deploy
  const VIVIBotBatchFunder = await ethers.getContractFactory(
    "VIVIBotBatchFunder"
  );

  console.log("📦 Deploying contract...");
  const contract = await VIVIBotBatchFunder.deploy();
  await contract.deployed();

  console.log("✅ VIVIBotBatchFunder deployed to:", contract.address);

  // 4. Verify deployment by reading contract state
  console.log("\n🔍 Verifying deployment...");
  const owner = await contract.owner();
  const maxRecipients = await contract.maxRecipientsPerBatch();
  const minAmount = await contract.minAmountPerRecipient();

  console.log("   Owner:", owner);
  console.log("   Max recipients per batch:", maxRecipients.toString());
  console.log(
    "   Min amount per recipient:",
    ethers.utils.formatEther(minAmount),
    "ETH"
  );

  // 5. Test batch funding capability for bot use case
  console.log("\n🧪 Testing batch funding capability for bot...");
  const testRecipients = 4; // Bot will fund 4 wallets at once
  const testAmount = ethers.utils.parseEther("0.0000005"); // Amount per wallet for bot

  const [canFund, reason] = await contract.canPerformBatchFunding(
    deployer.address,
    testRecipients,
    testAmount
  );

  console.log(
    `   Can fund ${testRecipients} wallets with ${ethers.utils.formatEther(
      testAmount
    )} ETH each:`,
    canFund
  );
  if (!canFund) {
    console.log("   Reason:", reason);
  }

  const totalRequired = await contract.calculateTotalRequired(
    testRecipients,
    testAmount
  );
  console.log(
    "   Total ETH required for bot burst:",
    ethers.utils.formatEther(totalRequired),
    "ETH"
  );

  // 6. Prepare deployment data
  const outputData = {
    contractName: "VIVIBotBatchFunder",
    chain: chainName,
    address: contract.address,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    deploymentBlock: await ethers.provider.getBlockNumber(),
    maxRecipientsPerBatch: maxRecipients.toString(),
    minAmountPerRecipient: ethers.utils.formatEther(minAmount),
    gasUsedForDeployment: "TBD", // Will be filled later if needed
    optimizedFor: "VIVI Bot - 4 wallet burst funding every 2 seconds",
  };

  // 7. Create deployments directory if it doesn't exist
  const deploymentDir = path.join(__dirname, "deployments");
  if (!fs.existsSync(deploymentDir)) {
    fs.mkdirSync(deploymentDir, { recursive: true });
  }

  // 8. Save deployment info to file
  const deploymentFile = path.join(
    deploymentDir,
    `VIVIBotBatchFunder-${chainName}.json`
  );
  fs.writeFileSync(deploymentFile, JSON.stringify(outputData, null, 2));

  console.log("\n🎉 Deployment completed successfully!");
  console.log("\n📋 Summary:");
  console.log("   Contract Address:", contract.address);
  console.log("   Network: Base Mainnet");
  console.log("   Owner:", owner);
  console.log("   Optimized for: 4 wallets burst funding");
  console.log("   Ready for VIVI bot integration!");

  console.log("\n💾 Deployment info saved to:", deploymentFile);

  console.log("\n📝 Add this to your VIVI bot .env file:");
  console.log(`BATCH_FUNDER_CONTRACT=${contract.address}`);

  console.log("\n🔧 Next steps:");
  console.log("1. Add the contract address to your bot configuration");
  console.log("2. Update WalletManager to use batch funding");
  console.log("3. Test with a small number of transactions first");
  console.log("4. Deploy in burst mode for maximum effect!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("💥 Deployment failed:", error);
    process.exit(1);
  });
