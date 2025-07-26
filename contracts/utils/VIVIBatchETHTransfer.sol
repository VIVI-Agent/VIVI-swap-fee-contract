// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title VIVIBatchETHTransfer
 * @dev Contrato para realizar transferencias en batch de ETH nativo
 * @dev Permite transferir cantidades específicas de ETH a múltiples destinatarios en una sola transacción
 */
contract VIVIBatchETHTransfer is Ownable, ReentrancyGuard {
    // Eventos
    event BatchETHTransferCompleted(
        address indexed sender,
        uint256 totalEthAmount,
        uint256 recipientCount
    );

    event ETHTransferFailed(
        address indexed recipient,
        uint256 amount,
        string reason
    );

    // Variables de estado
    uint256 public maxRecipientsPerBatch;

    // Modificadores
    modifier validBatchSize(uint256 batchSize) {
        require(batchSize > 0, "Batch size must be greater than 0");
        require(
            maxRecipientsPerBatch == 0 || batchSize <= maxRecipientsPerBatch,
            "Batch size exceeds maximum allowed"
        );
        _;
    }

    constructor() Ownable(msg.sender) {
        maxRecipientsPerBatch = 500; // Límite por defecto
    }

    /**
     * @dev Transferir la misma cantidad de ETH a múltiples destinatarios
     * @param recipients Array de direcciones destinatarias
     * @param ethAmountEach Cantidad de ETH a transferir a cada destinatario
     */
    function batchETHTransferEqual(
        address[] calldata recipients,
        uint256 ethAmountEach
    ) external payable nonReentrant validBatchSize(recipients.length) {
        require(recipients.length > 0, "No recipients specified");
        require(ethAmountEach > 0, "ETH amount must be greater than 0");

        uint256 totalEthAmount = ethAmountEach * recipients.length;

        // Verificar que se envió suficiente ETH
        require(msg.value >= totalEthAmount, "Insufficient ETH sent");

        // Realizar las transferencias
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");

            (bool ethSuccess, ) = recipients[i].call{value: ethAmountEach}("");
            require(ethSuccess, "ETH transfer failed");
        }

        // Devolver ETH sobrante si existe
        uint256 remainingEth = msg.value - totalEthAmount;
        if (remainingEth > 0) {
            (bool refundSuccess, ) = msg.sender.call{value: remainingEth}("");
            require(refundSuccess, "ETH refund failed");
        }

        emit BatchETHTransferCompleted(
            msg.sender,
            totalEthAmount,
            recipients.length
        );
    }

    /**
     * @dev Transferir cantidades específicas de ETH a múltiples destinatarios
     * @param recipients Array de direcciones destinatarias
     * @param amounts Array de cantidades de ETH a transferir a cada destinatario
     */
    function batchETHTransferCustom(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable nonReentrant validBatchSize(recipients.length) {
        require(recipients.length > 0, "No recipients specified");
        require(recipients.length == amounts.length, "Arrays length mismatch");

        uint256 totalEthAmount = 0;

        // Calcular total de ETH necesario
        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] > 0, "All amounts must be greater than 0");
            totalEthAmount += amounts[i];
        }

        // Verificar que se envió suficiente ETH
        require(msg.value >= totalEthAmount, "Insufficient ETH sent");

        // Realizar las transferencias
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");

            (bool ethSuccess, ) = recipients[i].call{value: amounts[i]}("");
            require(ethSuccess, "ETH transfer failed");
        }

        // Devolver ETH sobrante si existe
        uint256 remainingEth = msg.value - totalEthAmount;
        if (remainingEth > 0) {
            (bool refundSuccess, ) = msg.sender.call{value: remainingEth}("");
            require(refundSuccess, "ETH refund failed");
        }

        emit BatchETHTransferCompleted(
            msg.sender,
            totalEthAmount,
            recipients.length
        );
    }

    // Funciones de administración

    /**
     * @dev Establece el número máximo de destinatarios por batch
     */
    function setMaxRecipientsPerBatch(
        uint256 _maxRecipients
    ) external onlyOwner {
        maxRecipientsPerBatch = _maxRecipients;
    }

    /**
     * @dev Función de emergencia para recuperar ETH enviado accidentalmente al contrato
     */
    function emergencyWithdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Funciones de vista

    /**
     * @dev Calcula el total de ETH necesario para un equal batch transfer
     */
    function calculateTotalEthAmount(
        uint256 recipientCount,
        uint256 ethAmountEach
    ) external pure returns (uint256 totalEthAmount) {
        totalEthAmount = ethAmountEach * recipientCount;
    }

    /**
     * @dev Calcula el total de ETH necesario para un custom batch transfer
     */
    function calculateTotalEthAmountCustom(
        uint256[] calldata amounts
    ) external pure returns (uint256 totalEthAmount) {
        for (uint256 i = 0; i < amounts.length; i++) {
            totalEthAmount += amounts[i];
        }
    }

    /**
     * @dev Verifica si una dirección puede realizar un batch transfer
     */
    function canPerformBatchTransfer(
        address sender,
        uint256 totalEthAmount
    ) external view returns (bool) {
        return sender.balance >= totalEthAmount;
    }

    /**
     * @dev Función para recibir ETH directamente
     */
    receive() external payable {}

    /**
     * @dev Función fallback para recibir ETH
     */
    fallback() external payable {}
}
