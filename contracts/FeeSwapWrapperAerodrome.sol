// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FeeSwapWrapperAerodrome
 * @notice Similar a `FeeSwapWrapper` de Uniswap V2, pero usando Aerodrome router.
 *         Maneja un fee en ETH y tokens deflacionarios.
 */
contract FeeSwapWrapperAerodrome is ReentrancyGuard, Ownable {
    struct SwapParams {
        address[] path; // e.g. [tokenA, tokenB, tokenC], donde tokenB => WETH en caso de ETH
        uint256 amountIn;
        address recipient;
        uint256 deadline;
    }

    address public feeReceiver;
    IAerodromeRouter public aerodromeRouter;

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
     * @dev Simple helper para calcular fee en base 10000 (0.50% => 50).
     */
    function _calculateFee(
        uint256 amount,
        uint256 feeBps
    ) internal pure returns (uint256) {
        return (amount * feeBps) / 10000;
    }

    /**
     * @notice swapTokensForETH con fee en ETH, usando la lógica "supporting fee on transfer" de Aerodrome.
     * @param params ruta: path[0] = tokenIn, path[path.length-1] = WETH (por ejemplo),
     * @param feeBps 50 => 0.50%, 100 => 1.00%
     * @param slippagePercent se maneja calculando `getAmountsOut` => `amountOutMin`
     */
    function swapTokensForETHWithFee(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent
    ) external nonReentrant {
        require(params.path.length >= 2, "Path must be >=2");
        require(feeBps <= 100, "fee too high (1% max)");
        require(slippagePercent <= 50, "slippage max 50%");

        address tokenIn = params.path[0];
        address tokenOut = params.path[params.path.length - 1];

        // Aseguramos que al final sea WETH si queremos recibir ETH
        // En Aerodrome, "swapExactTokensForETH" => path final == WETH => luego retira
        // En su router, `swapExactTokensForETH...` hace unwrap internamente.
        // Revisa si su router de verdad soporta "stable vs volatile" => param en path?
        // en Aerodrome se usa "Route[] memory routes", con stable booleans.
        // Este wrapper asume algo simplificado (similar a tu V2 wrapper).

        // 1) Transfer tokens deflacionarios
        IERC20(tokenIn).transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );
        uint256 realAmountIn = IERC20(tokenIn).balanceOf(address(this));
        require(realAmountIn > 0, "No tokens arrived");

        // 2) Approve
        IERC20(tokenIn).approve(address(aerodromeRouter), realAmountIn);

        // 3) Calculate amountOutMin => getAmountsOut
        uint256[] memory amountsOut = aerodromeRouter.getAmountsOut(
            realAmountIn,
            _toRoutes(params.path)
        );
        uint256 expectedETH = amountsOut[amountsOut.length - 1];
        uint256 amountOutMin = (expectedETH * (100 - slippagePercent)) / 100;

        // 4) swapExactTokensForETH
        // ver si Aerodrome tiene "swapExactTokensForETHSupportingFeeOnTransferTokens"
        // o "swapExactTokensForETH". Ajusta según su ABI.
        uint256 balanceBefore = address(this).balance;
        aerodromeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            realAmountIn,
            amountOutMin,
            _toRoutes(params.path),
            address(this), // Recibimos ETH en el wrapper
            params.deadline
        );
        uint256 ethReceived = address(this).balance - balanceBefore;
        require(ethReceived > 0, "no ETH received");

        // 5) fee en ETH
        uint256 feeAmount = _calculateFee(ethReceived, feeBps);
        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "fee transfer fail");

        uint256 ethAfterFee = ethReceived - feeAmount;
        (bool userSent, ) = params.recipient.call{value: ethAfterFee}("");
        require(userSent, "final transfer fail");

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
     */
    function swapETHForTokensWithFee(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent
    ) external payable nonReentrant {
        require(params.path.length >= 2, "Path >=2");
        require(feeBps <= 100, "fee >1% not allowed");
        require(slippagePercent <= 50, "slippage>50% not allowed");
        require(msg.value > 0, "No ETH sent");

        // 1) Cobrar fee
        uint256 feeAmount = _calculateFee(msg.value, feeBps);
        uint256 amountAfterFee = msg.value - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "fee transfer fail");

        address tokenOut = params.path[params.path.length - 1];
        // 2) Calculamos amountOutMin
        uint256[] memory amountsOut = aerodromeRouter.getAmountsOut(
            amountAfterFee,
            _toRoutes(params.path)
        );
        uint256 expectedTokens = amountsOut[amountsOut.length - 1];
        uint256 amountOutMin = (expectedTokens * (100 - slippagePercent)) / 100;

        // 3) swapExactETHForTokens
        // => en aerodrome: `swapExactETHForTokensSupportingFeeOnTransferTokens(...)`
        // si lo tiene. Sino usas `swapExactETHForTokens`.
        uint256 tokenBalanceBefore = IERC20(tokenOut).balanceOf(
            params.recipient
        );
        aerodromeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountAfterFee
        }(
            amountOutMin,
            _toRoutes(params.path),
            params.recipient,
            params.deadline
        );
        uint256 tokenBalanceAfter = IERC20(tokenOut).balanceOf(
            params.recipient
        );
        uint256 tokensReceived = tokenBalanceAfter - tokenBalanceBefore;

        emit SwapETHForTokens(
            msg.sender,
            tokenOut,
            msg.value,
            tokensReceived,
            feeAmount
        );
    }

    /**
     * Aerodrome usa una estructura: `struct Route { address from; address to; bool stable; address factory; }`
     * En tu wrapper, params.path es address[].
     * Debes convertir path => Route[] con un stable==false (o true) y factory==address(0).
     * O si tu wrapper necesita stable/pools, deberás exponer stable como param.
     */
    function _toRoutes(
        address[] memory path
    ) internal pure returns (Route[] memory) {
        // EJEMPLO: asumimos path => [A, B] single-hop, stable=false, factory=0 => default
        // En la práctica, si la persona desea multi-hop, necesitas un array con stable booleans.
        // Simplifico asumiendo 1 hop.
        // Genera un Route[] de length=1 => {from=path[0], to=path[1], stable=false, factory=address(0)}
        require(path.length == 2, "only 1 hop for demo");
        Route[] memory routes = new Route[](1);
        routes[0] = Route({
            from: path[0],
            to: path[1],
            stable: false,
            factory: address(0)
        });
        return routes;
    }

    receive() external payable {}
}

// Interfaz minimal. Ajustar con la real si hace multi-hop:
interface IAerodromeRouter {
    // Path is typically an array of Route { from, to, stable, factory },
    // see https://github.com/aerodrome-finance/contracts/blob/...
    // getAmountsOut
    function getAmountsOut(
        uint256 amountIn,
        Route[] memory routes
    ) external view returns (uint256[] memory amounts);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable;
}

struct Route {
    address from;
    address to;
    bool stable;
    address factory; // optional
}
