import { ethers } from "hardhat";

async function main() {
  // MAINNET
  // const feeReceiver = "0xf59E87c6B05d047aED4941ff00dD841BD0874D7f"; // dirección que recibirá las fees
  // const uniswapRouter = "0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24"; // dirección del router en base sepolia

  // SEPOLIA
  const feeReceiver = "0x8Fd7a6a86EacFe6b159fd253f9de3895B8e1B72C"; // dirección que recibirá las fees
  const uniswapRouter = "0x1689E7B1F10000AE47eBfE339a4f69dECd19F602"; // dirección del router en base sepolia

  // 1. Obtener el contrato (compilará automáticamente)
  const FeeSwapWrapper = await ethers.getContractFactory("FeeSwapWrapper");

  // 2. Desplegar el contrato
  const contract = await FeeSwapWrapper.deploy(uniswapRouter, feeReceiver);
  await contract.deployed();

  console.log("FeeSwapWrapper deployed to:", contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
