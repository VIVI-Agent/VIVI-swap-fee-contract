# VIVIMixedBatchTransfer

Un contrato inteligente que permite realizar transferencias en lote de tokens ERC20 y ETH de forma simultánea a múltiples destinatarios en una sola transacción.

## Características

- ✅ Transferencia simultánea de tokens ERC20 y ETH
- ✅ Soporte para 1 a N destinatarios
- ✅ Transferencias con cantidades variables o iguales
- ✅ Transferencias solo de ETH
- ✅ Protección contra reentrancy
- ✅ Control de acceso con Ownable
- ✅ Funciones de emergencia para recuperar fondos
- ✅ Límite configurable de destinatarios por lote
- ✅ Sistema de autorización de tokens (opcional)
- ✅ Eventos detallados para tracking
- ✅ Reembolso automático de ETH sobrante

## Funciones Principales

### `mixedBatchTransfer`

Transfiere tokens ERC20 y ETH a múltiples destinatarios con cantidades variables.

```solidity
function mixedBatchTransfer(
    address token,
    MixedTransferData[] calldata transfers
) external payable
```

**Parámetros:**

- `token`: Dirección del contrato ERC20
- `transfers`: Array de estructuras con destinatario, cantidad de tokens y cantidad de ETH

### `mixedBatchTransferEqual`

Transfiere la misma cantidad de tokens ERC20 y ETH a múltiples destinatarios.

```solidity
function mixedBatchTransferEqual(
    address token,
    address[] calldata recipients,
    uint256 tokenAmountEach,
    uint256 ethAmountEach
) external payable
```

### `batchTransferETH`

Transfiere solo ETH a múltiples destinatarios con cantidades variables.

```solidity
function batchTransferETH(
    address[] calldata recipients,
    uint256[] calldata amounts
) external payable
```

### `batchTransferETHEqual`

Transfiere la misma cantidad de ETH a múltiples destinatarios.

```solidity
function batchTransferETHEqual(
    address[] calldata recipients,
    uint256 amountEach
) external payable
```

## Estructura de Datos

### `MixedTransferData`

```solidity
struct MixedTransferData {
    address recipient;     // Dirección del destinatario
    uint256 tokenAmount;   // Cantidad de tokens ERC20 a transferir
    uint256 ethAmount;     // Cantidad de ETH a transferir
}
```

## Eventos

```solidity
// Emitido cuando se completa una transferencia mixta en lote
event MixedBatchTransferCompleted(
    address indexed token,
    address indexed sender,
    uint256 totalTokenAmount,
    uint256 totalEthAmount,
    uint256 recipientCount
);

// Emitido cuando falla una transferencia individual
event SingleMixedTransferFailed(
    address indexed recipient,
    uint256 tokenAmount,
    uint256 ethAmount,
    string reason
);

// Emitido cuando falla una transferencia de ETH
event ETHTransferFailed(
    address indexed recipient,
    uint256 amount,
    string reason
);
```

## Funciones de Vista

### `calculateTotalAmounts`

Calcula el total de tokens y ETH necesarios para una transferencia mixta.

```solidity
function calculateTotalAmounts(
    MixedTransferData[] calldata transfers
) external pure returns (uint256 totalTokenAmount, uint256 totalEthAmount)
```

### `canPerformMixedBatchTransfer`

Verifica si una dirección puede realizar una transferencia mixta en lote.

```solidity
function canPerformMixedBatchTransfer(
    address sender,
    address token,
    uint256 totalTokenAmount,
    uint256 totalEthAmount
) external view returns (bool)
```

## Funciones de Administración

- `authorizeToken(address token)`: Autoriza un token (solo owner)
- `unauthorizeToken(address token)`: Desautoriza un token (solo owner)
- `setOnlyAuthorizedTokens(bool)`: Activa/desactiva modo de tokens autorizados
- `setMaxRecipientsPerBatch(uint256)`: Establece límite de destinatarios
- `emergencyWithdraw(address, uint256)`: Recupera tokens (solo owner)
- `emergencyWithdrawETH()`: Recupera ETH (solo owner)

## Requisitos

1. **Para tokens ERC20**: El usuario debe aprobar al contrato para gastar los tokens
2. **Para ETH**: El usuario debe enviar suficiente ETH con la transacción
3. **Gas**: Las transacciones consumen más gas con más destinatarios

## Ejemplos de Uso

### Ejemplo 1: Transferencia Mixta con Cantidades Variables

```javascript
const transfers = [
  {
    recipient: "0x1234...",
    tokenAmount: ethers.parseEther("10"), // 10 tokens
    ethAmount: ethers.parseEther("0.1"), // 0.1 ETH
  },
  {
    recipient: "0x5678...",
    tokenAmount: ethers.parseEther("20"), // 20 tokens
    ethAmount: ethers.parseEther("0.2"), // 0.2 ETH
  },
];

// Aprobar tokens primero
await token.approve(contractAddress, ethers.parseEther("30"));

// Realizar transferencia
await contract.mixedBatchTransfer(tokenAddress, transfers, {
  value: ethers.parseEther("0.3"), // Total ETH necesario
});
```

### Ejemplo 2: Transferencia Mixta con Cantidades Iguales

```javascript
const recipients = ["0x1234...", "0x5678...", "0x9abc..."];
const tokenAmountEach = ethers.parseEther("5"); // 5 tokens cada uno
const ethAmountEach = ethers.parseEther("0.05"); // 0.05 ETH cada uno

await contract.mixedBatchTransferEqual(
  tokenAddress,
  recipients,
  tokenAmountEach,
  ethAmountEach,
  { value: ethers.parseEther("0.15") } // 0.05 * 3 = 0.15 ETH total
);
```

### Ejemplo 3: Solo ETH

```javascript
const recipients = ["0x1234...", "0x5678..."];
const amounts = [ethers.parseEther("0.1"), ethers.parseEther("0.2")];

await contract.batchTransferETH(recipients, amounts, {
  value: ethers.parseEther("0.3"), // Total ETH
});
```

## Seguridad

- ✅ Protección contra reentrancy con `ReentrancyGuard`
- ✅ Validación de direcciones (no zero address)
- ✅ Validación de cantidades (mayor a 0)
- ✅ Verificación de balances antes de transferir
- ✅ Manejo de errores con try/catch para tokens
- ✅ Reembolso automático de ETH sobrante
- ✅ Funciones de emergencia para recuperar fondos

## Limitaciones

- El límite de destinatarios por lote es configurable (default: 500)
- Las transferencias de tokens requieren aprobación previa
- Consumo de gas aumenta linealmente con el número de destinatarios
- Si una transferencia falla, se emite un evento pero no se revierte toda la transacción

## Scripts Disponibles

### Deployment

```bash
npx hardhat run scripts/mixed-batch/deploy-vivi-mixed-batch-transfer.ts --network base-sepolia
```

### Verificación

```bash
npx hardhat run scripts/mixed-batch/verify-deployment.ts --network base-sepolia
```

### Ejemplo de Uso

```bash
npx hardhat run scripts/mixed-batch/example-mixed-batch-transfer.ts --network  base-sepolia
```

## Costos de Gas Estimados

| Operación  | 1 destinatario | 5 destinatarios | 10 destinatarios |
| ---------- | -------------- | --------------- | ---------------- |
| Solo ETH   | ~65,000        | ~85,000         | ~125,000         |
| Solo ERC20 | ~75,000        | ~95,000         | ~135,000         |
| Mixto      | ~85,000        | ~115,000        | ~165,000         |

_Los costos pueden variar según la red y la complejidad del token ERC20_
