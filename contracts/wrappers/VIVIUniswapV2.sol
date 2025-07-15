// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../utils/VIVIFeeManager.sol";

/**
 * @title VIVIUniswapV2
 * @notice Enables swaps on Uniswap V2 with an ETH fee,
 *         using VIVIBuy (ETH->tokens) and VIVISell (tokens->ETH),
 *         and Buy / Sell events to report activity.
 *         Supports multiple fee receivers with configurable percentages.
 */
contract VIVIUniswapV2 is ReentrancyGuard, VIVIFeeManager {
    struct SwapParams {
        address[] path;
        uint256 amountIn;
        address recipient;
        uint256 deadline;
    }

    IUniswapV2Router02 public uniswapRouter;

    event RouterUpdated(address indexed newRouter);

    /**
     * @dev *Sell* event (equivalent to tokens->ETH).
     * @param user The caller
     * @param tokenIn Token being sold
     * @param tokensIn Number of tokens sent
     * @param ethOut The gross ETH received before fees
     * @param ethOutAfterFee The net ETH after fee
     * @param feeAmount Fee in ETH
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
     * @dev *Buy* event (equivalent to ETH->tokens).
     * @param user The caller
     * @param tokenOut Token being bought
     * @param ethIn The gross ETH sent
     * @param ethInAfterFee The net ETH after fee
     * @param tokensOut The final amount of tokens purchased
     * @param feeAmount Fee in ETH
     */
    event Buy(
        address indexed user,
        address tokenOut,
        uint256 ethIn,
        uint256 ethInAfterFee,
        uint256 tokensOut,
        uint256 feeAmount
    );

    constructor(
        address _router,
        address _feeReceiver
    ) VIVIFeeManager(_feeReceiver) {
        require(_router != address(0), "Router=0");
        uniswapRouter = IUniswapV2Router02(_router);
    }

    function setRouter(address _r) external onlyOwner {
        require(_r != address(0), "r=0");
        uniswapRouter = IUniswapV2Router02(_r);
        emit RouterUpdated(_r);
    }

    /**
     * @notice VIVISell => tokens->ETH with an ETH fee applied after the swap.
     * @param params Swap parameters
     * @param feeBps e.g. 50 => 0.5%, 100 => 1.00%
     * @param slippagePercent 0..50%
     * @param additionalFeeReceivers Optional array of additional fee receivers with their BPS
     */
    function VIVISell(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent,
        FeeReceiver[] calldata additionalFeeReceivers
    ) external nonReentrant {
        require(params.path.length >= 2, "path <2");
        address tokenIn = params.path[0];
        address tokenOut = params.path[params.path.length - 1];
        require(tokenOut == uniswapRouter.WETH(), "tokenOut must be WETH");
        require(feeBps <= 100, "fee>1%");
        require(slippagePercent <= 50, "slippage>50%");
        require(params.amountIn > 0, "amtIn=0");

        // 1) Transfer tokens from the user
        IERC20 t = IERC20(tokenIn);
        uint256 bBefore = t.balanceOf(address(this));
        bool ok = t.transferFrom(msg.sender, address(this), params.amountIn);
        require(ok, "transferFrom failed");
        uint256 bAfter = t.balanceOf(address(this));
        uint256 realIn = bAfter - bBefore;
        require(realIn > 0, "no tokens arrived");

        // 2) Approve the router
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

        // 4) Measure the ETH balance
        uint256 ethBefore = address(this).balance;
        // Perform the swap
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

        // 5) Fee distribution
        uint256 feeAmount = _calculateFee(ethGot, feeBps);
        uint256 ethNet = ethGot - feeAmount;

        // Distribute fees to additional receivers first
        uint256 remainingFee = _distributeFees(
            feeAmount,
            additionalFeeReceivers
        );

        // Send remaining fee to default receiver
        _sendToDefaultReceiver(remainingFee);

        // 6) Send net ETH to user
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
     * @notice VIVIBuy => ETH->tokens, applying an ETH fee before the swap.
     * @param params Swap parameters
     * @param feeBps e.g. 50 => 0.5%, 100 => 1.00%
     * @param slippagePercent 0..50%
     * @param additionalFeeReceivers Optional array of additional fee receivers with their BPS
     */
    function VIVIBuy(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent,
        FeeReceiver[] calldata additionalFeeReceivers
    ) external payable nonReentrant {
        require(params.path.length >= 2, "path<2");
        require(params.path[0] == uniswapRouter.WETH(), "first!=WETH");
        address tokenOut = params.path[params.path.length - 1];
        require(tokenOut != address(0), "tokenOut=0");
        require(msg.value > 0, "no ETH");
        require(feeBps <= 100, "fee>1%");
        require(slippagePercent <= 50, "slippage>50%");

        // 1) Fee distribution
        uint256 feeAmt = _calculateFee(msg.value, feeBps);
        uint256 ethNet = msg.value - feeAmt;

        // Distribute fees to additional receivers first
        uint256 remainingFee = _distributeFees(feeAmt, additionalFeeReceivers);

        // Send remaining fee to default receiver
        _sendToDefaultReceiver(remainingFee);

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

        // 3) Measure tokens
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
