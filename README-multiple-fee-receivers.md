# VIVI Wrappers - Múltiples Fee Receptors

## Resumen de Cambios

Se ha implementado un sistema de distribución de fees a múltiples receptores en todos los wrappers de VIVI. Ahora es posible distribuir el fee total entre varios receptores con porcentajes configurables.

## Nueva Funcionalidad

### VIVIFeeManager (Contrato Base)

Se creó un contrato base `VIVIFeeManager` que maneja la distribución de fees:

```solidity
struct FeeReceiver {
    address receiver;
    uint256 bps; // basis points (100 = 1%)
}
```

**Funciones principales:**

- `_distributeFees()`: Distribuye fees a receptores adicionales
- `_sendToDefaultReceiver()`: Envía el fee restante al receptor por defecto
- `_validateFeeReceivers()`: Valida que los receptores sean válidos
- `setDefaultFeeReceiver()`: Permite cambiar el receptor por defecto

### Wrappers Modificados

Todos los wrappers ahora heredan de `VIVIFeeManager` y soportan múltiples fee receptors:

1. **VIVIUniswapV2**
2. **VIVIUniswapV3**
3. **VIVIAerodrome**
4. **VIVIApeStore**
5. **VIVIVirtualsHop**
6. **VIVIZoraMultiHop**

## Cómo Funciona

### Distribución de Fees

1. **Fee Total**: Se calcula basado en el `feeBps` (ej: 100 = 1%)
2. **Receptores Adicionales**: Reciben su porcentaje del fee total
3. **Receptor por Defecto**: Recibe el monto restante

### Ejemplo de Distribución

Si el fee total es 1 ETH con `feeBps = 100` (1%) y hay 2 receptores adicionales:

- Receptor 1: 10% (1000 bps) = 0.1 ETH
- Receptor 2: 30% (3000 bps) = 0.3 ETH
- Receptor por defecto: 60% restante = 0.6 ETH

## Uso de las Funciones

### Función VIVIBuy (Ejemplo con UniswapV2)

```typescript
const feeReceivers = [
  {
    receiver: "0x1234567890123456789012345678901234567890",
    bps: 1000, // 10%
  },
  {
    receiver: "0x0987654321098765432109876543210987654321",
    bps: 3000, // 30%
  },
];

await viviUniswapV2.VIVIBuy(
  {
    path: [WETH_ADDRESS, TOKEN_ADDRESS],
    amountIn: 0,
    recipient: USER_ADDRESS,
    deadline: Math.floor(Date.now() / 1000) + 300,
  },
  100, // 1% fee total
  5, // 5% slippage
  feeReceivers // Array de receptores adicionales
);
```

### Función VIVISell (Ejemplo con UniswapV2)

```typescript
await viviUniswapV2.VIVISell(
  {
    path: [TOKEN_ADDRESS, WETH_ADDRESS],
    amountIn: ethers.parseEther("100"),
    recipient: USER_ADDRESS,
    deadline: Math.floor(Date.now() / 1000) + 300,
  },
  100, // 1% fee total
  5, // 5% slippage
  feeReceivers // Array de receptores adicionales
);
```

## Validaciones

### Restricciones de BPS

- La suma de BPS de los receptores adicionales no puede exceder 10000 (100%)
- Cada receptor debe tener BPS > 0
- Las direcciones de los receptores no pueden ser address(0)

### Compatibilidad

- Si no se proporcionan receptores adicionales (array vacío), todo el fee va al receptor por defecto
- Mantiene compatibilidad con el comportamiento anterior

## Eventos

### FeeDistributed

Se emite cuando hay receptores adicionales:

```solidity
event FeeDistributed(
    address indexed user,
    uint256 totalFeeAmount,
    address[] receivers,
    uint256[] amounts
);
```

### DefaultFeeReceiverUpdated

Se emite cuando se actualiza el receptor por defecto:

```solidity
event DefaultFeeReceiverUpdated(address indexed newFeeReceiver);
```

## Migración

### Para Usuarios Existentes

Los contratos existentes mantienen compatibilidad:

- Si no se pasan receptores adicionales, funciona como antes
- El receptor por defecto sigue siendo configurable
- Todas las funciones existentes siguen funcionando

### Para Nuevos Deployments

Los nuevos deployments requieren:

1. Deploy del `VIVIFeeManager` o usar los wrappers actualizados
2. Configurar el receptor por defecto en el constructor
3. Opcionalmente, pasar receptores adicionales en las llamadas

## Archivos Modificados

### Nuevos Archivos

- `contracts/utils/VIVIFeeManager.sol` - Contrato base para manejo de fees
- `scripts/example-multiple-fee-receivers.ts` - Ejemplo de uso

### Archivos Actualizados

- `contracts/wrappers/VIVIUniswapV2.sol`
- `contracts/wrappers/VIVIUniswapV3.sol`
- `contracts/wrappers/VIVIAerodrome.sol`
- `contracts/wrappers/VIVIApestore.sol`
- `contracts/wrappers/VIVIVirtualsHop.sol`
- `contracts/wrappers/VIVIZoraMultiHop.sol`

## Beneficios

1. **Flexibilidad**: Permite distribuir fees a múltiples partes
2. **Transparencia**: Eventos claros para tracking de distribución
3. **Compatibilidad**: No rompe funcionalidad existente
4. **Escalabilidad**: Fácil agregar más receptores en el futuro
5. **Consistencia**: Misma interfaz en todos los wrappers

## Consideraciones de Seguridad

- Validación de direcciones de receptores
- Límites en BPS para prevenir overflow
- Manejo de errores en transferencias
- Reentrancy protection mantenida
- Ownership controls para configuración
