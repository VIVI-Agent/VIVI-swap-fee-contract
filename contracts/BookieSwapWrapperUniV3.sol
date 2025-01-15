// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BookieSwapWrapperUniV3
 * @notice Permite hacer swaps en Uniswap V3 con posibilidad de cobrar un fee en ETH.
 *         Maneja tokens deflacionarios calculando el monto real transferido.
 * @dev Usa ISwapRouter de Uniswap V3. Ejemplo single-hop.
 */
contract BookieSwapWrapperUniV3 is ReentrancyGuard, Ownable {
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint24 feeTier; // ej. 3000 => 0.3%
        uint256 amountIn; // Cuánto tokensIn pasamos
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

    // Simple helper para fees en base 10000
    function _calculateFee(
        uint256 amount,
        uint256 feeBps
    ) internal pure returns (uint256) {
        return (amount * feeBps) / 10000;
    }

    /**
     * @notice swapTokensForETH con Fee en ETH (similar a V2, pero usando exactInputSingle).
     * @dev single-hop: tokenIn -> WETH -> unwrap WETH -> cobrar fee -> user
     */
    function swapTokensForETHWithFee(
        SwapParams calldata params,
        uint256 feeBps
    ) external nonReentrant {
        require(
            params.tokenOut == WETH,
            "tokenOut must be WETH for ETH result"
        );
        require(params.amountIn > 0, "No input");
        require(feeBps <= 100, "Max 1% fee");

        IERC20 tokenIn = IERC20(params.tokenIn);

        // 1) Transfer tokens deflacionarios => realAmountIn
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

        // 3) Llamar exactInputSingle(tokenIn->WETH)
        ISwapRouter.ExactInputSingleParams memory singleParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: params.tokenIn,
                tokenOut: params.tokenOut,
                fee: params.feeTier,
                recipient: address(this), // recibimos WETH acá
                deadline: params.deadline,
                amountIn: realAmountIn,
                amountOutMinimum: params.amountOutMin,
                sqrtPriceLimitX96: 0
            });

        uint256 wethReceived = uniswapRouter.exactInputSingle(singleParams);
        require(wethReceived > 0, "No WETH out from V3");

        // 4) unwrap WETH->ETH
        (bool successUnwrap, ) = WETH.call(
            abi.encodeWithSignature("withdraw(uint256)", wethReceived)
        );
        require(successUnwrap, "WETH withdraw failed");

        uint256 ethBal = address(this).balance;
        // Cobrar fee en ETH
        uint256 feeAmount = _calculateFee(ethBal, feeBps);
        uint256 ethAfterFee = ethBal - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "fee transfer failed");

        // Enviar resto al user
        (bool sentUser, ) = params.recipient.call{value: ethAfterFee}("");
        require(sentUser, "final transfer failed");

        emit SwapTokensForETHV3(
            msg.sender,
            params.tokenIn,
            realAmountIn,
            ethBal,
            feeAmount
        );
    }

    /**
     * @notice swapETHForTokens con Fee en ETH (similar a V2).
     * @dev single-hop: user ETH -> wrapper -> fee -> remainder -> swap to WETH -> tokenOut
     */
    function swapETHForTokensWithFee(
        SwapParams calldata params,
        uint256 feeBps
    ) external payable nonReentrant {
        require(params.tokenIn == WETH, "tokenIn must be WETH for ETH swaps");
        require(msg.value > 0, "No ETH sent");
        require(feeBps <= 100, "Max 1% fee");

        // 1) Cobrar fee en ETH
        uint256 feeAmount = _calculateFee(msg.value, feeBps);
        uint256 amountAfterFee = msg.value - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "fee transfer fail");

        // 2) Llamar a exactInputSingle( WETH-> tokenOut ), depositar WETH con wrap
        //   Sin embargo, ISwapRouter V3 no soporta deposit WETH internamente
        //   normal es: router.exactInputSingle{value: amountAfterFee}(...),
        //   con "multicall" o PeripheryPayments.  Para simplificar:
        //   - deposit WETH
        (bool successWrap, ) = WETH.call{value: amountAfterFee}(
            abi.encodeWithSignature("deposit()")
        );
        require(successWrap, "WETH deposit fail");

        // 3) Approve WETH to router
        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        IERC20(WETH).approve(address(uniswapRouter), wethBalance);

        ISwapRouter.ExactInputSingleParams memory singleParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: params.tokenOut,
                fee: params.feeTier,
                recipient: params.recipient,
                deadline: params.deadline,
                amountIn: wethBalance, // todo lo que depositamos
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
