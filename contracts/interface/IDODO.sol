// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface IDODO {
    function sellBase(address to) external returns (uint256 receiveQuoteAmount);
    function sellQuote(address to) external returns (uint256 receiveBaseAmount);
    function sellBaseToken(
        uint256 amount,
        uint256 minReceiveQuote,
        bytes calldata data
    ) external returns (uint256);

    function buyBaseToken(
        uint256 amount,
        uint256 maxPayQuote,
        bytes calldata data
    ) external returns (uint256);
    function querySellBaseToken(uint256 amount) external view returns (uint256 receiveQuote);
}