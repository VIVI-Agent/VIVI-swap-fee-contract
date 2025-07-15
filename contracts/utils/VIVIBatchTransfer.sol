// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VIVIBatchTransfer
 * @dev Contrato para realizar transferencias en batch de tokens ERC20
 * @dev Permite a cualquier dirección transferir tokens ERC20 a múltiples destinatarios en una sola transacción
 */
contract VIVIBatchTransfer is Ownable, ReentrancyGuard {
    // Eventos
    event BatchTransferCompleted(
        address indexed token,
        address indexed sender,
        uint256 totalAmount,
        uint256 recipientCount
    );

    event SingleTransferFailed(
        address indexed token,
        address indexed recipient,
        uint256 amount,
        string reason
    );

    // Estructuras
    struct TransferData {
        address recipient;
        uint256 amount;
    }

    // Variables de estado
    mapping(address => bool) public authorizedTokens;
    bool public onlyAuthorizedTokens;
    uint256 public maxRecipientsPerBatch;

    // Modificadores
    modifier validToken(address token) {
        require(token != address(0), "Token address cannot be zero");
        if (onlyAuthorizedTokens) {
            require(authorizedTokens[token], "Token not authorized");
        }
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
        onlyAuthorizedTokens = false; // Por defecto permite todos los tokens
    }

    /**
     * @dev Realiza transferencias en batch de tokens ERC20
     * @param token Dirección del contrato del token ERC20
     * @param transfers Array de estructuras TransferData con destinatarios y cantidades
     */
    function batchTransfer(
        address token,
        TransferData[] calldata transfers
    ) external nonReentrant validToken(token) validBatchSize(transfers.length) {
        require(transfers.length > 0, "No transfers specified");

        IERC20 erc20Token = IERC20(token);
        uint256 totalAmount = 0;
        uint256 successfulTransfers = 0;

        // Calcular el total requerido
        for (uint256 i = 0; i < transfers.length; i++) {
            require(
                transfers[i].recipient != address(0),
                "Invalid recipient address"
            );
            require(
                transfers[i].amount > 0,
                "Transfer amount must be greater than 0"
            );
            totalAmount += transfers[i].amount;
        }

        // Verificar que el sender tenga suficiente balance
        require(
            erc20Token.balanceOf(msg.sender) >= totalAmount,
            "Insufficient token balance"
        );

        // Verificar que el contrato tenga suficiente allowance
        require(
            erc20Token.allowance(msg.sender, address(this)) >= totalAmount,
            "Insufficient token allowance"
        );

        // Realizar las transferencias
        for (uint256 i = 0; i < transfers.length; i++) {
            try
                erc20Token.transferFrom(
                    msg.sender,
                    transfers[i].recipient,
                    transfers[i].amount
                )
            returns (bool success) {
                if (success) {
                    successfulTransfers++;
                } else {
                    emit SingleTransferFailed(
                        token,
                        transfers[i].recipient,
                        transfers[i].amount,
                        "Transfer returned false"
                    );
                }
            } catch Error(string memory reason) {
                emit SingleTransferFailed(
                    token,
                    transfers[i].recipient,
                    transfers[i].amount,
                    reason
                );
            } catch {
                emit SingleTransferFailed(
                    token,
                    transfers[i].recipient,
                    transfers[i].amount,
                    "Unknown error"
                );
            }
        }

        require(successfulTransfers > 0, "All transfers failed");

        emit BatchTransferCompleted(
            token,
            msg.sender,
            totalAmount,
            successfulTransfers
        );
    }

    /**
     * @dev Versión simplificada que requiere que todas las transferencias sean exitosas
     * @param token Dirección del contrato del token ERC20
     * @param recipients Array de direcciones destinatarias
     * @param amounts Array de cantidades a transferir
     */
    function batchTransferSimple(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    )
        external
        nonReentrant
        validToken(token)
        validBatchSize(recipients.length)
    {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "No transfers specified");

        IERC20 erc20Token = IERC20(token);
        uint256 totalAmount = 0;

        // Calcular el total y validar
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");
            require(amounts[i] > 0, "Transfer amount must be greater than 0");
            totalAmount += amounts[i];
        }

        // Verificar balance y allowance
        require(
            erc20Token.balanceOf(msg.sender) >= totalAmount,
            "Insufficient token balance"
        );
        require(
            erc20Token.allowance(msg.sender, address(this)) >= totalAmount,
            "Insufficient token allowance"
        );

        // Realizar todas las transferencias
        for (uint256 i = 0; i < recipients.length; i++) {
            require(
                erc20Token.transferFrom(msg.sender, recipients[i], amounts[i]),
                "Transfer failed"
            );
        }

        emit BatchTransferCompleted(
            token,
            msg.sender,
            totalAmount,
            recipients.length
        );
    }

    /**
     * @dev Transferencia de la misma cantidad a múltiples destinatarios
     * @param token Dirección del contrato del token ERC20
     * @param recipients Array de direcciones destinatarias
     * @param amountEach Cantidad a transferir a cada destinatario
     */
    function batchTransferEqual(
        address token,
        address[] calldata recipients,
        uint256 amountEach
    )
        external
        nonReentrant
        validToken(token)
        validBatchSize(recipients.length)
    {
        require(recipients.length > 0, "No recipients specified");
        require(amountEach > 0, "Amount must be greater than 0");

        IERC20 erc20Token = IERC20(token);
        uint256 totalAmount = amountEach * recipients.length;

        // Verificar balance y allowance
        require(
            erc20Token.balanceOf(msg.sender) >= totalAmount,
            "Insufficient token balance"
        );
        require(
            erc20Token.allowance(msg.sender, address(this)) >= totalAmount,
            "Insufficient token allowance"
        );

        // Realizar las transferencias
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");
            require(
                erc20Token.transferFrom(msg.sender, recipients[i], amountEach),
                "Transfer failed"
            );
        }

        emit BatchTransferCompleted(
            token,
            msg.sender,
            totalAmount,
            recipients.length
        );
    }

    // Funciones de administración

    /**
     * @dev Autoriza un token para ser usado en el contrato (solo si onlyAuthorizedTokens está activo)
     */
    function authorizeToken(address token) external onlyOwner {
        authorizedTokens[token] = true;
    }

    /**
     * @dev Desautoriza un token
     */
    function unauthorizeToken(address token) external onlyOwner {
        authorizedTokens[token] = false;
    }

    /**
     * @dev Activa/desactiva el modo de solo tokens autorizados
     */
    function setOnlyAuthorizedTokens(
        bool _onlyAuthorizedTokens
    ) external onlyOwner {
        onlyAuthorizedTokens = _onlyAuthorizedTokens;
    }

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
     * @dev Calcula el total de tokens necesarios para un batch transfer
     */
    function calculateTotalAmount(
        TransferData[] calldata transfers
    ) external pure returns (uint256 totalAmount) {
        for (uint256 i = 0; i < transfers.length; i++) {
            totalAmount += transfers[i].amount;
        }
    }

    /**
     * @dev Verifica si una dirección puede realizar un batch transfer
     */
    function canPerformBatchTransfer(
        address sender,
        address token,
        uint256 totalAmount
    ) external view returns (bool) {
        if (token == address(0)) return false;
        if (onlyAuthorizedTokens && !authorizedTokens[token]) return false;

        IERC20 erc20Token = IERC20(token);
        return
            erc20Token.balanceOf(sender) >= totalAmount &&
            erc20Token.allowance(sender, address(this)) >= totalAmount;
    }
}
