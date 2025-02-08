// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VIVIUniswapV2
 * @notice Permite swaps en Uniswap V2 con fee en ETH,
 *         usando funciones VIVIBuy (ETH->tokens) y VIVISell (tokens->ETH),
 *         y eventos Buy / Sell para reportar la actividad.
 */
contract VIVIUniswapV2 is ReentrancyGuard, Ownable {
    struct SwapParams {
        address[] path;
        uint256 amountIn;
        address recipient;
        uint256 deadline;
    }

    address public feeReceiver;
    IUniswapV2Router02 public uniswapRouter;

    event FeeReceiverUpdated(address indexed newFeeReceiver);
    event RouterUpdated(address indexed newRouter);

    /**
     * @dev Evento *Sell* (equivale a tokens->ETH).
     * @param user Quién invoca
     * @param tokenIn El token que se vende
     * @param tokensIn Cuántos tokensIn se enviaron
     * @param ethOut ETH bruto obtenido antes de fee
     * @param ethOutAfterFee ETH neto después de fee
     * @param feeAmount El fee en ETH
     */
    event Sell(
        address indexed user,
        address tokenIn,
        uint256 tokensIn,
        uint256 ethOut,
        uint256 ethOutAfterFee,
        uint256 feeAmount
    );

    /**
     * @dev Evento *Buy* (equivale a ETH->tokens).
     * @param user Quién invoca
     * @param tokenOut El token que se compra
     * @param ethIn ETH bruto enviado
     * @param ethInAfterFee ETH neto luego de fee
     * @param tokensOut La cantidad final de tokens comprados
     * @param feeAmount Fee en ETH
     */
    event Buy(
        address indexed user,
        address tokenOut,
        uint256 ethIn,
        uint256 ethInAfterFee,
        uint256 tokensOut,
        uint256 feeAmount
    );

    constructor(address _router, address _feeReceiver) Ownable(msg.sender) {
        require(_router != address(0), "Router=0");
        require(_feeReceiver != address(0), "Fee=0");
        uniswapRouter = IUniswapV2Router02(_router);
        feeReceiver = _feeReceiver;

        _transferOwnership(msg.sender);
    }

    function setFeeReceiver(address _fr) external onlyOwner {
        require(_fr != address(0), "fr=0");
        feeReceiver = _fr;
        emit FeeReceiverUpdated(_fr);
    }

    function setRouter(address _r) external onlyOwner {
        require(_r != address(0), "r=0");
        uniswapRouter = IUniswapV2Router02(_r);
        emit RouterUpdated(_r);
    }

    function _calculateFee(
        uint256 amount,
        uint256 bps
    ) internal pure returns (uint256) {
        return (amount * bps) / 10000;
    }

    /**
     * @notice VIVISell => tokens->ETH con fee en ETH post-swap.
     * @param params swap params
     * @param feeBps e.g. 50 => 0.5%, 100 => 1.00%
     * @param slippagePercent 0..50%
     */
    function VIVISell(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent
    ) external nonReentrant {
        require(params.path.length >= 2, "path <2");
        address tokenIn = params.path[0];
        address tokenOut = params.path[params.path.length - 1];
        require(tokenOut == uniswapRouter.WETH(), "tokenOut must be WETH");
        require(feeBps <= 100, "fee>1%");
        require(slippagePercent <= 50, "slippage>50%");
        require(params.amountIn > 0, "amtIn=0");

        // 1) Transfer tokens del user
        IERC20 t = IERC20(tokenIn);
        uint256 bBefore = t.balanceOf(address(this));
        bool ok = t.transferFrom(msg.sender, address(this), params.amountIn);
        require(ok, "transferFrom failed");
        uint256 bAfter = t.balanceOf(address(this));
        uint256 realIn = bAfter - bBefore;
        require(realIn > 0, "no tokens arrived");

        // 2) Approve router
        uint256 curAllow = t.allowance(address(this), address(uniswapRouter));
        if (curAllow < realIn) {
            t.approve(address(uniswapRouter), type(uint256).max);
        }

        // 3) slippage => amountOutMin
        uint256 amountOutMin;
        try uniswapRouter.getAmountsOut(realIn, params.path) returns (
            uint256[] memory out
        ) {
            uint256 expectedEth = out[out.length - 1];
            amountOutMin = (expectedEth * (100 - slippagePercent)) / 100;
        } catch Error(string memory reason) {
            revert(
                string(
                    abi.encodePacked("UniswapV2 getAmountsOut error: ", reason)
                )
            );
        } catch (bytes memory /*lowLevelData*/) {
            revert("UniswapV2 getAmountsOut unknown error");
        }

        // 4) measure ETH bal
        uint256 ethBefore = address(this).balance;
        // swap
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            realIn,
            amountOutMin,
            params.path,
            address(this),
            params.deadline
        );
        uint256 ethAfter = address(this).balance;
        uint256 ethGot = ethAfter - ethBefore;
        require(ethGot > 0, "No ETH out");

        // 5) fee
        uint256 feeAmount = _calculateFee(ethGot, feeBps);
        uint256 ethNet = ethGot - feeAmount;

        (bool feeOk, ) = feeReceiver.call{value: feeAmount}("");
        require(feeOk, "Fee transfer fail");

        // 6) user
        (bool userOk, ) = params.recipient.call{value: ethNet}("");
        require(userOk, "ETH transfer fail");

        emit Sell(
            msg.sender,
            tokenIn,
            params.amountIn,
            ethGot,
            ethNet,
            feeAmount
        );
    }

    /**
     * @notice VIVIBuy => ETH->tokens, cobro fee en ETH antes del swap.
     * @param params ...
     * @param feeBps ...
     * @param slippagePercent ...
     */
    function VIVIBuy(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent
    ) external payable nonReentrant {
        require(params.path.length >= 2, "path<2");
        require(params.path[0] == uniswapRouter.WETH(), "first!=WETH");
        address tokenOut = params.path[params.path.length - 1];
        require(tokenOut != address(0), "tokenOut=0");
        require(msg.value > 0, "no ETH");
        require(feeBps <= 100, "fee>1%");
        require(slippagePercent <= 50, "slippage>50%");

        // 1) fee
        uint256 feeAmt = _calculateFee(msg.value, feeBps);
        uint256 ethNet = msg.value - feeAmt;

        (bool feeOk, ) = feeReceiver.call{value: feeAmt}("");
        require(feeOk, "Fee transfer fail");

        uint256 amountOutMin;
        try uniswapRouter.getAmountsOut(ethNet, params.path) returns (
            uint256[] memory out
        ) {
            uint256 expected = out[out.length - 1];
            amountOutMin = (expected * (100 - slippagePercent)) / 100;
        } catch Error(string memory reason) {
            revert(
                string(
                    abi.encodePacked("UniswapV2 getAmountsOut error: ", reason)
                )
            );
        } catch (bytes memory /*lowLevelData*/) {
            revert("UniswapV2 getAmountsOut unknown error");
        }

        // 3) measure tokens
        uint256 balBefore = IERC20(tokenOut).balanceOf(params.recipient);

        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethNet
        }(amountOutMin, params.path, params.recipient, params.deadline);

        uint256 balAfter = IERC20(tokenOut).balanceOf(params.recipient);
        uint256 tokensOut = balAfter - balBefore;

        emit Buy(msg.sender, tokenOut, msg.value, ethNet, tokensOut, feeAmt);
    }

    receive() external payable {}
}
