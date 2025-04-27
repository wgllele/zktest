// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface ISwapRouterWithFee{
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x20[amountInMax(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **/
    function Buy(bytes memory swapData)external returns(uint amount);
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x20[amountInMax(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **[32+1+32+20+20+20+2+20=147字节]
    **/
    function Sell(bytes memory swapData)external returns(uint amount);

    /**
   ** 0x20[amountOutMin(32)]+
   ** 0x1[swapType(1)]+
   ** 0x14[recipient(20)]+
   ** 0x14[tokenOut(20)]+
   ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
   **/
    function BuyFromEth(
        bytes memory swapData
    )external payable returns(uint amount);

    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x20[amountInMax(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **/
    function SellForEth(
        bytes memory swapData
    )external returns(uint amount);
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x14[tokenOut(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **/
    function SimpleBuyFromEth(
        bytes memory swapData
    )external payable returns(uint amount);
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x20[amountInMax(32)]+
    ** 0x14[tokenIn(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **/
    function SimpleSellForEth(
        bytes memory swapData
    )external returns(uint amount);
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x20[amountInMax(32)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **/
    function SimpleBuy(
        bytes memory swapData
    )external returns(uint amount);
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x20[amountInMax(32)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **/
    function SimpleSell(
        bytes memory swapData
    )external returns(uint amount);
}