// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IApeStoreRouter {
    function buy(
        address token,
        uint256 ethAmount,
        uint256 minOut,
        bytes calldata signature
    ) external payable;
}

contract ApeStoreWrapper {
    address public apeStoreRouter;

    constructor(address _apeStoreRouter) {
        apeStoreRouter = _apeStoreRouter;
    }

    function executeBuy(
        address token,
        uint256 ethAmount,
        uint256 minOut,
        bytes calldata signature
    ) external payable {
        require(msg.value == ethAmount, "Incorrect ETH amount sent");

        IApeStoreRouter(apeStoreRouter).buy{value: msg.value}(
            token,
            ethAmount,
            minOut,
            signature
        );
    }
}
