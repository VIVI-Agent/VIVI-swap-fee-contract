# VIVI Virtuals Wrapper

Un wrapper para realizar swaps multi-hop a través de Virtuals Protocol en Uniswap V2.

## Routing

### Buy (Compra): ETH → VIRTUAL → TOKEN

- ETH → VIRTUAL (usando Uniswap V2)
- VIRTUAL → TOKEN (usando Uniswap V2)

### Sell (Venta): TOKEN → VIRTUAL → ETH

- TOKEN → VIRTUAL (usando Uniswap V2)
- VIRTUAL → ETH (usando Uniswap V2)

## Addresses

- **VIRTUAL Token**: `0x0b3e328455c4059eeb9e3f84b5543f74e24e7e1b`
- **VIRTUAL/WETH Pool**: `0x9c087eb773291e50cf6c6a90ef0f4500e349b903`
- **Uniswap V2 Router**: `0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24` (Base)

## Deployment

```bash
# Compilar contratos
npx hardhat compile

# Deploy en Base Mainnet
npx hardhat run scripts/virtuals/0_deploy.ts --network base-mainnet
```

## Usage Examples

### Buy Tokens

```bash
# Configurar y ejecutar ejemplo de compra
npx hardhat run scripts/virtuals/1_buy_example.ts --network base-mainnet
```

### Sell Tokens

```bash
# Configurar y ejecutar ejemplo de venta
npx hardhat run scripts/virtuals/2_sell_example.ts --network base-mainnet
```

## Contract Interface

### VIVIVirtualsBuy

Compra tokens usando ETH:

```solidity
function VIVIVirtualsBuy(
    MultiHopParams calldata params,
    uint256 feeBps
) external payable nonReentrant
```

**Parámetros:**

- `params.tokenTarget`: Dirección del token a comprar
- `params.recipient`: Dirección que recibirá los tokens
- `params.deadline`: Timestamp límite para la transacción
- `params.slippagePercent`: Porcentaje de slippage tolerado (0-50%)
- `feeBps`: Fee en basis points (máx 100 = 1%)

### VIVIVirtualsSell

Vende tokens por ETH:

```solidity
function VIVIVirtualsSell(
    MultiHopParams calldata params,
    uint256 feeBps
) external nonReentrant
```

**Parámetros:**

- `params.tokenTarget`: Dirección del token a vender
- `params.recipient`: Dirección que recibirá el ETH
- `params.deadline`: Timestamp límite para la transacción
- `params.slippagePercent`: Porcentaje de slippage tolerado (0-50%)
- `params.amountIn`: Cantidad de tokens a vender
- `feeBps`: Fee en basis points (máx 100 = 1%)

## Events

### Buy Event

```solidity
event Buy(
    address indexed user,
    address tokenOut,
    uint256 ethIn,
    uint256 ethInAfterFee,
    uint256 tokensOut,
    uint256 feeAmount
);
```

### Sell Event

```solidity
event Sell(
    address indexed user,
    address tokenIn,
    uint256 tokensIn,
    uint256 ethOut,
    uint256 ethOutAfterFee,
    uint256 feeAmount
);
```

## Important Notes

1. **Fees**: El contrato cobra un fee adicional en ETH (máximo 1%)
2. **Slippage**: Usar `slippagePercent` para especificar el porcentaje de slippage tolerado (0-50%)
3. **Approval**: Para sell, el usuario debe aprobar tokens al contrato primero
4. **Deadlines**: Usar deadlines apropiados (ej: 5-10 minutos desde now)
5. **Uniswap V2**: Este contrato usa Uniswap V2 router, no V3 - sin fee tiers específicos
6. **Multi-hop**: Las rutas usan arrays de direcciones, no encoded paths como V3

## Comparison with Zora

| Feature                 | Zora                    | Virtuals                  |
| ----------------------- | ----------------------- | ------------------------- |
| **DEX Version**         | Uniswap V3              | Uniswap V2                |
| **Hops**                | 4 (ETH→USDC→ZORA→TOKEN) | 3 (ETH→VIRTUAL→TOKEN)     |
| **Pool Fees**           | 0.05%, 0.3%, 1%         | Standard V2 (0.3%)        |
| **Intermediate Tokens** | USDC, ZORA              | VIRTUAL                   |
| **Gas Usage**           | Higher (más hops + V3)  | Lower (menos hops + V2)   |
| **Path Encoding**       | Bytes (V3 style)        | Address arrays (V2)       |
| **Slippage Control**    | `amountOutMin` fixed    | `slippagePercent` (0-50%) |
| **Router Contract**     | ISwapRouter (V3)        | IUniswapV2Router02        |

## Security

- ✅ ReentrancyGuard protección
- ✅ Ownable para funciones admin
- ✅ Validaciones de input
- ✅ Fee límites (máx 1%)
- ✅ Error handling con try/catch
