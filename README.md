# VIVI Swap Fee Contracts 🚫 Deprecated

> **Status: Deprecated**  
> This repository is no longer actively maintained. Kept public for portfolio and historical reference.

Hardhat project containing the **fee-on-swap wrapper contracts** used by the VIVI Telegram trading bot on **Base**.

These contracts wrap Uniswap V2, Uniswap V3, Aerodrome, and other venues to charge a small ETH fee on swaps executed through the bot.

## Contracts

- `VIVIUniswapV2.sol`
- `VIVIUniswapV3.sol`
- `VIVIAerodrome.sol`
- `VIVIApestore.sol`
- `VIVIVirtualsHop.sol`
- `VIVIZoraMultiHop.sol`
- Batch transfer helpers (`VIVIBatchTransfer`, `VIVIBatchETHTransfer`, etc.)

## Tech Stack

- Hardhat
- Solidity 0.8.x
- OpenZeppelin
- Ethers.js

## Networks

- Base Mainnet
- Base Sepolia

## Related Repositories

- Main project overview: [VIVI-Agent/vivi](https://github.com/VIVI-Agent/vivi)
- Telegram bot: [VIVI-Agent/VIVI-telegram-bot](https://github.com/VIVI-Agent/VIVI-telegram-bot)
- Token contracts: [VIVI-Agent/VIVI-token-contracts](https://github.com/VIVI-Agent/VIVI-token-contracts)

## Links

- Telegram Bot: [t.me/VIVIBaseBot](https://t.me/VIVIBaseBot)
- X / Twitter: [@vividotwin](https://x.com/vividotwin)

---

*Part of the VIVI trading agent (2024–2025).*
