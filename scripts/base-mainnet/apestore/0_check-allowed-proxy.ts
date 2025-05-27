import { ethers } from "hardhat";

const ROUTER_ADDRESS = "0xc750af290bb41ca5dec04f22cd1318e940dd826a"; // ApeStore router (probable owner)
const SIGMA_CONTRACT = "0x743f2f29cdd66242fb27d292ab2cc92f45674635"; // dirección del contrato Sigma

const APE_ROUTER_ABI = ["function AllowedProxies(address) view returns (bool)"];

async function main() {
  const [signer] = await ethers.getSigners();

  const router = new ethers.Contract(ROUTER_ADDRESS, APE_ROUTER_ABI, signer);

  const isAllowed = await router.AllowedProxies(SIGMA_CONTRACT);

  console.log(`✅ Is Sigma allowed as proxy? ${isAllowed}`);
}

main().catch((err) => {
  console.error("❌ Error:", err);
  process.exit(1);
});
