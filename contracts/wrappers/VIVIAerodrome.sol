// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../utils/VIVIFeeManager.sol";

/**
 * @title VIVIAerodrome
 * @notice Wrapper that allows charging an ETH fee on Aerodrome swaps,
 *         providing VIVIBuy (ETH->tokens) and VIVISell (tokens->ETH) functions,
 *         and Buy / Sell events for reporting.
 *         Supports multiple fee receivers with configurable percentages.
 */
contract VIVIAerodrome is ReentrancyGuard, VIVIFeeManager {
    /**
     * @dev In Aerodrome, each "Route" has: (from, to, stable, factory).
     *      Example of a 1-hop route: [{ from: WETH, to: tokenOut, stable: false, factory: <volatileFactory> }]
     */
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    /**
     * @dev SwapParams includes an array of Route[], an amountIn, recipient, and deadline.
     *      - routes[0].from = tokenIn (or WETH if swapTokensForETH).
     *      - routes[routes.length - 1].to = WETH if you want to end up in ETH.
     *      - In swapETHForTokens => the opposite: routes[0].from = WETH => routes[last].to = tokenOut.
     */
    struct SwapParams {
        Route[] routes;
        uint256 amountIn;
        address recipient;
        uint256 deadline;
    }

    IAerodromeRouter public aerodromeRouter;
    address public WETH;

    event RouterUpdated(address indexed newRouter);
    event WETHUpdated(address indexed newWETH);

    /**
     * @dev Sell event (tokens->ETH).
     * @param user The caller
     * @param tokenIn The token being sold
     * @param tokenAmountIn The declared token amount from the user
     * @param ethOut The total ETH received before fee
     * @param ethOutAfterFee The net ETH after fee
     * @param feeAmount The fee taken in ETH
     */
    event Sell(
        address indexed user,
        address tokenIn,
        uint256 tokenAmountIn,
        uint256 ethOut,
        uint256 ethOutAfterFee,
        uint256 feeAmount
    );

    /**
     * @dev Buy event (ETH->tokens).
     * @param user The caller
     * @param tokenOut The token being purchased
     * @param ethIn Total ETH sent
     * @param ethInAfterFee Net ETH after fee
     * @param tokensOut The number of tokens received
     * @param feeAmount The fee taken in ETH
     */
    event Buy(
        address indexed user,
        address tokenOut,
        uint256 ethIn,
        uint256 ethInAfterFee,
        uint256 tokensOut,
        uint256 feeAmount
    );

    /**
     * @param _router Address of the Aerodrome router
     * @param _feeReceiver Address that will receive the fees
     * @param _weth Address of the WETH token
     */
    constructor(
        address _router,
        address _feeReceiver,
        address _weth
    ) VIVIFeeManager(_feeReceiver) {
        require(_router != address(0), "router=0");
        require(_weth != address(0), "WETH=0");
        aerodromeRouter = IAerodromeRouter(_router);
        WETH = _weth;
    }

    /**
     * @notice Updates the Aerodrome router address.
     * @param _r The new router address
     */
    function setRouter(address _r) external onlyOwner {
        require(_r != address(0), "r=0");
        aerodromeRouter = IAerodromeRouter(_r);
        emit RouterUpdated(_r);
    }

    /**
     * @notice Updates the WETH address.
     * @param _newWETH The new WETH address
     */
    function setWETH(address _newWETH) external onlyOwner {
        require(_newWETH != address(0), "WETH=0");
        WETH = _newWETH;
        emit WETHUpdated(_newWETH);
    }

    /**
     * @notice VIVISell: tokens->ETH with an ETH fee (post-swap).
     *         The last route.to must be WETH => the contract unwraps to ETH.
     * @param params SwapParams (routes, amountIn, recipient, deadline)
     * @param feeBps Fee in basis points (e.g. 50 => 0.5%, 100 => 1%)
     * @param slippagePercent 0..50% max
     * @param additionalFeeReceivers Optional array of additional fee receivers with their BPS
     */
    function VIVISell(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent,
        FeeReceiver[] calldata additionalFeeReceivers
    ) external nonReentrant {
        require(params.routes.length >= 1, "no routes");
        require(feeBps <= 100, "fee>1%");
        require(slippagePercent <= 50, "slippage>50%");

        // The first route.from is tokenIn
        address tokenIn = params.routes[0].from;
        // The last route.to must be WETH
        require(
            params.routes[params.routes.length - 1].to == WETH,
            "last route.to != WETH"
        );

        // Transfer tokens from user
        IERC20(tokenIn).transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );
        uint256 realIn = IERC20(tokenIn).balanceOf(address(this));
        require(realIn > 0, "No tokens arrived");

        // Approve the router
        IERC20(tokenIn).approve(address(aerodromeRouter), realIn);

        // getAmountsOut with try/catch
        uint256[] memory outs;
        try aerodromeRouter.getAmountsOut(realIn, params.routes) returns (
            uint256[] memory returnedOuts
        ) {
            outs = returnedOuts;
        } catch Error(string memory reason) {
            revert(
                string(
                    abi.encodePacked("Aerodrome getAmountsOut error: ", reason)
                )
            );
        } catch (bytes memory) {
            revert("Aerodrome getAmountsOut unknown error");
        }

        uint256 expectedETH = outs[outs.length - 1];
        uint256 amountOutMin = (expectedETH * (100 - slippagePercent)) / 100;

        // Perform the swap
        uint256 ethBalBefore = address(this).balance;
        aerodromeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            realIn,
            amountOutMin,
            params.routes,
            address(this),
            params.deadline
        );
        // Calc ETH received
        uint256 ethBalAfter = address(this).balance;
        uint256 ethGot = ethBalAfter - ethBalBefore;
        require(ethGot > 0, "No ETH out");

        // Fee distribution
        uint256 feeAmount = _calculateFee(ethGot, feeBps);
        uint256 ethNet = ethGot - feeAmount;

        // Distribute fees to additional receivers first
        uint256 remainingFee = _distributeFees(
            feeAmount,
            additionalFeeReceivers
        );

        // Send remaining fee to default receiver
        _sendToDefaultReceiver(remainingFee);

        (bool userOk, ) = params.recipient.call{value: ethNet}("");
        require(userOk, " ETH transfer fail");

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
     * @notice VIVIBuy: ETH->tokens with an ETH fee (pre-swap).
     *         The last route.to is the token being bought.
     * @param params SwapParams (routes, amountIn, recipient, deadline)
     * @param feeBps Fee in basis points
     * @param slippagePercent Max 50%
     * @param additionalFeeReceivers Optional array of additional fee receivers with their BPS
     */
    function VIVIBuy(
        SwapParams calldata params,
        uint256 feeBps,
        uint256 slippagePercent,
        FeeReceiver[] calldata additionalFeeReceivers
    ) external payable nonReentrant {
        require(params.routes.length >= 1, "no routes");
        require(feeBps <= 100, "fee>1%");
        require(slippagePercent <= 50, "slippage>50%");
        require(msg.value > 0, "no ETH");

        uint256 feeAmt = _calculateFee(msg.value, feeBps);
        uint256 ethAfterFee = msg.value - feeAmt;

        // Distribute fees to additional receivers first
        uint256 remainingFee = _distributeFees(feeAmt, additionalFeeReceivers);

        // Send remaining fee to default receiver
        _sendToDefaultReceiver(remainingFee);

        address tokenOut = params.routes[params.routes.length - 1].to;
        require(tokenOut != address(0), "tokenOut=0");

        address tokenIn = params.routes[0].from;
        require(tokenIn == WETH, "first route.from != WETH");

        // getAmountsOut with try/catch
        uint256[] memory outs;
        try aerodromeRouter.getAmountsOut(ethAfterFee, params.routes) returns (
            uint256[] memory returnedOuts
        ) {
            outs = returnedOuts;
        } catch Error(string memory reason) {
            revert(
                string(
                    abi.encodePacked("Aerodrome getAmountsOut error: ", reason)
                )
            );
        } catch (bytes memory) {
            revert("Aerodrome getAmountsOut unknown error");
        }

        uint256 expectedTokens = outs[outs.length - 1];
        uint256 amtOutMin = (expectedTokens * (100 - slippagePercent)) / 100;

        // Check recipient's balance before
        uint256 balBefore = IERC20(tokenOut).balanceOf(params.recipient);
        aerodromeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAfterFee
        }(amtOutMin, params.routes, params.recipient, params.deadline);

        // Check recipient's balance after
        uint256 balAfter = IERC20(tokenOut).balanceOf(params.recipient);
        uint256 tokensOut = balAfter - balBefore;

        emit Buy(
            msg.sender,
            tokenOut,
            msg.value,
            ethAfterFee,
            tokensOut,
            feeAmt
        );
    }

    receive() external payable {}
}

/**
 * @dev Minimal Aerodrome router interface. Adjust to your actual router specs.
 */
interface IAerodromeRouter {
    function getAmountsOut(
        uint256 amountIn,
        VIVIAerodrome.Route[] calldata routes
    ) external view returns (uint256[] memory);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        VIVIAerodrome.Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        VIVIAerodrome.Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable;
}
