// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface ISwapCallBack {
    function callBack(bytes memory data)external;
}