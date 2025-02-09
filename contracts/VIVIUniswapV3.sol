// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VIVIUniswapV3
 * @notice Enables swaps on Uniswap V3 with an ETH fee.
 *         Uses single-hop logic (tokenIn <-> WETH <-> tokenOut).
 *         Provides VIVISell (tokens->ETH) and VIVIBuy (ETH->tokens),
 *         and Buy / Sell events for consistency with other VIVI wrappers.
 */
contract VIVIUniswapV3 is ReentrancyGuard, Ownable {
    /**
     * @dev SwapParams for single-hop:
     *  - tokenIn / tokenOut
     *  - feeTier (e.g. 3000 => 0.3%)
     *  - amountIn => how many tokens to swap (or 0 if not used)
     *  - recipient => who receives the output tokens (or ETH after unwrap)
     *  - deadline => tx must finalize before this timestamp
     *  - amountOutMin => slippage protection
     */
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint24 feeTier;
        uint256 amountIn;
        address recipient;
        uint256 deadline;
        uint256 amountOutMin;
    }

    address public feeReceiver;
    ISwapRouter public uniswapRouter;
    address public WETH;

    event FeeReceiverUpdated(address indexed newFeeReceiver);
    event RouterUpdated(address indexed newRouter);
    event WETHUpdated(address indexed newWETH);

    /**
     * @dev Sell event (tokens->ETH).
     * @param user The caller
     * @param tokenIn Token being sold
     * @param tokensIn Actual tokens swapped
     * @param ethOut The total ETH received (before fee)
     * @param ethOutAfterFee The net ETH after fee
     * @param feeAmount Fee taken in ETH
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
     * @dev Buy event (ETH->tokens).
     * @param user The caller
     * @param tokenOut Token being purchased
     * @param ethIn Total ETH sent
     * @param ethInAfterFee Net ETH after fee
     * @param tokensOut Number of tokens bought
     * @param feeAmount Fee taken in ETH
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
     * @param _v3Router Address of the Uniswap V3 router
     * @param _feeReceiver Address to which fees are sent
     * @param _weth Address of the WETH token on this network
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

    /**
     * @notice Updates the fee receiver address.
     * @param _feeReceiver The new fee receiver
     */
    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        require(_feeReceiver != address(0), "feeReceiver=0");
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdated(_feeReceiver);
    }

    /**
     * @notice Updates the Uniswap V3 router address.
     * @param _v3Router The new router address
     */
    function setRouter(address _v3Router) external onlyOwner {
        require(_v3Router != address(0), "router=0");
        uniswapRouter = ISwapRouter(_v3Router);
        emit RouterUpdated(_v3Router);
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
     * @dev Calculates fee in basis points (50 => 0.5%, 100 => 1%).
     */
    function _calculateFee(
        uint256 amount,
        uint256 feeBps
    ) internal pure returns (uint256) {
        return (amount * feeBps) / 10000;
    }

    /**
     * @notice VIVISell => tokens->ETH with an ETH fee, single-hop.
     *         tokenIn => WETH => unwrap => user receives ETH minus fee.
     * @param params Must have tokenOut == WETH to eventually unwrap to ETH.
     * @param feeBps e.g. 50 => 0.5%, 100 => 1%.
     */
    function VIVISell(
        SwapParams calldata params,
        uint256 feeBps
    ) external nonReentrant {
        require(params.tokenOut == WETH, "tokenOut must be WETH");
        require(params.amountIn > 0, "No input tokens");
        require(feeBps <= 100, "Max 1% fee");

        // 1) Transfer tokens from user (could be deflationary => realIn < params.amountIn)
        IERC20 tokenIn = IERC20(params.tokenIn);
        uint256 balBefore = tokenIn.balanceOf(address(this));
        bool ok = tokenIn.transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );
        require(ok, "transferFrom failed");
        uint256 balAfter = tokenIn.balanceOf(address(this));
        uint256 realIn = balAfter - balBefore;
        require(realIn > 0, "No tokens arrived");

        // 2) Approve router if needed
        uint256 allowance = tokenIn.allowance(
            address(this),
            address(uniswapRouter)
        );
        if (allowance < realIn) {
            tokenIn.approve(address(uniswapRouter), type(uint256).max);
        }

        // 3) single-hop swap: tokenIn->WETH, recipient = address(this)
        ISwapRouter.ExactInputSingleParams memory singleParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: params.tokenIn,
                tokenOut: params.tokenOut,
                fee: params.feeTier,
                recipient: address(this),
                amountIn: realIn,
                amountOutMinimum: params.amountOutMin,
                sqrtPriceLimitX96: 0
            });

        uint256 wethReceived;
        // Use try/catch for error capturing
        try uniswapRouter.exactInputSingle(singleParams) returns (uint256 out) {
            wethReceived = out;
        } catch Error(string memory reason) {
            revert(
                string(
                    abi.encodePacked(
                        "UniswapV3 exactInputSingle error: ",
                        reason
                    )
                )
            );
        } catch (bytes memory) {
            revert("UniswapV3 exactInputSingle unknown error");
        }

        require(wethReceived > 0, "No WETH out from V3 swap");

        // 4) Unwrap WETH -> ETH
        uint256 oldEthBal = address(this).balance;
        (bool successUnwrap, ) = WETH.call(
            abi.encodeWithSignature("withdraw(uint256)", wethReceived)
        );
        require(successUnwrap, "WETH withdraw failed");
        uint256 newEthBal = address(this).balance;
        uint256 ethUnwrapped = newEthBal - oldEthBal;
        require(ethUnwrapped > 0, "No ETH unwrapped");

        // 5) Fee in ETH
        uint256 feeAmount = _calculateFee(ethUnwrapped, feeBps);
        uint256 ethAfterFee = ethUnwrapped - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer failed");

        // 6) Send net ETH to user
        (bool sentUser, ) = params.recipient.call{value: ethAfterFee}("");
        require(sentUser, "ETH transfer failed");

        emit Sell(
            msg.sender,
            params.tokenIn,
            realIn,
            ethUnwrapped,
            ethAfterFee,
            feeAmount
        );
    }

    /**
     * @notice VIVIBuy => ETH->tokens with an ETH fee, single-hop.
     *         user => pay ETH => take fee => wrap WETH => swap WETH->tokenOut.
     * @param params Must have tokenIn == WETH for single-hop from WETH to tokenOut
     * @param feeBps e.g. 50 => 0.5%, 100 => 1%.
     */
    function VIVIBuy(
        SwapParams calldata params,
        uint256 feeBps
    ) external payable nonReentrant {
        require(params.tokenIn == WETH, "tokenIn must be WETH");
        require(msg.value > 0, "No ETH sent");
        require(feeBps <= 100, "Max 1% fee");

        // 1) Fee in ETH
        uint256 feeAmount = _calculateFee(msg.value, feeBps);
        uint256 ethAfterFee = msg.value - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer fail");

        // 2) Wrap leftover ETH into WETH
        (bool successWrap, ) = WETH.call{value: ethAfterFee}(
            abi.encodeWithSignature("deposit()")
        );
        require(successWrap, "WETH deposit fail");

        // 3) Approve WETH to router
        uint256 wBal = IERC20(WETH).balanceOf(address(this));
        IERC20(WETH).approve(address(uniswapRouter), wBal);

        // 4) single-hop swap: WETH->tokenOut
        ISwapRouter.ExactInputSingleParams memory singleParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: params.tokenOut,
                fee: params.feeTier,
                recipient: params.recipient,
                amountIn: wBal,
                amountOutMinimum: params.amountOutMin,
                sqrtPriceLimitX96: 0
            });

        uint256 tokensOut;
        // Use try/catch for error capturing
        try uniswapRouter.exactInputSingle(singleParams) returns (uint256 out) {
            tokensOut = out;
        } catch Error(string memory reason) {
            revert(
                string(
                    abi.encodePacked(
                        "UniswapV3 exactInputSingle error: ",
                        reason
                    )
                )
            );
        } catch (bytes memory) {
            revert("UniswapV3 exactInputSingle unknown error");
        }

        require(tokensOut > 0, "No tokens out from v3 swap");

        emit Buy(
            msg.sender,
            params.tokenOut,
            msg.value,
            ethAfterFee,
            tokensOut,
            feeAmount
        );
    }

    receive() external payable {}
}

/**
 * @dev Minimal Uniswap V3 SwapRouter interface for single-hop.
 *      Adjust if you need multi-hop or advanced features.
 */
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
