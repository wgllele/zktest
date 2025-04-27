// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface ISwapRouter {
    function Swap(
        bytes memory swapData
    )external payable returns(uint amount);

    function AggregationSwapFromEthDirect(
        bytes memory swapData
    )external payable returns(uint amount);
}