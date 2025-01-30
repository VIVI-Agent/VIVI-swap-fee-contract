// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BookieSwapWrapperUniV3
 * @notice Permite hacer swaps en Uniswap V3 con posibilidad de cobrar un fee en ETH.
 *         Maneja tokens deflacionarios calculando el monto real transferido.
 * @dev Usa ISwapRouter de Uniswap V3. Ejemplo single-hop (token <-> WETH).
 */
contract BookieSwapWrapperUniV3 is ReentrancyGuard, Ownable {
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint24 feeTier; // ej. 3000 => 0.3%
        uint256 amountIn; // cuántos tokensIn (o 0 si es ETH) se envían
        address recipient;
        uint256 deadline;
        uint256 amountOutMin; // slippage
    }

    address public feeReceiver;
    ISwapRouter public uniswapRouter; // V3 SwapRouter
    address public WETH; // WETH address en la red que uses

    event FeeReceiverUpdated(address indexed newFeeReceiver);
    event RouterUpdated(address indexed newRouter);

    event SwapTokensForETHV3(
        address indexed sender,
        address tokenIn,
        uint256 amountIn,
        uint256 ethReceived,
        uint256 feeAmount
    );
    event SwapETHForTokensV3(
        address indexed sender,
        address tokenOut,
        uint256 ethIn,
        uint256 tokensReceived,
        uint256 feeAmount
    );

    /**
     * @dev Constructor: Asigna router V3, feeReceiver y la dirección de WETH.
     *      Asegúrate de que Ownable(msg.sender) sea correcto para tu versión de OpenZeppelin.
     */
    constructor(
        address _v3Router,
        address _feeReceiver,
        address _weth
    ) Ownable(msg.sender) {
        require(_v3Router != address(0), "Invalid router");
        require(_feeReceiver != address(0), "Invalid feeReceiver");
        require(_weth != address(0), "Invalid WETH");

        uniswapRouter = ISwapRouter(_v3Router);
        feeReceiver = _feeReceiver;
        WETH = _weth;
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        require(_feeReceiver != address(0), "feeReceiver=0");
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdated(_feeReceiver);
    }

    function setRouter(address _v3Router) external onlyOwner {
        require(_v3Router != address(0), "router=0");
        uniswapRouter = ISwapRouter(_v3Router);
        emit RouterUpdated(_v3Router);
    }

    /**
     * @dev Helper para calcular fee en base 10000 (ej. 50 => 0.50%, 100 => 1%).
     */
    function _calculateFee(
        uint256 amount,
        uint256 feeBps
    ) internal pure returns (uint256) {
        return (amount * feeBps) / 10000;
    }

    /**
     * @notice swapTokensForETH con fee en ETH (single-hop).
     * @dev tokenIn -> WETH con exactInputSingle, unwrap WETH->ETH, cobrar fee, enviar ETH al user.
     * @param params.tokenOut Debe ser WETH.
     * @param feeBps Por ej. 50 => 0.5%, 100 => 1%.
     */
    function swapTokensForETHWithFee(
        SwapParams calldata params,
        uint256 feeBps
    ) external nonReentrant {
        require(
            params.tokenOut == WETH,
            "tokenOut must be WETH for ETH result"
        );
        require(params.amountIn > 0, "No input tokens");
        require(feeBps <= 100, "Max 1% fee");

        // 1) Tomamos el tokenIn (deflacionario)
        IERC20 tokenIn = IERC20(params.tokenIn);

        // Transfer tokens (deflacionario => realAmountIn)
        uint256 beforeBal = tokenIn.balanceOf(address(this));
        bool ok = tokenIn.transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );
        require(ok, "transferFrom failed");
        uint256 afterBal = tokenIn.balanceOf(address(this));
        uint256 realAmountIn = afterBal - beforeBal;
        require(realAmountIn > 0, "No tokens arrived");

        // 2) Approve al router si allowance < realAmountIn
        uint256 allowance = tokenIn.allowance(
            address(this),
            address(uniswapRouter)
        );
        if (allowance < realAmountIn) {
            tokenIn.approve(address(uniswapRouter), type(uint256).max);
        }

        // 3) Llamamos exactInputSingle(tokenIn->WETH), recipient=this -> recibimos WETH
        ISwapRouter.ExactInputSingleParams memory singleParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: params.tokenIn,
                tokenOut: params.tokenOut,
                fee: params.feeTier,
                recipient: address(this), // Recibimos WETH aquí, luego unwrap
                amountIn: realAmountIn,
                amountOutMinimum: params.amountOutMin,
                sqrtPriceLimitX96: 0
            });

        uint256 wethReceived = uniswapRouter.exactInputSingle(singleParams);
        require(wethReceived > 0, "No WETH out from V3 swap");

        // 4) Calculamos cuánta ETH genera el unwrap de WETH
        uint256 oldEthBal = address(this).balance; // ETH antes de unwrap
        // unwrap WETH->ETH
        (bool successUnwrap, ) = WETH.call(
            abi.encodeWithSignature("withdraw(uint256)", wethReceived)
        );
        require(successUnwrap, "WETH withdraw failed");

        uint256 newEthBal = address(this).balance; // ETH después de unwrap
        uint256 newlyUnwrapped = newEthBal - oldEthBal;
        // Este es el ETH proveniente del swap, sin mezclar leftover.

        require(newlyUnwrapped > 0, "No ETH unwrapped");

        // 5) Cobrar fee en ETH
        uint256 feeAmount = _calculateFee(newlyUnwrapped, feeBps);
        uint256 ethAfterFee = newlyUnwrapped - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "fee transfer failed");

        // 6) Enviar resto al usuario (params.recipient)
        (bool sentUser, ) = params.recipient.call{value: ethAfterFee}("");
        require(sentUser, "final transfer failed");

        emit SwapTokensForETHV3(
            msg.sender,
            params.tokenIn,
            realAmountIn,
            newlyUnwrapped,
            feeAmount
        );
    }

    /**
     * @notice swapETHForTokens con fee en ETH (single-hop).
     * @dev user ETH -> cobrar fee -> deposit WETH -> exactInputSingle(WETH->tokenOut).
     * @param params.tokenIn Debe ser WETH.
     * @param feeBps Por ej. 50 => 0.5%, 100 => 1%.
     */
    function swapETHForTokensWithFee(
        SwapParams calldata params,
        uint256 feeBps
    ) external payable nonReentrant {
        require(params.tokenIn == WETH, "tokenIn must be WETH for ETH swaps");
        require(msg.value > 0, "No ETH sent");
        require(feeBps <= 100, "Max 1% fee");

        // 1) Cobrar fee
        uint256 feeAmount = _calculateFee(msg.value, feeBps);
        uint256 amountAfterFee = msg.value - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "fee transfer fail");

        // 2) wrap el ETH leftover -> WETH
        (bool successWrap, ) = WETH.call{value: amountAfterFee}(
            abi.encodeWithSignature("deposit()")
        );
        require(successWrap, "WETH deposit fail");

        // 3) Approve WETH to router
        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        IERC20(WETH).approve(address(uniswapRouter), wethBalance);

        // 4) exactInputSingle(WETH -> tokenOut), recipient = params.recipient
        ISwapRouter.ExactInputSingleParams memory singleParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: params.tokenOut,
                fee: params.feeTier,
                recipient: params.recipient,
                amountIn: wethBalance,
                amountOutMinimum: params.amountOutMin,
                sqrtPriceLimitX96: 0
            });

        uint256 tokensOut = uniswapRouter.exactInputSingle(singleParams);
        require(tokensOut > 0, "No tokens out from v3 swap");

        emit SwapETHForTokensV3(
            msg.sender,
            params.tokenOut,
            msg.value,
            tokensOut,
            feeAmount
        );
    }

    receive() external payable {}
}

// Interfaz mínima del router de Aerodrome.
// Ajusta los nombres y funciones a lo que tu router real use.
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}
