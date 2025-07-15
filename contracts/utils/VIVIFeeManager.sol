// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VIVIFeeManager
 * @notice Base contract for managing fee distribution to multiple receivers
 */
contract VIVIFeeManager is Ownable {
    struct FeeReceiver {
        address receiver;
        uint256 bps; // basis points (100 = 1%)
    }

    address public defaultFeeReceiver;

    event DefaultFeeReceiverUpdated(address indexed newFeeReceiver);
    event FeeDistributed(
        address indexed user,
        uint256 totalFeeAmount,
        address[] receivers,
        uint256[] amounts
    );

    constructor(address _defaultFeeReceiver) Ownable(msg.sender) {
        require(
            _defaultFeeReceiver != address(0),
            "Default fee receiver cannot be zero"
        );
        defaultFeeReceiver = _defaultFeeReceiver;
    }

    /**
     * @notice Set the default fee receiver
     * @param _defaultFeeReceiver New default fee receiver address
     */
    function setDefaultFeeReceiver(
        address _defaultFeeReceiver
    ) external onlyOwner {
        require(
            _defaultFeeReceiver != address(0),
            "Default fee receiver cannot be zero"
        );
        defaultFeeReceiver = _defaultFeeReceiver;
        emit DefaultFeeReceiverUpdated(_defaultFeeReceiver);
    }

    /**
     * @notice Calculate fee amount in basis points
     * @param amount Total amount to calculate fee from
     * @param bps Basis points (100 = 1%)
     * @return Fee amount
     */
    function _calculateFee(
        uint256 amount,
        uint256 bps
    ) internal pure returns (uint256) {
        return (amount * bps) / 10000;
    }

    /**
     * @notice Validate fee receivers array
     * @param feeReceivers Array of fee receivers with their BPS
     */
    function _validateFeeReceivers(
        FeeReceiver[] calldata feeReceivers
    ) internal pure {
        uint256 totalBps = 0;
        for (uint256 i = 0; i < feeReceivers.length; i++) {
            require(
                feeReceivers[i].receiver != address(0),
                "Fee receiver cannot be zero"
            );
            require(feeReceivers[i].bps > 0, "Fee BPS must be greater than 0");
            totalBps += feeReceivers[i].bps;
        }
        require(totalBps <= 10000, "Total BPS cannot exceed 100%");
    }

    /**
     * @notice Distribute fees to multiple receivers
     * @param totalFeeAmount Total fee amount to distribute
     * @param feeReceivers Array of additional fee receivers (optional)
     * @return remainingFeeAmount Amount remaining for default receiver
     */
    function _distributeFees(
        uint256 totalFeeAmount,
        FeeReceiver[] calldata feeReceivers
    ) internal returns (uint256 remainingFeeAmount) {
        remainingFeeAmount = totalFeeAmount;

        if (feeReceivers.length > 0) {
            _validateFeeReceivers(feeReceivers);

            address[] memory receivers = new address[](feeReceivers.length);
            uint256[] memory amounts = new uint256[](feeReceivers.length);

            for (uint256 i = 0; i < feeReceivers.length; i++) {
                uint256 feeAmount = _calculateFee(
                    totalFeeAmount,
                    feeReceivers[i].bps
                );
                if (feeAmount > 0) {
                    (bool success, ) = feeReceivers[i].receiver.call{
                        value: feeAmount
                    }("");
                    require(success, "Fee transfer failed");

                    remainingFeeAmount -= feeAmount;
                    receivers[i] = feeReceivers[i].receiver;
                    amounts[i] = feeAmount;
                }
            }

            emit FeeDistributed(msg.sender, totalFeeAmount, receivers, amounts);
        }

        return remainingFeeAmount;
    }

    /**
     * @notice Send remaining fee to default receiver
     * @param feeAmount Amount to send to default receiver
     */
    function _sendToDefaultReceiver(uint256 feeAmount) internal {
        if (feeAmount > 0) {
            (bool success, ) = defaultFeeReceiver.call{value: feeAmount}("");
            require(success, "Default fee transfer failed");
        }
    }
}
