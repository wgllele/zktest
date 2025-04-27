// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
import "./SwapRouterBase.sol";
import "../interface/ISwapRouterWithFee.sol";
abstract contract SwapRouterWithFee is SwapRouterBase,ISwapRouterWithFee{
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x20[amountInMax(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **/
    function Buy(bytes memory swapData)external whenNotPaused nonReentrant returns(uint amount){
        uint amountOutMin;
        uint amountInMax;
        address recipient;
        address tokenIn;
        address tokenOut;
        UintParam memory uintParam=UintParam(0,0,0);
        {
            uint8 swapType;
            uint16 feeRate;
            assembly {
                amountOutMin := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
                swapType := mload(add(add(swapData, 0x1), 0x20))//start:32(0x20),length:1
                amountInMax := mload(add(add(swapData, 0x20), 0x21))//start:33(0x21),length:32(0x20)
                recipient := shr(96, mload(add(add(swapData, 0x20), 0x41)))//start:65(0x41),length:20(0x14)
                tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x55)))//start:85(0x55),length:20(0x14)
                tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x69)))//start:105(0x69),length:20(0x14)
                feeRate := mload(add(add(swapData, 0x2), 0x7d))//start:125(0x7d),length:2(0x2)
            }
            uintParam.swapType=swapType;
            uintParam.feeRate=feeRate;
        }
        uint outBalBefore=getTokenBalanceOf(tokenOut,recipient);
        address feeTo;
        uint feeAmount;
        if(uintParam.swapType<2){
            (feeTo,feeAmount)=aggregationExecutor.getFee0(amountInMax);
        }else{
            (feeTo,feeAmount)=aggregationExecutor.getFee1(amountInMax);
        }
        amountInMax=amountInMax-feeAmount;//扣除手续费
        if(uintParam.feeRate<10000){//不需要回调支付
            address pair0;
            assembly {
                pair0 := shr(96, mload(add(add(swapData, 0x20), 0x7f)))//start:127(0x7f),length:20(0x14)
            }
            tokenTransferFrom(tokenIn,msg.sender,pair0,amountInMax);
        }else{//需要回调支付
            payer=msg.sender;
            srcToken=tokenIn;
            amountMax=amountInMax;
        }
        //amountOutMin(32)+swapType(1)+amountInMax(32)三个参数不需要,从0x41(65)开始,同时要把扣除手续费后的amountInMax传入aggregationExecutor合约
        if(uintParam.swapType==0||uintParam.swapType==2){
            aggregationExecutor.SingleSwap(abi.encodePacked(
                amountInMax,
                slice(swapData,0x41)
            ));
        }else{
            aggregationExecutor.SingleSwapWithFee(abi.encodePacked(
                amountInMax,
                slice(swapData,0x41)
            ));
        }
        amount=getTokenBalanceOf(tokenOut,recipient)-outBalBefore;
        if(amount<amountOutMin){//滑点保护
            revert OutIsLessThanOutMin();
        }
        tokenTransferFrom(tokenIn,msg.sender,feeTo,feeAmount);//转账手续费
    }
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
    function Sell(bytes memory swapData)external whenNotPaused nonReentrant returns(uint amount){
        uint amountOutMin;
        uint amountInMax;
        address recipient;
        address tokenIn;
        address tokenOut;
        UintParam memory uintParam=UintParam(0,0,0);
        {
            uint8 swapType;
            uint16 feeRate;
            assembly {
                amountOutMin := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
                swapType := mload(add(add(swapData, 0x1), 0x20))//start:32(0x20),length:1
                amountInMax := mload(add(add(swapData, 0x20), 0x21))//start:33(0x21),length:32(0x20)
                recipient := shr(96, mload(add(add(swapData, 0x20), 0x41)))//start:65(0x41),length:20(0x14)
                tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x55)))//start:85(0x55),length:20(0x14)
                tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x69)))//start:105(0x69),length:20(0x14)
                feeRate := mload(add(add(swapData, 0x2), 0x7d))//start:125(0x7d),length:2(0x2)
            }
            uintParam.swapType=swapType;
            uintParam.feeRate=feeRate;
        }
        uint outBalBefore=getTokenBalanceOf(tokenOut,address(this));
        if(uintParam.feeRate<10000){//不需要回调支付
            address pair0;
            assembly {
                pair0 := shr(96, mload(add(add(swapData, 0x20), 0x7f)))//start:127(0x7f),length:20(0x14)
            }
            tokenTransferFrom(tokenIn,msg.sender,pair0,amountInMax);
        }else{//需要回调支付
            payer=msg.sender;
            srcToken=tokenIn;
            amountMax=amountInMax;
        }
        //amountOutMin(32)+swapType(1)+amountInMax(32)+recipient(20)四个参数不需要,从0x55(85)开始,同时要把amountInMax,recipient(address(this))传入aggregationExecutor合约
        if(uintParam.swapType==0||uintParam.swapType==2){
            aggregationExecutor.SingleSwap(abi.encodePacked(
                amountInMax,
                address(this),
                slice(swapData,0x55)
            ));
        }else{
            aggregationExecutor.SingleSwapWithFee(abi.encodePacked(
                amountInMax,
                address(this),
                slice(swapData,0x55)
            ));
        }
        amount=getTokenBalanceOf(tokenOut,address(this))-outBalBefore;
        address feeTo;
        uint feeAmount;
        if(uintParam.swapType<2){
            (feeTo,feeAmount)=aggregationExecutor.getFee0(amount);
        }else{
            (feeTo,feeAmount)=aggregationExecutor.getFee1(amount);
        }
        amount=amount-feeAmount;//扣除手续费
        if(amount<amountOutMin){//滑点保护
            revert OutIsLessThanOutMin();
        }
        tokenTransfer(tokenOut,recipient,amount);
        tokenTransfer(tokenOut,feeTo,feeAmount);//转账手续费
    }

    /**
   ** 0x20[amountOutMin(32)]+
   ** 0x1[swapType(1)]+
   ** 0x14[recipient(20)]+
   ** 0x14[tokenOut(20)]+
   ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
   **/
    function BuyFromEth(
        bytes memory swapData
    )external payable whenNotPaused nonReentrant returns(uint amount){
        uint amountOutMin;
        uint amountInMax=msg.value;
        address recipient;
        address tokenOut;
        UintParam memory uintParam=UintParam(0,0,0);
        {
            uint8 swapType;
            uint16 feeRate;
            assembly {
                amountOutMin := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
                swapType := mload(add(add(swapData, 0x1), 0x20))//start:32(0x20),length:1
                recipient := shr(96, mload(add(add(swapData, 0x20), 0x21)))//start:33(0x21),length:20(0x14)
                tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x35)))//start:53(0x35),length:20(0x14)
                feeRate := mload(add(add(swapData, 0x2), 0x49))//start:73(0x49),length:2(0x2)
            }
            uintParam.swapType=swapType;
            uintParam.feeRate=feeRate;
        }
        address feeTo;
        uint feeAmount;
        if(uintParam.swapType<2){
            (feeTo,feeAmount)=aggregationExecutor.getFee0(amountInMax);
        }else{
            (feeTo,feeAmount)=aggregationExecutor.getFee1(amountInMax);
        }

        amountInMax=amountInMax-feeAmount;//扣除手续费
        WETH.deposit{value: amountInMax}();
        uint outBalBefore=getTokenBalanceOf(tokenOut,recipient);
        if(uintParam.feeRate<10000){//不需要回调支付
            address pair0;
            assembly {
                pair0 := shr(96, mload(add(add(swapData, 0x20), 0x4b)))//start:75(0x4b),length:20(0x14)
            }
            tokenTransfer(address(WETH),pair0,amountInMax);
        }else{//需要回调支付
            amountMax=amountInMax;
        }
        //amountOutMin(32)+swapType(1)两个参数不需要,从0x21(33)开始,同时要把amountInMax传入aggregationExecutor合约
        if(uintParam.swapType==0||uintParam.swapType==2){
            aggregationExecutor.SingleSwapFromEth(abi.encodePacked(
                amountInMax,
                slice(swapData,0x21)
            ));
        }else{
            aggregationExecutor.SingleSwapFromEthWithFee(abi.encodePacked(
                amountInMax,
                slice(swapData,0x21)
            ));
        }
        amount=getTokenBalanceOf(tokenOut,recipient)-outBalBefore;
        if(amount<amountOutMin){//滑点保护
            revert OutIsLessThanOutMin();
        }
        (bool success,) = feeTo.call{value: feeAmount}(new bytes(0));//转账手续费
        if(!success){
            revert EthTransfer(feeTo,feeAmount);
        }
    }

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
    )external whenNotPaused nonReentrant returns(uint amount){
        uint amountOutMin;
        uint amountInMax;
        address recipient;
        address tokenIn;
        UintParam memory uintParam=UintParam(0,0,0);
        {
            uint8 swapType;
            uint16 feeRate;
            assembly {
                amountOutMin := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
                swapType := mload(add(add(swapData, 0x1), 0x20))//start:32(0x20),length:1
                amountInMax := mload(add(add(swapData, 0x20), 0x21))//start:33(0x21),length:32(0x20)
                recipient := shr(96, mload(add(add(swapData, 0x20), 0x41)))//start:65(0x41),length:20(0x14)
                tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x55)))//start:85(0x55),length:20(0x14)
                feeRate := mload(add(add(swapData, 0x2), 0x69))//start:105(0x69),length:2(0x2)
            }
            uintParam.swapType=swapType;
            uintParam.feeRate=feeRate;
        }
        uint outBalBefore=address(this).balance;
        if(uintParam.feeRate<10000){//不需要回调支付
            address pair0;
            assembly {
                pair0 := shr(96, mload(add(add(swapData, 0x20), 0x6b)))//start:107(0x6b),length:20(0x14)
            }
            tokenTransferFrom(tokenIn,msg.sender,pair0,amountInMax);
        }else{//需要回调支付
            payer=msg.sender;
            srcToken=tokenIn;
            amountMax=amountInMax;
        }
        //amountOutMin(32)+swapType(1)+amountInMax(32)+recipient(20)四个参数不需要,从0x55(85)开始,同时要把amountInMax,recipient(address(this))传入aggregationExecutor合约
        if(uintParam.swapType==0||uintParam.swapType==2){
            aggregationExecutor.SingleSwapForEth(abi.encodePacked(
                amountInMax,
                address(this),
                slice(swapData,0x55)
            ));
        }else{
            aggregationExecutor.SingleSwapForEthWithFee(abi.encodePacked(
                amountInMax,
                address(this),
                slice(swapData,0x55)
            ));
        }
        amount=address(this).balance-outBalBefore;
        address feeTo;
        uint feeAmount;
        if(uintParam.swapType<2){
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee0(amountInMax);
        }else{
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee1(amountInMax);
        }
        amount=amount-feeAmount;//扣除手续费
        if(amount<amountOutMin){//滑点保护
            revert OutIsLessThanOutMin();
        }
        (bool success,) = recipient.call{value: amount}(new bytes(0));
        if(!success){
            revert EthTransfer(recipient,amount);
        }
        (success,) = feeTo.call{value: feeAmount}(new bytes(0));//转账手续费
        if(!success){
            revert EthTransfer(feeTo,feeAmount);
        }
    }
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x14[tokenOut(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **/
    function SimpleBuyFromEth(
        bytes memory swapData
    )external payable whenNotPaused nonReentrant returns(uint amount){
        uint amountOutMin;
        uint amountInMax=msg.value;
        address tokenIn=address(WETH);
        address tokenOut;
        UintParam memory uintParam=UintParam(0,0,0);
        {
            uint8 swapType;
            uint16 feeRate;
            assembly {
                amountOutMin := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
                swapType := mload(add(add(swapData, 0x1), 0x20))//start:32(0x20),length:1
                tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x21)))//start:33(0x21),length:20(0x14)
                feeRate := mload(add(add(swapData, 0x2), 0x35))//start:53(0x35),length:2(0x2)
            }
            uintParam.swapType=swapType;
            uintParam.feeRate=feeRate;
        }
        uint outBalBefore=getTokenBalanceOf(tokenOut,msg.sender);
        address feeTo;
        uint feeAmount;
        if(uintParam.swapType<2){
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee0(amountInMax);
        }else{
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee1(amountInMax);
        }
        amountInMax=amountInMax-feeAmount;//扣除手续费
        WETH.deposit{value: amountInMax}();
        if(uintParam.feeRate<10000){//不需要回调支付
            address pair0;
            assembly {
                pair0 := shr(96, mload(add(add(swapData, 0x20), 0x37)))//start:55(0x37),length:20(0x14)
            }
            tokenTransfer(tokenIn,pair0,amountInMax);
        }else{//需要回调支付
            amountMax=amountInMax;
        }
        //amountOutMin(32)+swapType(1)两个参数不需要,从0x21(33)开始,同时要把amountInMax(msg.value),recipient(msg.sender)传入aggregationExecutor合约
        if(uintParam.swapType==0||uintParam.swapType==2){
            aggregationExecutor.SingleSwapFromEth(abi.encodePacked(
                amountInMax,
                msg.sender,
                slice(swapData,0x21)
            ));
        }else{
            aggregationExecutor.SingleSwapFromEthWithFee(abi.encodePacked(
                amountInMax,
                msg.sender,
                slice(swapData,0x21)
            ));
        }
        amount=getTokenBalanceOf(tokenOut,msg.sender)-outBalBefore;
        if(amount<amountOutMin){//滑点保护
            revert OutIsLessThanOutMin();
        }
        (bool success,) = feeTo.call{value: feeAmount}(new bytes(0));//手续费转账
        if(!success){
            revert EthTransfer(feeTo,feeAmount);
        }
    }
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x20[amountInMax(32)]+
    ** 0x14[tokenIn(20)]+
    ** 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    **/
    function SimpleSellForEth(
        bytes memory swapData
    )external whenNotPaused nonReentrant returns(uint amount){
        uint amountOutMin;
        uint amountInMax;
        address tokenIn;
        UintParam memory uintParam=UintParam(0,0,0);
        {
            uint8 swapType;
            uint16 feeRate;
            assembly {
                amountOutMin := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
                swapType := mload(add(add(swapData, 0x1), 0x20))//start:32(0x20),length:1
                amountInMax := mload(add(add(swapData, 0x20), 0x21))//start:33(0x21),length:32(0x20)
                tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x41)))//start:65(0x41),length:20(0x14)
                feeRate := mload(add(add(swapData, 0x2), 0x55))//start:85(0x55),length:2(0x2)
            }
            uintParam.swapType=swapType;
            uintParam.feeRate=feeRate;
        }
        uint outBalBefore=address(this).balance;
        if(uintParam.feeRate<10000){//不需要回调支付
            address pair0;
            assembly {
                pair0 := shr(96, mload(add(add(swapData, 0x20), 0x57)))//start:87(0x57),length:20(0x14)
            }
            tokenTransferFrom(tokenIn,msg.sender,pair0,amountInMax);
        }else{//需要回调支付
            payer=msg.sender;
            srcToken=tokenIn;
            amountMax=amountInMax;
        }
        //amountOutMin(32)+swapType(1)+amountInMax(32) 三个参数不需要,从0x41(65)开始,同时要把amountInMax,recipient(address(this))再次传入aggregationExecutor合约
        if(uintParam.swapType==0||uintParam.swapType==2){
            aggregationExecutor.SingleSwapForEth(abi.encodePacked(
                amountInMax,
                address(this),
                slice(swapData,0x41)
            ));
        }else{
            aggregationExecutor.SingleSwapForEthWithFee(abi.encodePacked(
                amountInMax,
                address(this),
                slice(swapData,0x41)
            ));
        }
        amount=address(this).balance-outBalBefore;
        address feeTo;
        uint feeAmount;
        if(uintParam.swapType<2){
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee0(amount);
        }else{
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee1(amount);
        }
        amount=amount-feeAmount;//扣除手续费

        if(amount<amountOutMin){//滑点保护
            revert OutIsLessThanOutMin();
        }
        (bool success,) = msg.sender.call{value: amount}(new bytes(0));
        if(!success){
            revert EthTransfer(msg.sender,amount);
        }
        (success,) = feeTo.call{value: feeAmount}(new bytes(0));//转账手续费
        if(!success){
            revert EthTransfer(feeTo,feeAmount);
        }
    }
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
    )external whenNotPaused nonReentrant returns(uint amount){
        uint amountOutMin;
        uint amountInMax;
        address tokenIn;
        address tokenOut;
        UintParam memory uintParam=UintParam(0,0,0);
        {
            uint8 swapType;
            uint16 feeRate;
            assembly {
                amountOutMin := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
                swapType := mload(add(add(swapData, 0x1), 0x20))//start:32(0x20),length:1
                amountInMax := mload(add(add(swapData, 0x20), 0x21))//start:33(0x21),length:32(0x20)
                tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x41)))//start:65(0x41),length:20(0x14)
                tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x55)))//start:85(0x55),length:20(0x14)
                feeRate := mload(add(add(swapData, 0x2), 0x69))//start:105(0x69),length:2(0x2)
            }
            uintParam.swapType=swapType;
            uintParam.feeRate=feeRate;
        }
        address feeTo;
        uint feeAmount;
        if(uintParam.swapType<2){
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee0(amountInMax);
        }else{
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee1(amountInMax);
        }
        amountInMax=amountInMax-feeAmount;//扣除手续费
        uint outBalBefore=getTokenBalanceOf(tokenOut,msg.sender);
        if(uintParam.feeRate<10000){//不需要回调支付
            address pair0;
            assembly {
                pair0 := shr(96, mload(add(add(swapData, 0x20), 0x6b)))//start:107(0x6b),length:20(0x14)
            }
            tokenTransferFrom(tokenIn,msg.sender,pair0,amountInMax);
        }else{//需要回调支付
            payer=msg.sender;
            srcToken=tokenIn;
            amountMax=amountInMax;
        }
        //amountOutMin(32)+swapType(1)+amountInMax(32) 三个参数不需要,从0x41(65)开始,同时要把amountInMax,recipient(msg.sender)再次传入aggregationExecutor合约
        if(uintParam.swapType==0||uintParam.swapType==2){
            aggregationExecutor.SingleSwap(abi.encodePacked(
                amountInMax,
                msg.sender,
                slice(swapData,0x41)
            ));
        }else{
            aggregationExecutor.SingleSwapWithFee(abi.encodePacked(
                amountInMax,
                msg.sender,
                slice(swapData,0x41)
            ));
        }
        amount=getTokenBalanceOf(tokenOut,msg.sender)-outBalBefore;
        if(amount<amountOutMin){//滑点保护
            revert OutIsLessThanOutMin();
        }
        tokenTransferFrom(tokenIn,msg.sender,feeTo,feeAmount);
    }
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
    )external whenNotPaused nonReentrant returns(uint amount){
        uint amountOutMin;
        uint amountInMax;
        address tokenIn;
        address tokenOut;
        UintParam memory uintParam=UintParam(0,0,0);
        {
            uint8 swapType;
            uint16 feeRate;
            assembly {
                amountOutMin := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
                swapType := mload(add(add(swapData, 0x1), 0x20))//start:32(0x20),length:1
                amountInMax := mload(add(add(swapData, 0x20), 0x21))//start:33(0x21),length:32(0x20)
                tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x41)))//start:65(0x41),length:20(0x14)
                tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x55)))//start:85(0x55),length:20(0x14)
                feeRate := mload(add(add(swapData, 0x2), 0x69))//start:105(0x69),length:2(0x2)
            }
            uintParam.swapType=swapType;
            uintParam.feeRate=feeRate;
        }
        uint outBalBefore=getTokenBalanceOf(tokenOut,address(this));
        if(uintParam.feeRate<10000){//不需要回调支付
            address pair0;
            assembly {
                pair0 := shr(96, mload(add(add(swapData, 0x20), 0x6b)))//start:107(0x6b),length:20(0x14)
            }
            tokenTransferFrom(tokenIn,msg.sender,pair0,amountInMax);
        }else{//需要回调支付
            payer=msg.sender;
            srcToken=tokenIn;
            amountMax=amountInMax;
        }
        //amountOutMin(32)+swapType(1)+amountInMax(32) 三个参数不需要,从0x41(65)开始,同时要把amountInMax,recipient(address(this))再次传入aggregationExecutor合约
        if(uintParam.swapType==0){
            aggregationExecutor.SingleSwap(abi.encodePacked(
                amountInMax,
                address(this),
                slice(swapData,0x41)
            ));
        }else{
            aggregationExecutor.SingleSwapWithFee(abi.encodePacked(
                amountInMax,
                address(this),
                slice(swapData,0x41)
            ));
        }
        amount=getTokenBalanceOf(tokenOut,address(this))-outBalBefore;
        address feeTo;
        uint feeAmount;
        if(uintParam.swapType<2){
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee0(amount);
        }else{
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee1(amount);
        }
        amount=amount-feeAmount;//扣除手续费
        if(amount<amountOutMin){//滑点保护
            revert OutIsLessThanOutMin();
        }
        tokenTransfer(tokenOut,msg.sender,amount);
        tokenTransfer(tokenOut,feeTo,feeAmount);//转账手续费
    }
}