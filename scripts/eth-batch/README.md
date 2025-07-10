# VIVIBatchETHTransfer

Contrato para realizar transferencias en batch de ETH nativo a múltiples destinatarios en una sola transacción.

## 🚀 Características

- **Transferencias iguales**: Envía la misma cantidad de ETH a múltiples recipients
- **Transferencias personalizadas**: Envía cantidades específicas a cada recipient
- **Reembolso automático**: Devuelve el ETH sobrante al remitente
- **Límites configurables**: Máximo de recipients por batch (500 por defecto)
- **Funciones de emergencia**: Para recuperar ETH enviado accidentalmente
- **Seguridad**: Protección contra reentrancy y validaciones

## 📄 Funciones principales

### `batchETHTransferEqual`

Transfiere la misma cantidad de ETH a múltiples destinatarios.

```solidity
function batchETHTransferEqual(
    address[] calldata recipients,
    uint256 ethAmountEach
) external payable
```

**Parámetros:**

- `recipients`: Array de direcciones destinatarias
- `ethAmountEach`: Cantidad de ETH a transferir a cada destinatario (en wei)

### `batchETHTransferCustom`

Transfiere cantidades específicas de ETH a múltiples destinatarios.

```solidity
function batchETHTransferCustom(
    address[] calldata recipients,
    uint256[] calldata amounts
) external payable
```

**Parámetros:**

- `recipients`: Array de direcciones destinatarias
- `amounts`: Array de cantidades de ETH para cada destinatario (en wei)

## 🛠️ Despliegue

1. **Compilar el contrato:**

```bash
npx hardhat compile
```

2. **Desplegar:**

```bash
npx hardhat run scripts/eth-batch/deploy-vivi-batch-eth-transfer.ts --network <red>
```

3. **Verificar el despliegue:**
   El script guardará la información del despliegue en `scripts/eth-batch/deployments/`

## 📝 Ejemplo de uso

1. **Configurar el script de ejemplo:**
   Edita `scripts/eth-batch/example-batch-eth-transfer.ts` y configura:

- `CONTRACT_ADDRESS`: Dirección del contrato desplegado
- `TEST_RECIPIENTS`: Direcciones de prueba

2. **Ejecutar el ejemplo:**

```bash
npx hardhat run scripts/eth-batch/example-batch-eth-transfer.ts --network <red>
```

## 🔧 Funciones auxiliares

### Cálculo de totales

```solidity
// Para transferencias iguales
function calculateTotalEthAmount(uint256 recipientCount, uint256 ethAmountEach)
    external pure returns (uint256 totalEthAmount)

// Para transferencias personalizadas
function calculateTotalEthAmountCustom(uint256[] calldata amounts)
    external pure returns (uint256 totalEthAmount)
```

### Verificación de capacidad

```solidity
function canPerformBatchTransfer(address sender, uint256 totalEthAmount)
    external view returns (bool)
```

## ⚙️ Administración

### Configurar límite de recipients

```solidity
function setMaxRecipientsPerBatch(uint256 _maxRecipients) external onlyOwner
```

### Funciones de emergencia

```solidity
// Recuperar ETH enviado accidentalmente
function emergencyWithdrawETH() external onlyOwner
```

## 🎯 Casos de uso

- **Distribución de recompensas**: Enviar ETH a múltiples usuarios por participación
- **Pago masivo**: Realizar pagos a múltiples empleados o contratistas
- **Airdrop de ETH**: Distribuir ETH nativo a holders de tokens
- **Reembolsos**: Devolver ETH a múltiples usuarios
- **Financiamiento**: Enviar ETH inicial a múltiples wallets

## 💡 Ejemplo práctico

```typescript
// Transferir 0.01 ETH a 3 recipients
const recipients = [
  "0x742d35Cc6634C0532925a3b8D4C0d5AF8E20a1A4",
  "0x8ba1f109551bD432803012645Hac136c5c4b2Eba",
  "0x0000000000000000000000000000000000000001",
];

const ethAmountEach = ethers.utils.parseEther("0.01"); // 0.01 ETH
const totalRequired = ethAmountEach.mul(recipients.length); // 0.03 ETH

await contract.batchETHTransferEqual(recipients, ethAmountEach, {
  value: totalRequired,
});
```

## ⚠️ Consideraciones importantes

1. **Gas**: El gas aumenta linealmente con el número de recipients
2. **Límites de bloque**: Considerar el límite de gas por bloque para batches grandes
3. **ETH requerido**: Debes enviar al menos el total de ETH necesario
4. **Direcciones válidas**: Todas las direcciones deben ser válidas (no zero address)
5. **Reembolso**: El ETH sobrante se devuelve automáticamente

## 📊 Gas aproximado

- Deployment: ~600,000 gas
- Transfer igual (10 recipients): ~150,000 gas
- Transfer personalizado (10 recipients): ~160,000 gas

## 🔐 Seguridad

- ✅ Protección contra reentrancy
- ✅ Validación de parámetros
- ✅ Límites configurables
- ✅ Funciones de emergencia
- ✅ Ownership con OpenZeppelin
