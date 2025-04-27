// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

interface IAerodromePairV2 {
    function getAmountOut(uint256,address)external returns (uint256);
}