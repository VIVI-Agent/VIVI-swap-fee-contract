// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VIVIVirtualsHop
 * @notice Enables multi-hop swaps on Uniswap V2 with fixed Virtuals routing and ETH fees.
 *         Buy: ETH → VIRTUAL → TOKEN
 *         Sell: TOKEN → VIRTUAL → ETH
 */
contract VIVIVirtualsHop is ReentrancyGuard, Ownable {
    /**
     * @dev MultiHopParams for Virtuals routing:
     *  - tokenTarget => the final token (for buy) or initial token (for sell)
     *  - recipient => who receives the output
     *  - deadline => tx must finalize before this timestamp
     *  - slippagePercent => slippage tolerance (0-50%)
     *  - amountIn => for sell operations, how many tokens to swap
     */
    struct MultiHopParams {
        address tokenTarget;
        address recipient;
        uint256 deadline;
        uint256 slippagePercent;
        uint256 amountIn; // Only used for sell
    }

    address public feeReceiver;
    IUniswapV2Router02 public uniswapRouter;
    address public WETH;
    address public VIRTUAL;

    event FeeReceiverUpdated(address indexed newFeeReceiver);
    event RouterUpdated(address indexed newRouter);
    event TokenAddressUpdated(string tokenName, address indexed newAddress);

    /**
     * @dev Sell event (tokens->ETH via Virtuals routing).
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
     * @dev Buy event (ETH->tokens via Virtuals routing).
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
     * @param _v2Router Address of the Uniswap V2 router
     * @param _feeReceiver Address to which fees are sent
     * @param _weth Address of the WETH token
     * @param _virtual Address of the VIRTUAL token
     */
    constructor(
        address _v2Router,
        address _feeReceiver,
        address _weth,
        address _virtual
    ) Ownable(msg.sender) {
        require(_v2Router != address(0), "Invalid router");
        require(_feeReceiver != address(0), "Invalid feeReceiver");
        require(_weth != address(0), "Invalid WETH");
        require(_virtual != address(0), "Invalid VIRTUAL");

        uniswapRouter = IUniswapV2Router02(_v2Router);
        feeReceiver = _feeReceiver;
        WETH = _weth;
        VIRTUAL = _virtual;
    }

    /**
     * @notice Updates the fee receiver address.
     */
    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        require(_feeReceiver != address(0), "feeReceiver=0");
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdated(_feeReceiver);
    }

    /**
     * @notice Updates the Uniswap V2 router address.
     */
    function setRouter(address _v2Router) external onlyOwner {
        require(_v2Router != address(0), "router=0");
        uniswapRouter = IUniswapV2Router02(_v2Router);
        emit RouterUpdated(_v2Router);
    }

    /**
     * @notice Updates token addresses.
     */
    function setWETH(address _newWETH) external onlyOwner {
        require(_newWETH != address(0), "WETH=0");
        WETH = _newWETH;
        emit TokenAddressUpdated("WETH", _newWETH);
    }

    function setVIRTUAL(address _newVIRTUAL) external onlyOwner {
        require(_newVIRTUAL != address(0), "VIRTUAL=0");
        VIRTUAL = _newVIRTUAL;
        emit TokenAddressUpdated("VIRTUAL", _newVIRTUAL);
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
     * @notice VIVIVirtualsSell => tokens->ETH via TOKEN → VIRTUAL → ETH
     * @param params MultiHop parameters
     * @param feeBps Fee in basis points (max 100 = 1%)
     */
    function VIVIVirtualsSell(
        MultiHopParams calldata params,
        uint256 feeBps
    ) external nonReentrant {
        require(params.amountIn > 0, "No input tokens");
        require(feeBps <= 100, "Max 1% fee");
        require(params.slippagePercent <= 50, "slippage>50%");
        require(
            params.tokenTarget != WETH && params.tokenTarget != VIRTUAL,
            "Invalid target token"
        );

        // 1) Transfer tokens from user
        IERC20 tokenIn = IERC20(params.tokenTarget);
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

        // 3) Build path: TOKEN → VIRTUAL → WETH
        address[] memory path = new address[](3);
        path[0] = params.tokenTarget; // TOKEN
        path[1] = VIRTUAL; // VIRTUAL
        path[2] = WETH; // WETH

        // 4) Calculate slippage protection
        uint256 amountOutMin;
        try uniswapRouter.getAmountsOut(realIn, path) returns (
            uint256[] memory amounts
        ) {
            uint256 expectedEth = amounts[amounts.length - 1];
            amountOutMin = (expectedEth * (100 - params.slippagePercent)) / 100;
        } catch Error(string memory reason) {
            revert(
                string(
                    abi.encodePacked("UniswapV2 getAmountsOut error: ", reason)
                )
            );
        } catch (bytes memory) {
            revert("UniswapV2 getAmountsOut unknown error");
        }

        // 5) Measure ETH balance before swap
        uint256 ethBefore = address(this).balance;

        // 6) Multi-hop swap
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            realIn,
            amountOutMin,
            path,
            address(this),
            params.deadline
        );

        uint256 ethAfter = address(this).balance;
        uint256 ethReceived = ethAfter - ethBefore;
        require(ethReceived > 0, "No ETH from swap");

        // 7) Fee in ETH
        uint256 feeAmount = _calculateFee(ethReceived, feeBps);
        uint256 ethAfterFee = ethReceived - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer failed");

        // 8) Send net ETH to user
        (bool sentUser, ) = params.recipient.call{value: ethAfterFee}("");
        require(sentUser, "ETH transfer failed");

        emit Sell(
            msg.sender,
            params.tokenTarget,
            realIn,
            ethReceived,
            ethAfterFee,
            feeAmount
        );
    }

    /**
     * @notice VIVIVirtualsBuy => ETH->tokens via ETH → VIRTUAL → TOKEN
     * @param params MultiHop parameters
     * @param feeBps Fee in basis points (max 100 = 1%)
     */
    function VIVIVirtualsBuy(
        MultiHopParams calldata params,
        uint256 feeBps
    ) external payable nonReentrant {
        require(msg.value > 0, "No ETH sent");
        require(feeBps <= 100, "Max 1% fee");
        require(params.slippagePercent <= 50, "slippage>50%");
        require(
            params.tokenTarget != WETH && params.tokenTarget != VIRTUAL,
            "Invalid target token"
        );

        // 1) Fee in ETH
        uint256 feeAmount = _calculateFee(msg.value, feeBps);
        uint256 ethAfterFee = msg.value - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer failed");

        // 2) Build path: WETH → VIRTUAL → TOKEN
        address[] memory path = new address[](3);
        path[0] = WETH; // WETH
        path[1] = VIRTUAL; // VIRTUAL
        path[2] = params.tokenTarget; // TOKEN

        // 3) Calculate slippage protection
        uint256 amountOutMin;
        try uniswapRouter.getAmountsOut(ethAfterFee, path) returns (
            uint256[] memory amounts
        ) {
            uint256 expectedTokens = amounts[amounts.length - 1];
            amountOutMin =
                (expectedTokens * (100 - params.slippagePercent)) /
                100;
        } catch Error(string memory reason) {
            revert(
                string(
                    abi.encodePacked("UniswapV2 getAmountsOut error: ", reason)
                )
            );
        } catch (bytes memory) {
            revert("UniswapV2 getAmountsOut unknown error");
        }

        // 4) Measure token balance before swap
        uint256 tokensBefore = IERC20(params.tokenTarget).balanceOf(
            params.recipient
        );

        // 5) Multi-hop swap
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAfterFee
        }(amountOutMin, path, params.recipient, params.deadline);

        uint256 tokensAfter = IERC20(params.tokenTarget).balanceOf(
            params.recipient
        );
        uint256 tokensOut = tokensAfter - tokensBefore;

        require(tokensOut > 0, "No tokens from swap");

        emit Buy(
            msg.sender,
            params.tokenTarget,
            msg.value,
            ethAfterFee,
            tokensOut,
            feeAmount
        );
    }

    receive() external payable {}
}
