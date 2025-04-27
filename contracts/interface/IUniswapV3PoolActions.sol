// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface IUniswapV3PoolActions {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    )external returns (
        int256 amount0,
        int256 amount1
    );
    function fee() external view returns (uint24);
    function isPool(address pool) external view returns (bool);
}