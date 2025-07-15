// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../utils/VIVIFeeManager.sol";

interface IApeStoreRouter {
    function buy(
        address token,
        uint256 ethAmount,
        uint256 minOut,
        bytes calldata signature
    ) external payable;

    function sell(
        address token,
        uint256 amount,
        uint256 minOut,
        bytes calldata signature
    ) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
}

contract VIVIApeStore is ReentrancyGuard, VIVIFeeManager {
    struct BuyParams {
        address token;
        uint256 minOut;
        bytes signature;
        address recipient;
    }

    struct SellParams {
        address token;
        uint256 amount;
        uint256 minOut;
        bytes signature;
        address recipient;
    }

    address public immutable apeStoreRouter;

    event TokensHeld(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event Buy(
        address indexed user,
        address indexed token,
        uint256 ethIn,
        uint256 ethInAfterFee,
        uint256 tokensOut,
        uint256 feeAmount
    );

    event Sell(
        address indexed user,
        address indexed token,
        uint256 tokensIn,
        uint256 ethOut,
        uint256 ethOutAfterFee,
        uint256 feeAmount
    );

    constructor(
        address _apeStoreRouter,
        address _feeReceiver
    ) VIVIFeeManager(_feeReceiver) {
        require(_apeStoreRouter != address(0), "Invalid router");
        apeStoreRouter = _apeStoreRouter;
    }

    /**
     * @notice VIVIBuy para ApeStore - ETH->tokens con fee
     * @param params Parámetros de compra
     * @param feeBps Fee en basis points (ej: 50 = 0.5%, 100 = 1%)
     * @param additionalFeeReceivers Optional array of additional fee receivers with their BPS
     */
    function VIVIBuy(
        BuyParams calldata params,
        uint256 feeBps,
        FeeReceiver[] calldata additionalFeeReceivers
    ) external payable nonReentrant {
        require(params.token != address(0), "Invalid token");
        require(msg.value > 0, "No ETH sent");
        require(feeBps <= 1000, "Fee too high (max 10%)");
        require(params.recipient != address(0), "Invalid recipient");

        // 1) Calcular fee y monto para el router
        uint256 feeAmount = _calculateFee(msg.value, feeBps);
        uint256 ethForRouter = msg.value - feeAmount;

        require(ethForRouter > 0, "Insufficient ETH after fee");

        // 2) Distribuir fees a receptores adicionales primero
        uint256 remainingFee = _distributeFees(
            feeAmount,
            additionalFeeReceivers
        );

        // 3) Enviar fee restante al receptor por defecto
        _sendToDefaultReceiver(remainingFee);

        // 4) Medir balance de tokens antes del swap
        uint256 balanceBefore = IERC20(params.token).balanceOf(address(this));

        // 5) Ejecutar compra en ApeStore
        IApeStoreRouter(apeStoreRouter).buy{value: ethForRouter}(
            params.token,
            ethForRouter,
            params.minOut,
            params.signature
        );

        // 6) Calcular tokens recibidos
        uint256 balanceAfter = IERC20(params.token).balanceOf(address(this));
        uint256 tokensReceived = balanceAfter - balanceBefore;

        // 7) Transferir tokens al recipient
        if (tokensReceived > 0) {
            try
                IERC20(params.token).transfer(params.recipient, tokensReceived)
            returns (bool success) {
                require(success, "Token transfer failed");
            } catch {
                // Si falla el transfer, emitir evento para manual recovery
                emit TokensHeld(params.recipient, params.token, tokensReceived);
            }
        }

        emit Buy(
            msg.sender,
            params.token,
            msg.value,
            ethForRouter,
            tokensReceived,
            feeAmount
        );
    }

    /**
     * @notice VIVISell para ApeStore - tokens->ETH con fee
     * @param params Parámetros de venta
     * @param feeBps Fee en basis points (ej: 50 = 0.5%, 100 = 1%)
     * @param additionalFeeReceivers Optional array of additional fee receivers with their BPS
     */
    function VIVISell(
        SellParams calldata params,
        uint256 feeBps,
        FeeReceiver[] calldata additionalFeeReceivers
    ) external nonReentrant {
        require(params.token != address(0), "Invalid token");
        require(params.amount > 0, "Invalid amount");
        require(feeBps <= 1000, "Fee too high (max 10%)");
        require(params.recipient != address(0), "Invalid recipient");

        // 1) Transferir tokens del usuario a este contrato
        bool received = IERC20(params.token).transferFrom(
            msg.sender,
            address(this),
            params.amount
        );
        require(received, "Token transferFrom failed");

        // 2) Aprobar tokens al router si es necesario
        uint256 currentAllowance = IERC20(params.token).allowance(
            address(this),
            apeStoreRouter
        );
        if (currentAllowance < params.amount) {
            bool approved = IERC20(params.token).approve(
                apeStoreRouter,
                type(uint256).max
            );
            require(approved, "Token approval failed");
        }

        // 3) Medir ETH antes del swap
        uint256 ethBefore = address(this).balance;

        // 4) Ejecutar venta en ApeStore
        IApeStoreRouter(apeStoreRouter).sell(
            params.token,
            params.amount,
            params.minOut,
            params.signature
        );

        // 5) Calcular ETH recibido
        uint256 ethAfter = address(this).balance;
        uint256 ethReceived = ethAfter - ethBefore;
        require(ethReceived > 0, "No ETH received");

        // 6) Calcular fee y ETH para el usuario
        uint256 feeAmount = _calculateFee(ethReceived, feeBps);
        uint256 ethForUser = ethReceived - feeAmount;

        // 7) Distribuir fees a receptores adicionales primero
        uint256 remainingFee = _distributeFees(
            feeAmount,
            additionalFeeReceivers
        );

        // 8) Enviar fee restante al receptor por defecto
        _sendToDefaultReceiver(remainingFee);

        // 9) Enviar ETH al recipient
        (bool userSuccess, ) = params.recipient.call{value: ethForUser}("");
        require(userSuccess, "ETH transfer failed");

        emit Sell(
            msg.sender,
            params.token,
            params.amount,
            ethReceived,
            ethForUser,
            feeAmount
        );
    }

    /**
     * @notice Función para recibir ETH
     */
    receive() external payable {}

    /**
     * @notice Función de emergencia para retirar ETH bloqueado
     */
    function emergencyWithdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "ETH withdrawal failed");
    }

    /**
     * @notice Función de emergencia para retirar tokens bloqueados
     */
    function emergencyWithdrawToken(address token) external onlyOwner {
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");

        bool success = tokenContract.transfer(owner(), balance);
        require(success, "Token withdrawal failed");
    }

    /**
     * @notice Función para recuperar tokens que quedaron bloqueados en el contrato
     * @dev Solo el owner puede ejecutar esto para casos de emergencia
     */
    function recoverTokensFor(
        address token,
        address user,
        uint256 amount
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(user != address(0), "Invalid user");
        require(amount > 0, "Invalid amount");

        IERC20 tokenContract = IERC20(token);
        require(
            tokenContract.balanceOf(address(this)) >= amount,
            "Insufficient token balance"
        );

        bool success = tokenContract.transfer(user, amount);
        require(success, "Token recovery failed");
    }
}
