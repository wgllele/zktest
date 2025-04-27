// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    function isPool(address pool) external view returns (bool);
    function allPools(uint256 index) external view returns (address);
    function allPoolsLength() external view returns (uint256);
    function poolDeployer() external view returns (address);
}