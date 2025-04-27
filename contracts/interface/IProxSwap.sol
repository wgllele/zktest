// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface IProxSwap {
    function callThirdPartySwap(
        bytes memory paramData,
        bytes memory swapData
    ) external;

    function callThirdPartySwapOut(
        bytes memory paramData,
        bytes memory swapData
    ) external;
}
