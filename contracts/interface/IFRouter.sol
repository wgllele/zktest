// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface IFRouter {
    function sell(
        uint256 amountIn,
        address tokenAddress,
        address to
    ) external returns (uint256 amount, uint256 amountOut);
    function buy(
        uint256 amountIn,
        address tokenAddress,
        address to
    ) external returns (uint256 amount, uint256 amountOut);
}