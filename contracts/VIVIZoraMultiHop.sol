// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VIVIZoraMultiHop
 * @notice Enables multi-hop swaps on Uniswap V3 with fixed Zora routing and ETH fees.
 *         Buy: ETH → USDC → ZORA → TOKEN (fees: 500, 3000, 10000)
 *         Sell: TOKEN → ZORA → USDC → ETH (fees: 10000, 3000, 500)
 */
contract VIVIZoraMultiHop is ReentrancyGuard, Ownable {
    /**
     * @dev MultiHopParams for Zora routing:
     *  - tokenTarget => the final token (for buy) or initial token (for sell)
     *  - recipient => who receives the output
     *  - deadline => tx must finalize before this timestamp
     *  - amountOutMin => slippage protection
     *  - amountIn => for sell operations, how many tokens to swap
     */
    struct MultiHopParams {
        address tokenTarget;
        address recipient;
        uint256 deadline;
        uint256 amountOutMin;
        uint256 amountIn; // Only used for sell
    }

    address public feeReceiver;
    ISwapRouter public uniswapRouter;
    address public WETH;
    address public USDC;
    address public ZORA;

    // Fixed fee tiers for Zora routing
    uint24 constant FEE_ETH_USDC = 500; // 0.05%
    uint24 constant FEE_USDC_ZORA = 3000; // 0.3%
    uint24 constant FEE_ZORA_TOKEN = 10000; // 1%

    event FeeReceiverUpdated(address indexed newFeeReceiver);
    event RouterUpdated(address indexed newRouter);
    event TokenAddressUpdated(string tokenName, address indexed newAddress);

    /**
     * @dev Sell event (tokens->ETH via Zora routing).
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
     * @dev Buy event (ETH->tokens via Zora routing).
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
     * @param _weth Address of the WETH token
     * @param _usdc Address of the USDC token
     * @param _zora Address of the ZORA token
     */
    constructor(
        address _v3Router,
        address _feeReceiver,
        address _weth,
        address _usdc,
        address _zora
    ) Ownable(msg.sender) {
        require(_v3Router != address(0), "Invalid router");
        require(_feeReceiver != address(0), "Invalid feeReceiver");
        require(_weth != address(0), "Invalid WETH");
        require(_usdc != address(0), "Invalid USDC");
        require(_zora != address(0), "Invalid ZORA");

        uniswapRouter = ISwapRouter(_v3Router);
        feeReceiver = _feeReceiver;
        WETH = _weth;
        USDC = _usdc;
        ZORA = _zora;
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
     * @notice Updates the Uniswap V3 router address.
     */
    function setRouter(address _v3Router) external onlyOwner {
        require(_v3Router != address(0), "router=0");
        uniswapRouter = ISwapRouter(_v3Router);
        emit RouterUpdated(_v3Router);
    }

    /**
     * @notice Updates token addresses.
     */
    function setWETH(address _newWETH) external onlyOwner {
        require(_newWETH != address(0), "WETH=0");
        WETH = _newWETH;
        emit TokenAddressUpdated("WETH", _newWETH);
    }

    function setUSDC(address _newUSDC) external onlyOwner {
        require(_newUSDC != address(0), "USDC=0");
        USDC = _newUSDC;
        emit TokenAddressUpdated("USDC", _newUSDC);
    }

    function setZORA(address _newZORA) external onlyOwner {
        require(_newZORA != address(0), "ZORA=0");
        ZORA = _newZORA;
        emit TokenAddressUpdated("ZORA", _newZORA);
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
     * @dev Builds the path for multi-hop swap.
     * @param tokenA First token
     * @param feeAB Fee between tokenA and tokenB
     * @param tokenB Second token
     * @param feeBC Fee between tokenB and tokenC
     * @param tokenC Third token
     * @param feeCD Fee between tokenC and tokenD
     * @param tokenD Fourth token
     */
    function _buildPath(
        address tokenA,
        uint24 feeAB,
        address tokenB,
        uint24 feeBC,
        address tokenC,
        uint24 feeCD,
        address tokenD
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                tokenA,
                feeAB,
                tokenB,
                feeBC,
                tokenC,
                feeCD,
                tokenD
            );
    }

    /**
     * @notice VIVIZoraSell => tokens->ETH via TOKEN → ZORA → USDC → ETH
     * @param params MultiHop parameters
     * @param feeBps Fee in basis points (max 100 = 1%)
     */
    function VIVIZoraSell(
        MultiHopParams calldata params,
        uint256 feeBps
    ) external nonReentrant {
        require(params.amountIn > 0, "No input tokens");
        require(feeBps <= 100, "Max 1% fee");
        require(
            params.tokenTarget != WETH &&
                params.tokenTarget != USDC &&
                params.tokenTarget != ZORA,
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

        // 3) Build path: TOKEN → ZORA → USDC → WETH
        bytes memory path = _buildPath(
            params.tokenTarget, // TOKEN
            FEE_ZORA_TOKEN, // 10000 (1%)
            ZORA, // ZORA
            FEE_USDC_ZORA, // 3000 (0.3%)
            USDC, // USDC
            FEE_ETH_USDC, // 500 (0.05%)
            WETH // WETH
        );

        // 4) Multi-hop swap
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter
            .ExactInputParams({
                path: path,
                recipient: address(this),
                amountIn: realIn,
                amountOutMinimum: params.amountOutMin
            });

        uint256 wethReceived;
        try uniswapRouter.exactInput(swapParams) returns (uint256 out) {
            wethReceived = out;
        } catch Error(string memory reason) {
            revert(
                string(abi.encodePacked("UniswapV3 exactInput error: ", reason))
            );
        } catch (bytes memory) {
            revert("UniswapV3 exactInput unknown error");
        }

        require(wethReceived > 0, "No WETH from multi-hop");

        // 5) Unwrap WETH -> ETH
        uint256 oldEthBal = address(this).balance;
        (bool successUnwrap, ) = WETH.call(
            abi.encodeWithSignature("withdraw(uint256)", wethReceived)
        );
        require(successUnwrap, "WETH withdraw failed");
        uint256 newEthBal = address(this).balance;
        uint256 ethUnwrapped = newEthBal - oldEthBal;
        require(ethUnwrapped > 0, "No ETH unwrapped");

        // 6) Fee in ETH
        uint256 feeAmount = _calculateFee(ethUnwrapped, feeBps);
        uint256 ethAfterFee = ethUnwrapped - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer failed");

        // 7) Send net ETH to user
        (bool sentUser, ) = params.recipient.call{value: ethAfterFee}("");
        require(sentUser, "ETH transfer failed");

        emit Sell(
            msg.sender,
            params.tokenTarget,
            realIn,
            ethUnwrapped,
            ethAfterFee,
            feeAmount
        );
    }

    /**
     * @notice VIVIZoraBuy => ETH->tokens via ETH → USDC → ZORA → TOKEN
     * @param params MultiHop parameters
     * @param feeBps Fee in basis points (max 100 = 1%)
     */
    function VIVIZoraBuy(
        MultiHopParams calldata params,
        uint256 feeBps
    ) external payable nonReentrant {
        require(msg.value > 0, "No ETH sent");
        require(feeBps <= 100, "Max 1% fee");
        require(
            params.tokenTarget != WETH &&
                params.tokenTarget != USDC &&
                params.tokenTarget != ZORA,
            "Invalid target token"
        );

        // 1) Fee in ETH
        uint256 feeAmount = _calculateFee(msg.value, feeBps);
        uint256 ethAfterFee = msg.value - feeAmount;

        (bool feeSent, ) = feeReceiver.call{value: feeAmount}("");
        require(feeSent, "Fee transfer failed");

        // 2) Wrap ETH into WETH
        (bool successWrap, ) = WETH.call{value: ethAfterFee}(
            abi.encodeWithSignature("deposit()")
        );
        require(successWrap, "WETH deposit failed");

        // 3) Approve WETH to router
        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        IERC20(WETH).approve(address(uniswapRouter), wethBalance);

        // 4) Build path: WETH → USDC → ZORA → TOKEN
        bytes memory path = _buildPath(
            WETH, // WETH
            FEE_ETH_USDC, // 500 (0.05%)
            USDC, // USDC
            FEE_USDC_ZORA, // 3000 (0.3%)
            ZORA, // ZORA
            FEE_ZORA_TOKEN, // 10000 (1%)
            params.tokenTarget // TOKEN
        );

        // 5) Multi-hop swap
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter
            .ExactInputParams({
                path: path,
                recipient: params.recipient,
                amountIn: wethBalance,
                amountOutMinimum: params.amountOutMin
            });

        uint256 tokensOut;
        try uniswapRouter.exactInput(swapParams) returns (uint256 out) {
            tokensOut = out;
        } catch Error(string memory reason) {
            revert(
                string(abi.encodePacked("UniswapV3 exactInput error: ", reason))
            );
        } catch (bytes memory) {
            revert("UniswapV3 exactInput unknown error");
        }

        require(tokensOut > 0, "No tokens from multi-hop");

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

/**
 * @dev Uniswap V3 SwapRouter interface for multi-hop swaps.
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

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut);
}
