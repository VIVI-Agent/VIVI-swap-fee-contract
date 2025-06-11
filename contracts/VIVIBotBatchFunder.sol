// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title VIVIBotBatchFunder
 * @dev Contrato optimizado para el bot de VIVI - distribuye ETH a múltiples wallets en una sola transacción
 * @dev Diseñado específicamente para resolver el problema de nonce cuando se crean múltiples wallets simultáneamente
 */
contract VIVIBotBatchFunder is Ownable, ReentrancyGuard {
    // Eventos
    event BatchFundingCompleted(
        address indexed sender,
        uint256 totalAmount,
        uint256 recipientCount,
        uint256 amountPerRecipient
    );

    event FundingFailed(
        address indexed recipient,
        uint256 amount,
        string reason
    );

    // Variables de configuración
    uint256 public maxRecipientsPerBatch;
    uint256 public minAmountPerRecipient;

    constructor() Ownable(msg.sender) {
        maxRecipientsPerBatch = 10; // Límite conservador para gas
        minAmountPerRecipient = 1000000000000000; // 0.001 ETH mínimo
    }

    /**
     * @dev Distribuye la misma cantidad de ETH a múltiples wallets
     * @param recipients Array de direcciones que recibirán ETH
     * @param amountPerRecipient Cantidad de ETH que recibirá cada wallet
     */
    function batchFundWallets(
        address[] calldata recipients,
        uint256 amountPerRecipient
    ) external payable nonReentrant {
        require(recipients.length > 0, "No recipients specified");
        require(
            recipients.length <= maxRecipientsPerBatch,
            "Too many recipients"
        );
        require(
            amountPerRecipient >= minAmountPerRecipient,
            "Amount too small"
        );

        uint256 totalRequired = amountPerRecipient * recipients.length;
        require(msg.value >= totalRequired, "Insufficient ETH sent");

        // Distribuir ETH a cada wallet
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            require(recipient != address(0), "Invalid recipient address");
            require(recipient != msg.sender, "Cannot fund sender address");

            (bool success, ) = recipient.call{value: amountPerRecipient}("");
            if (!success) {
                emit FundingFailed(
                    recipient,
                    amountPerRecipient,
                    "Transfer failed"
                );
                // Continuar con las siguientes transferencias en lugar de revertir todo
            }
        }

        // Devolver ETH sobrante si existe
        uint256 remainder = msg.value - totalRequired;
        if (remainder > 0) {
            (bool refundSuccess, ) = msg.sender.call{value: remainder}("");
            require(refundSuccess, "Refund failed");
        }

        emit BatchFundingCompleted(
            msg.sender,
            totalRequired,
            recipients.length,
            amountPerRecipient
        );
    }

    /**
     * @dev Función optimizada para el bot VIVI - distribuye cantidades específicas a cada wallet
     * @param recipients Array de direcciones
     * @param amounts Array de cantidades (debe tener la misma longitud que recipients)
     */
    function batchFundWalletsCustom(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable nonReentrant {
        require(recipients.length > 0, "No recipients specified");
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(
            recipients.length <= maxRecipientsPerBatch,
            "Too many recipients"
        );

        // Calcular total requerido
        uint256 totalRequired = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] >= minAmountPerRecipient, "Amount too small");
            totalRequired += amounts[i];
        }

        require(msg.value >= totalRequired, "Insufficient ETH sent");

        // Distribuir ETH
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 amount = amounts[i];

            require(recipient != address(0), "Invalid recipient address");
            require(recipient != msg.sender, "Cannot fund sender address");

            (bool success, ) = recipient.call{value: amount}("");
            if (!success) {
                emit FundingFailed(recipient, amount, "Transfer failed");
            }
        }

        // Devolver ETH sobrante
        uint256 remainder = msg.value - totalRequired;
        if (remainder > 0) {
            (bool refundSuccess, ) = msg.sender.call{value: remainder}("");
            require(refundSuccess, "Refund failed");
        }

        emit BatchFundingCompleted(
            msg.sender,
            totalRequired,
            recipients.length,
            0 // amountPerRecipient = 0 para custom amounts
        );
    }

    // Funciones de administración

    /**
     * @dev Configura el máximo número de destinatarios por batch
     */
    function setMaxRecipientsPerBatch(
        uint256 _maxRecipients
    ) external onlyOwner {
        require(_maxRecipients > 0, "Max recipients must be greater than 0");
        maxRecipientsPerBatch = _maxRecipients;
    }

    /**
     * @dev Configura la cantidad mínima por destinatario
     */
    function setMinAmountPerRecipient(uint256 _minAmount) external onlyOwner {
        minAmountPerRecipient = _minAmount;
    }

    /**
     * @dev Función de emergencia para recuperar ETH
     */
    function emergencyWithdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "Emergency withdrawal failed");
    }

    // Funciones de vista

    /**
     * @dev Calcula el total de ETH necesario para un batch funding
     */
    function calculateTotalRequired(
        uint256 recipientCount,
        uint256 amountPerRecipient
    ) external pure returns (uint256) {
        return recipientCount * amountPerRecipient;
    }

    /**
     * @dev Verifica si una dirección puede realizar un batch funding
     */
    function canPerformBatchFunding(
        address sender,
        uint256 recipientCount,
        uint256 amountPerRecipient
    ) external view returns (bool, string memory) {
        if (recipientCount == 0) {
            return (false, "No recipients");
        }

        if (recipientCount > maxRecipientsPerBatch) {
            return (false, "Too many recipients");
        }

        if (amountPerRecipient < minAmountPerRecipient) {
            return (false, "Amount too small");
        }

        uint256 totalRequired = recipientCount * amountPerRecipient;
        if (sender.balance < totalRequired) {
            return (false, "Insufficient balance");
        }

        return (true, "Can perform batch funding");
    }

    /**
     * @dev Función para recibir ETH directamente
     */
    receive() external payable {}

    /**
     * @dev Función fallback
     */
    fallback() external payable {}
}
