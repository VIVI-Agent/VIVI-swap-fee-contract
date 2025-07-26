import { ethers } from "hardhat";

const ROUTER_ADDRESS = "0xc750af290bb41ca5dec04f22cd1318e940dd826a"; // ApeStore router (probable owner)
const SIGMA_CONTRACT = "0x62806E8Fa86FE4879606F2575FDC7136351f8D5d"; // dirección del contrato Sigma

const APE_ROUTER_ABI = ["function AllowedProxies(address) view returns (bool)"];

async function main() {
  const [signer] = await ethers.getSigners();

  const router = new ethers.Contract(ROUTER_ADDRESS, APE_ROUTER_ABI, signer);

  const isAllowed = await router.AllowedProxies(SIGMA_CONTRACT);

  console.log(`✅ Is AllowedProxies? ${isAllowed}`);
}

main().catch((err) => {
  console.error("❌ Error:", err);
  process.exit(1);
});
