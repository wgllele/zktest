// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface ICurveAavePool {
    function offpeg_fee_multiplier() external view returns(uint256);
    function A_precise() external view returns(uint256);
    function fee() external view returns(uint256);
    function balances(uint256 i) external view returns(uint256);
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns(uint256 dy);
}