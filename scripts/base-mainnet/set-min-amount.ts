import { ethers } from "hardhat";

async function setMinAmount() {
  console.log("🔧 Setting minimum amount per recipient to 1 wei...");

  const [deployer] = await ethers.getSigners();
  console.log("📋 Using account:", deployer.address);

  // Contract address on Base mainnet
  const contractAddress = "0xDECa2416e84dF2CB0A2482977cDf9365CE65Ed2E";

  // Get contract instance
  const VIVIBotBatchFunder = await ethers.getContractFactory(
    "VIVIBotBatchFunder"
  );
  const batchFunder = VIVIBotBatchFunder.attach(contractAddress);

  try {
    // Check current minimum amount
    const currentMinAmount = await batchFunder.minAmountPerRecipient();
    console.log(
      `📊 Current minimum amount: ${ethers.utils.formatEther(
        currentMinAmount
      )} ETH`
    );

    // Set new minimum amount to 1 wei
    const newMinAmount = 1n; // 1 wei
    console.log(`🔄 Setting new minimum amount to: ${newMinAmount} wei`);

    const tx = await batchFunder.setMinAmountPerRecipient(newMinAmount);
    console.log(`📤 Transaction sent: ${tx.hash}`);

    // Wait for transaction confirmation
    const receipt = await tx.wait();
    console.log(`✅ Transaction confirmed in block: ${receipt.blockNumber}`);

    // Verify the change
    const updatedMinAmount = await batchFunder.minAmountPerRecipient();
    console.log(
      `🎉 New minimum amount: ${updatedMinAmount} wei (${ethers.utils.formatEther(
        updatedMinAmount
      )} ETH)`
    );

    // Test that we can now use small amounts
    const testAmount = ethers.utils.parseEther("0.0000001"); // 0.0000001 ETH
    console.log(
      `\n🧪 Testing with amount: ${ethers.utils.formatEther(testAmount)} ETH`
    );

    if (testAmount >= updatedMinAmount) {
      console.log("✅ Amount is now valid for batch funding!");
    } else {
      console.log("❌ Amount is still too small");
    }
  } catch (error: any) {
    console.error("❌ Error setting minimum amount:", error.message);
    process.exit(1);
  }
}

setMinAmount()
  .then(() => {
    console.log("🎉 Minimum amount updated successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Script failed:", error);
    process.exit(1);
  });
