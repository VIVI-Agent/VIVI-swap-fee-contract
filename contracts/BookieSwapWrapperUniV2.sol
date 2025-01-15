// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BookieSwapWrapperUniV2
 * @notice Este contrato permite hacer swaps en Uniswap V2 con posibilidad de cobrar un fee en ETH.
 *         Maneja de forma especial tokens deflacionarios (fee on transfer) calculando el monto real transferido.
 */
contract BookieSwapWrapperUniV2 is ReentrancyGuard, Ownable {
    /**
     * @dev Estructura para los parámetros de swap. Se define 'path' para soportar multi-hop.
     *      - path[0] será el tokenIn.
     *      - path[path.length - 1] será el tokenOut.
     *      - amountIn es la cantidad de tokens que el usuario *pretende* transferir si es swapTokensForETH
     *        (con tokens deflacionarios esta puede ser mayor al monto que realmente llega al contrato).
     */
    struct SwapParams {
        address[] path; // Camino (tokens) para el swap, ej: [tokenA, WETH, tokenB]
        uint256 amountIn; // Cantidad de tokens que el usuario desea swappear (en swapTokensForETH)
        address recipient; // Destinatario final de los tokens (o ETH) después del swap
        uint256 deadline; // Fecha/hora (timestamp) límite para el swap
    }

    // Variables públicas
    address public feeReceiver;
    IUniswapV2Router02 public uniswapRouter;

    // Eventos
    event FeeReceiverUpdated(address indexed newFeeReceiver);
    event RouterUpdated(address indexed newRouter);
    event SwapTokensForETH(
        address indexed sender,
        address tokenIn,
        uint256 amountIn,
        uint256 ethReceived,
        uint256 ethAfterFee,
        uint256 feeAmount
    );
    event SwapETHForTokens(
        address indexed sender,
        address tokenOut,
        uint256 ethIn,
        uint256 tokensReceived,
        uint256 feeAmount
    );

    /**
     * @param _router Dirección del router de Uniswap (por ejemplo en Sepolia).
     * @param _feeReceiver Dirección que recibe el fee.
     */
    constructor(address _router, address _feeReceiver) Ownable(msg.sender) {
        require(_router != address(0), "Router address invalid");
        require(_feeReceiver != address(0), "Fee receiver invalid");

        uniswapRouter = IUniswapV2Router02(_router);
        feeReceiver = _feeReceiver;
    }

    /**
     * @notice Actualiza la dirección del receptor de fees (solo el owner).
     */
    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        require(_feeReceiver != address(0), "Invalid feeReceiver address");
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdated(_feeReceiver);
    }

    /**
     * @notice Actualiza la dirección del router de Uniswap, en caso de que uses otro DEX.
     */
    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router address");
        uniswapRouter = IUniswapV2Router02(_router);
        emit RouterUpdated(_router);
    }

    /**
     * @dev Calcula el fee en base 10000 (basis points):
     *      50 => 0.50%, 100 => 1.00%, etc.
     */
    function _calculateFee(
        uint256 amount,
        uint256 feeBps
    ) internal pure returns (uint256) {
        return (amount * feeBps) / 10000;
    }

    /**
     * @notice swapTokensForETH con soporte a fee on transfer.
     * @dev Usa 'swapExactTokensForETHSupportingFeeOnTransferTokens' del router.
     *      Calculamos la cantidad de ETH recibida como la diferencia de balance
     *      en el contrato antes y después del swap.
     *
     * @param params Parámetros estructurados del swap (ver `SwapParams`).
     * @param feeBps Fee en basis points (ej. 50 => 0.50%, 100 => 1.00%).
     * @param slippagePercent Slippage permitido (máximo 50% => 50).
     */
    function swapTokensForETHWithFee(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent
    ) external nonReentrant {
        // Validaciones básicas
        require(params.path.length >= 2, "Path must have at least 2 tokens");
        address tokenIn = params.path[0];
        address tokenOut = params.path[params.path.length - 1];

        // Asegurarnos que sea WETH al final, si queremos ETH resultante
        require(
            tokenOut == uniswapRouter.WETH(),
            "Last token in path must be WETH for ETH swap"
        );

        require(feeBps <= 100, "Fee too high");
        require(slippagePercent <= 50, "Slippage too high");
        require(params.amountIn > 0, "AmountIn must be > 0");

        IERC20 token = IERC20(tokenIn);

        // *** 1) Transferir tokens del usuario al contrato ***
        uint256 balanceBefore = token.balanceOf(address(this));
        // Algunas implementaciones de ERC20 devuelven bool en transferFrom. Verificamos:
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );
        require(success, "Token transferFrom failed");

        // Calculamos el monto real que llegó al contrato (tokens deflacionarios)
        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 realAmountIn = balanceAfter - balanceBefore;
        require(
            realAmountIn > 0,
            "No tokens received; check deflationary token transfer"
        );

        // *** 2) Aprobación al router si la allowance es menor al realAmountIn ***
        uint256 currentAllowance = token.allowance(
            address(this),
            address(uniswapRouter)
        );
        if (currentAllowance < realAmountIn) {
            // Se suele usar una aprobación "infinita", pero podrías usar sólo realAmountIn
            token.approve(address(uniswapRouter), type(uint256).max);
        }

        // *** 3) Calcular el mínimo de ETH esperado (con slippage) usando getAmountsOut ***
        uint256 amountOutMin = 0;
        try uniswapRouter.getAmountsOut(realAmountIn, params.path) returns (
            uint256[] memory amounts
        ) {
            uint256 expectedEth = amounts[amounts.length - 1];
            // Aplicas slippage
            amountOutMin = (expectedEth * (100 - slippagePercent)) / 100;
        } catch {
            // Si falla, la dejas en 0
            amountOutMin = 0;
        }

        // 4) Medir balance ETH antes
        uint256 ethBalanceBefore = address(this).balance;

        // 5) Llamar 'swapExactTokensForETHSupportingFeeOnTransferTokens'
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            realAmountIn,
            amountOutMin,
            params.path,
            address(this),
            params.deadline
        );

        // 6) Medir balance ETH después
        uint256 ethBalanceAfter = address(this).balance;
        uint256 ethReceived = ethBalanceAfter - ethBalanceBefore;
        require(ethReceived > 0, "No ETH received");

        // Calcular fee en ETH => base 10000
        uint256 feeAmount = _calculateFee(ethReceived, feeBps);
        uint256 ethAfterFee = ethReceived - feeAmount;

        // 8) Enviar fee
        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer failed");

        // *** 6) Enviar el ETH restante al destinatario final ***
        (bool successEth, ) = params.recipient.call{value: ethAfterFee}("");
        require(successEth, "ETH transfer failed");

        // 10) Emitir evento
        emit SwapTokensForETH(
            msg.sender,
            tokenIn,
            params.amountIn,
            ethReceived,
            ethAfterFee,
            feeAmount
        );
    }

    /**
     * @notice swapETHForTokensWithFee cobra el fee en ETH antes de hacer el swap.
     * @param params Parámetros estructurados.
     * @param feeBps Fee en basis points (ej. 50 => 0.50%, 100 => 1.00%).
     * @param slippagePercent Slippage permitido (máximo 50%).
     */
    function swapETHForTokensWithFee(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent
    ) external payable nonReentrant {
        require(params.path.length >= 2, "Path must have at least 2 tokens");
        address tokenOut = params.path[params.path.length - 1];
        require(
            params.path[0] == uniswapRouter.WETH(),
            "First token in path must be WETH for ETH swap"
        );

        // feeBps <= 100 => hasta 1.00%
        require(feeBps <= 100, "Fee too high");
        require(slippagePercent <= 50, "Slippage too high");
        require(msg.value > 0, "ETH amount must be > 0");

        // 1) Calcular fee (en ETH)
        uint256 feeAmount = _calculateFee(msg.value, feeBps);
        uint256 amountAfterFee = msg.value - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer failed");

        // 2) Calcular amountOutMin con slippage
        uint256 amountOutMin = 0;
        try uniswapRouter.getAmountsOut(amountAfterFee, params.path) returns (
            uint256[] memory amounts
        ) {
            uint256 expectedTokens = amounts[amounts.length - 1];
            amountOutMin = (expectedTokens * (100 - slippagePercent)) / 100;
        } catch {
            amountOutMin = 0;
        }

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(params.recipient);

        // 3) swapExactETHForTokensSupportingFeeOnTransferTokens
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountAfterFee
        }(amountOutMin, params.path, params.recipient, params.deadline);

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(params.recipient);
        uint256 tokensReceived = balanceAfter - balanceBefore;

        emit SwapETHForTokens(
            msg.sender,
            tokenOut,
            amountAfterFee,
            tokensReceived,
            feeAmount
        );
    }

    // Recibir ETH
    receive() external payable {}
}
