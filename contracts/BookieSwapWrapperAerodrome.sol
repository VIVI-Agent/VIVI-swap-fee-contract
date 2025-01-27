// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BookieSwapWrapperAerodrome
 * @notice Wrapper que permite aplicar una comisión (fee) en swaps vía Aerodrome.
 *         No asume si la pool es "estable" o "volátil"; espera un array de rutas
 *         (Route[]) para que el off-chain decida la configuración exacta.
 */
contract BookieSwapWrapperAerodrome is ReentrancyGuard, Ownable {
    /**
     * @dev Aerodrome usa "Route" con: (from, to, stable, factory).
     *      Ejemplo de 1 hop: [ { from: WETH, to: tokenOut, stable: false, factory: <volatileFactory> } ]
     */
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    /**
     * @dev Para simplificar, definimos 'SwapParams' recibiendo `Route[] routes`.
     *      amountIn, recipient y deadline.
     *      - routes[0].from => tokenIn (o WETH si es swapTokensForETH).
     *      - routes[routes.length-1].to => WETH si quieres terminar en ETH.
     *      - En swapETHForTokens => al revés, routes[0].from = WETH => routes[last].to = tokenOut.
     */
    struct SwapParams {
        Route[] routes;
        uint256 amountIn;
        address recipient;
        uint256 deadline;
    }

    // Interfaz minimal del router de Aerodrome
    IAerodromeRouter public aerodromeRouter;
    address public feeReceiver;

    event FeeReceiverUpdated(address indexed newFeeReceiver);
    event RouterUpdated(address indexed newRouter);

    event SwapTokensForETH(
        address indexed sender,
        address tokenIn,
        uint256 amountInDeclared,
        uint256 ethReceived,
        uint256 feeAmount
    );

    event SwapETHForTokens(
        address indexed sender,
        address tokenOut,
        uint256 ethInDeclared,
        uint256 tokensReceived,
        uint256 feeAmount
    );

    constructor(address _router, address _feeReceiver) Ownable(msg.sender) {
        require(_router != address(0), "Invalid router");
        require(_feeReceiver != address(0), "Invalid feeReceiver");

        aerodromeRouter = IAerodromeRouter(_router);
        feeReceiver = _feeReceiver;

        // Ownable => el msg.sender será el owner.
        // (Si usas OpenZeppelin 4.8+, no necesitas Ownable(msg.sender) en el constructor.)
        _transferOwnership(msg.sender);
    }

    function setFeeReceiver(address _newFeeReceiver) external onlyOwner {
        require(_newFeeReceiver != address(0), "feeReceiver=0");
        feeReceiver = _newFeeReceiver;
        emit FeeReceiverUpdated(_newFeeReceiver);
    }

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "router=0");
        aerodromeRouter = IAerodromeRouter(_router);
        emit RouterUpdated(_router);
    }

    /**
     * @dev Aplica fee en base 10000 (50 => 0.50%, 100 => 1%).
     */
    function _calculateFee(
        uint256 amount,
        uint256 feeBps
    ) internal pure returns (uint256) {
        return (amount * feeBps) / 10000;
    }

    /**
     * @notice swapTokensForETH con fee en ETH, usando la lógica de Aerodrome.
     * @param params.routes => array con Route[], la última debe terminar en WETH.
     * @param feeBps => base 10000 (p.ej 50 => 0.5%)
     * @param slippagePercent => se usa para calcular amountOutMin (ej 10 => 10%)
     */
    function swapTokensForETHWithFee(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent
    ) external nonReentrant {
        require(params.routes.length >= 1, "No routes");
        require(feeBps <= 100, "fee>1% not allowed");
        require(slippagePercent <= 50, "slippage>50% not allowed");

        // 1) Tomamos el tokenIn
        address tokenIn = params.routes[0].from;
        require(tokenIn != address(0), "tokenIn=0");
        // Asumimos que la última ruta.to es WETH => aerodrome unwrap => ETH
        // 2) Transfer tokens al wrapper
        IERC20(tokenIn).transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );
        uint256 realAmountIn = IERC20(tokenIn).balanceOf(address(this));
        require(realAmountIn > 0, "No tokens arrived");

        // 3) Approve router
        IERC20(tokenIn).approve(address(aerodromeRouter), realAmountIn);

        // 4) Calcular amountOutMin => getAmountsOut
        uint256[] memory amountsOut = aerodromeRouter.getAmountsOut(
            realAmountIn,
            params.routes
        );
        uint256 expectedETH = amountsOut[amountsOut.length - 1];
        require(expectedETH > 0, "No route/pool? expectedETH=0");

        uint256 amountOutMin = (expectedETH * (100 - slippagePercent)) / 100;

        // 5) swapExactTokensForETHSupportingFeeOnTransferTokens
        uint256 balanceBefore = address(this).balance;
        aerodromeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            realAmountIn,
            amountOutMin,
            params.routes,
            address(this), // recibimos ETH aquí
            params.deadline
        );
        uint256 ethReceived = address(this).balance - balanceBefore;
        require(ethReceived > 0, "No ETH received");

        // 6) Cobramos fee en ETH
        uint256 feeAmount = _calculateFee(ethReceived, feeBps);
        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer fail");

        uint256 ethAfterFee = ethReceived - feeAmount;

        // 7) Enviamos ETH al usuario
        (bool userSent, ) = params.recipient.call{value: ethAfterFee}("");
        require(userSent, "Transfer fail to user");

        emit SwapTokensForETH(
            msg.sender,
            tokenIn,
            params.amountIn,
            ethReceived,
            feeAmount
        );
    }

    /**
     * @notice swapETHForTokens con fee en ETH, usando Aerodrome.
     *         La última ruta debe terminar en tokenOut. La primera from = WETH (que se wrapea).
     */
    function swapETHForTokensWithFee(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent
    ) external payable nonReentrant {
        require(params.routes.length >= 1, "No routes");
        require(feeBps <= 100, "fee>1% not allowed");
        require(slippagePercent <= 50, "slippage>50% not allowed");
        require(msg.value > 0, "No ETH sent");

        // 1) Cobrar fee en ETH
        uint256 feeAmount = _calculateFee(msg.value, feeBps);
        uint256 amountAfterFee = msg.value - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer fail");

        address tokenOut = params.routes[params.routes.length - 1].to;
        require(tokenOut != address(0), "tokenOut=0");

        // 2) getAmountsOut con amountAfterFee, para calculo slippage
        uint256[] memory amountsOut = aerodromeRouter.getAmountsOut(
            amountAfterFee,
            params.routes
        );
        uint256 expectedTokens = amountsOut[amountsOut.length - 1];
        require(expectedTokens > 0, "No route/pool? expectedTokens=0");

        uint256 amountOutMin = (expectedTokens * (100 - slippagePercent)) / 100;

        // 3) swapExactETHForTokensSupportingFeeOnTransferTokens
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(params.recipient);

        aerodromeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountAfterFee
        }(amountOutMin, params.routes, params.recipient, params.deadline);

        // 4) Calcular cuántos tokens recibió el usuario
        uint256 balanceAfter = IERC20(tokenOut).balanceOf(params.recipient);
        uint256 tokensReceived = balanceAfter - balanceBefore;

        emit SwapETHForTokens(
            msg.sender,
            tokenOut,
            msg.value,
            tokensReceived,
            feeAmount
        );
    }

    // Recibir ETH
    receive() external payable {}
}

// Interfaz mínima del router de Aerodrome.
// Ajusta los nombres y funciones a lo que tu router real use.
interface IAerodromeRouter {
    function getAmountsOut(
        uint256 amountIn,
        BookieSwapWrapperAerodrome.Route[] calldata routes
    ) external view returns (uint256[] memory amounts);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        BookieSwapWrapperAerodrome.Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        BookieSwapWrapperAerodrome.Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable;
}
