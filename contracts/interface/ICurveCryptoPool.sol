// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface ICurveCryptoPool {
    function exchange_underlying(uint256 i, uint256 j, uint256 _dx, uint256 _min_dy,address _receiver)external;
}