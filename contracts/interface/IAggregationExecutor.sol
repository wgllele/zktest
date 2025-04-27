// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface IAggregationExecutor{
    function getFee0(uint amountIn)external view returns (
        address feeTo,
        uint feeAmount
    );
    function getFee1(uint amountIn)external view returns (
        address feeTo,
        uint feeAmount
    );
    function getFee2(uint amountIn,uint8 fee)external view returns (
        address feeTo,
        uint feeAmount
    );
    function updateFeeSeting(
        uint index,
        address feeTo,
        uint32 fee,
        uint32 base
    )external returns (bool);

    function SingleSwap(bytes memory swapData)external;
    function SingleSwapWithFee(bytes memory swapData)external;

    function SingleSwapForEth(bytes memory swapData)external;
    function SingleSwapForEthWithFee(bytes memory swapData)external;

    function SingleSwapFromEth(bytes memory swapData)external;
    function SingleSwapFromEthWithFee(bytes memory swapData)external;

    function AggregationSwap(bytes memory swapData)external;
    function AggregationSwapWithFee(bytes memory swapData)external;

    function AggregationSwapForEth(bytes memory swapData)external;
    function AggregationSwapForEthWithFee(bytes memory swapData)external;

    function AggregationSwapFromEth(bytes memory swapData)external;
    function AggregationSwapFromEthWithFee(bytes memory swapData)external ;

    function AggregationSwapFromEthDirect(bytes memory swapData)external;
    function AggregationSwapFromEthDirectWithFee(bytes memory swapData)external ;
}