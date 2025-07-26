// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VIVIMixedBatchTransfer
 * @dev Contrato simplificado para realizar transferencias en batch de tokens ERC20 y ETH simultáneamente
 * @dev Permite transferir la misma cantidad de tokens y ETH a múltiples destinatarios en una sola transacción
 */
contract VIVIMixedBatchTransfer is Ownable, ReentrancyGuard {
    // Eventos
    event MixedBatchTransferCompleted(
        address indexed token,
        address indexed sender,
        uint256 totalTokenAmount,
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
    modifier validToken(address token) {
        require(token != address(0), "Token address cannot be zero");
        _;
    }

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
     * @dev Transferir la misma cantidad de tokens y ETH a múltiples destinatarios
     * @param token Dirección del contrato del token ERC20
     * @param recipients Array de direcciones destinatarias
     * @param tokenAmountEach Cantidad de tokens a transferir a cada destinatario
     * @param ethAmountEach Cantidad de ETH a transferir a cada destinatario
     */
    function mixedBatchTransferEqual(
        address token,
        address[] calldata recipients,
        uint256 tokenAmountEach,
        uint256 ethAmountEach
    )
        external
        payable
        nonReentrant
        validToken(token)
        validBatchSize(recipients.length)
    {
        require(recipients.length > 0, "No recipients specified");
        require(
            tokenAmountEach > 0 || ethAmountEach > 0,
            "Either token amount or ETH amount must be greater than 0"
        );

        IERC20 erc20Token = IERC20(token);
        uint256 totalTokenAmount = tokenAmountEach * recipients.length;
        uint256 totalEthAmount = ethAmountEach * recipients.length;

        // Verificar que se envió suficiente ETH
        require(msg.value >= totalEthAmount, "Insufficient ETH sent");

        // Verificar balance y allowance de tokens si es necesario
        if (totalTokenAmount > 0) {
            require(
                erc20Token.balanceOf(msg.sender) >= totalTokenAmount,
                "Insufficient token balance"
            );
            require(
                erc20Token.allowance(msg.sender, address(this)) >=
                    totalTokenAmount,
                "Insufficient token allowance"
            );
        }

        // Realizar las transferencias
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");

            // Transferir tokens si la cantidad es mayor a 0
            if (tokenAmountEach > 0) {
                require(
                    erc20Token.transferFrom(
                        msg.sender,
                        recipients[i],
                        tokenAmountEach
                    ),
                    "Token transfer failed"
                );
            }

            // Transferir ETH si la cantidad es mayor a 0
            if (ethAmountEach > 0) {
                (bool ethSuccess, ) = recipients[i].call{value: ethAmountEach}(
                    ""
                );
                require(ethSuccess, "ETH transfer failed");
            }
        }

        // Devolver ETH sobrante si existe
        uint256 remainingEth = msg.value - totalEthAmount;
        if (remainingEth > 0) {
            (bool refundSuccess, ) = msg.sender.call{value: remainingEth}("");
            require(refundSuccess, "ETH refund failed");
        }

        emit MixedBatchTransferCompleted(
            token,
            msg.sender,
            totalTokenAmount,
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
     * @dev Función de emergencia para recuperar tokens enviados accidentalmente al contrato
     */
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyOwner {
        require(token != address(0), "Invalid token address");
        IERC20(token).transfer(owner(), amount);
    }

    /**
     * @dev Función de emergencia para recuperar ETH enviado accidentalmente al contrato
     */
    function emergencyWithdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Funciones de vista

    /**
     * @dev Calcula el total de tokens y ETH necesarios para un equal batch transfer
     */
    function calculateTotalAmounts(
        uint256 recipientCount,
        uint256 tokenAmountEach,
        uint256 ethAmountEach
    ) external pure returns (uint256 totalTokenAmount, uint256 totalEthAmount) {
        totalTokenAmount = tokenAmountEach * recipientCount;
        totalEthAmount = ethAmountEach * recipientCount;
    }

    /**
     * @dev Verifica si una dirección puede realizar un mixed batch transfer
     */
    function canPerformMixedBatchTransfer(
        address sender,
        address token,
        uint256 totalTokenAmount,
        uint256 totalEthAmount
    ) external view returns (bool) {
        if (token == address(0)) return false;

        // Verificar balance de ETH del sender
        if (totalEthAmount > 0 && sender.balance < totalEthAmount) return false;

        // Verificar balance y allowance de tokens si es necesario
        if (totalTokenAmount > 0) {
            IERC20 erc20Token = IERC20(token);
            return
                erc20Token.balanceOf(sender) >= totalTokenAmount &&
                erc20Token.allowance(sender, address(this)) >= totalTokenAmount;
        }

        return true;
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
