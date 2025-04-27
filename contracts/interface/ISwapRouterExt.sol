// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
import "./ISwapRouter.sol";
interface ISwapRouterExt is ISwapRouter {
    struct PermitData {
        uint amountInMax;
        uint amountOutMin;
        uint deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
        address tokenIn;
        address tokenOut;
        address taker;
        address recipient;
    }

    function SwapWithPermit(
        PermitData memory permitData,
        bytes calldata swapTransactions
    )external returns(uint amount);

    function SwapForEthWithPermit(
        PermitData memory permitData,
        bytes calldata swapTransactions
    )external returns(uint amount);

    function MultiSwap(
        uint[] memory amountInMaxs,
        uint[] memory amountOutMins,
        address[] memory tokenIns,
        address[] memory tokenOuts,
        address recipient,
        uint deadline,
        bytes[] memory swapTransactions
    )external payable returns(uint[] memory amounts);

    function nonces(address operator) external view returns (uint256);
}