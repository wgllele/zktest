// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
import "./base/SwapRouterWithFee.sol";
import "./base/ProxSwap.sol";
import "./interface/ISwapRouter.sol";
import "./interface/IProxSwap.sol";
//import "hardhat/console.sol";
contract SwapRouter is SwapRouterWithFee,ISwapRouter{
    IProxSwap immutable proxSwap=new ProxSwap();
    constructor (address _weth)  payable SwapRouterBase(_weth){}

    event SwapWithFee(
        address token,
        address feeAddr,
        uint amount
    );
    /**
    ** 0x20[amountOutMin(32)]+
    ** 0x1[methodType(1)]+
    ** 0x1[swapType(1)]+
    ** 0x20[amountInMax(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+
    ** 如果是单个路由 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    ** 如果是多个路由 0x1[swapLength(1)]+
    ** 多个路由数据[0x1[swap datas length(1)]+0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x20[amountIn(32)]+0x14[pair0(20)]+swap datas]
    **/
    function Swap(
        bytes memory swapData
    )external payable whenNotPaused nonReentrant returns(uint amount){
        uint amountOutMin;
        SwapParam memory swapParam=SwapParam(0,0,0,address(0),address(0),0,0);
        uint amountInMax;
        address recipient;
        uint outBalBefore;
        uint pos=0x0;
        {
            address tokenIn;
            address tokenOut;
            uint8 methodType;
            uint8 swapType;
            uint8 swapFee;
            assembly {
                amountOutMin := mload(add(add(swapData, 0x20), pos))
                pos:=add(pos,0x20)
                methodType := mload(add(add(swapData, 0x1), pos))
                pos:=add(pos,0x1)
                swapType := mload(add(add(swapData, 0x1), pos))
                pos:=add(pos,0x1)
                swapFee := mload(add(add(swapData, 0x1), pos))
                pos:=add(pos,0x1)
            }
            swapParam.methodType=methodType;

            //0->SingleSwap,1->,SingleSwapWithFee,2->SingleSwap手续费买,3->,SingleSwapWithFee手续费买,4->SingleSwap手续费卖,5->,SingleSwapWithFee手续费卖
            //6->AggregationSwap,7->,AggregationSwapWithFee,8->AggregationSwap手续费买,9->,AggregationSwapWithFee手续费买,10->AggregationSwap手续费卖,11->,AggregationSwapWithFee手续费卖
            //第三方交易 [receipt 12,13,14,15不收手续费] [this 16,17,18,19 收手续费buy] [20,21,22,23 收手续费sell]
            swapParam.swapType=swapType;
            swapParam.swapFee=swapFee;
            //0->swap
            //1->SwapFromEth
            //2->SwapForEth
            //3->SimpleSwap
            //4->SimpleSwapFromEth
            //5->SimpleSwapForEth
            if(swapParam.methodType==1||swapParam.methodType==4){//SwapFromEth or SimpleSwapFromEth
                amountInMax=msg.value;
            }else{
                assembly {
                    amountInMax := mload(add(add(swapData, 0x20), pos))
                    pos:=add(pos,0x20)
                }
            }
            if(swapParam.methodType==3||swapParam.methodType==4||swapParam.methodType==5){
                //SimpleSwap,SimpleSwapFromEth,SimpleSwapForEth
                recipient=msg.sender;
            }else{
                //Swap,SwapFromEth,SwapForEth
                assembly {
                    recipient := shr(96, mload(add(add(swapData, 0x20), pos)))
                    pos:=add(pos,0x14)
                }
            }
            if(swapParam.methodType==1||swapParam.methodType==4){
                //SwapFromEth,SimpleSwapFromEth
                tokenIn=address(WETH);
            }else{
                assembly {
                    tokenIn := shr(96, mload(add(add(swapData, 0x20), pos)))
                    pos:=add(pos,0x14)
                }
            }
            if(swapParam.methodType==2||swapParam.methodType==5){
                //SwapForEth,SimpleSwapForEth
                tokenOut=address(WETH);
                if(
                    swapParam.swapType==4||swapParam.swapType==5||//单个路由收取手续费卖
                    swapParam.swapType==10||swapParam.swapType==11||//多个路由收取手续费卖
                    swapParam.swapType==20||swapParam.swapType==21||swapParam.swapType==22||swapParam.swapType==23//第三方收取手续费卖
                ){
                    outBalBefore=address(this).balance;
                }else{
                    outBalBefore=recipient.balance;
                }
            }else{
                assembly {
                    tokenOut := shr(96, mload(add(add(swapData, 0x20), pos)))
                    pos:=add(pos,0x14)
                }
                if(
                    swapParam.swapType==4||swapParam.swapType==5||//单个路由收取手续费卖
                    swapParam.swapType==10||swapParam.swapType==11||//多个路由收取手续费卖
                    swapParam.swapType==20||swapParam.swapType==21||swapParam.swapType==22||swapParam.swapType==23//第三方收取手续费卖
                ){
                    outBalBefore=getTokenBalanceOf(tokenOut,address(this));
                }else{
                    outBalBefore=getTokenBalanceOf(tokenOut,recipient);
                }
            }
            swapParam.tokenIn=tokenIn;
            swapParam.tokenOut=tokenOut;
        }

        address feeTo;
        uint feeAmount;
        if(
            swapParam.swapType==2||swapParam.swapType==3||//单个路由收取手续费买
            swapParam.swapType==8||swapParam.swapType==9||//多个路由收取手续费买
            swapParam.swapType==16||swapParam.swapType==17||swapParam.swapType==18||swapParam.swapType==19//第三方由收取手续费买
        ){
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee2(amountInMax,swapParam.swapFee);
            amountInMax=amountInMax-feeAmount;//扣掉手续费
        }
        if(swapParam.methodType==1||swapParam.methodType==4){
            WETH.deposit{value: amountInMax}();
        }
        if(swapParam.swapType<6){//单个路由交易 [0,1 不收手续费] [2,3 收手续费buy] [4,5 收手续费sell]
            uint16 feeRate;
            assembly {
                feeRate := mload(add(add(swapData, 0x2), pos))//start:125(0x7d),length:2(0x2)
                pos:=add(pos,0x2)
            }
            if(feeRate<10000){//不需要回调支付
                address pair0;
                assembly {
                    pair0 := shr(96, mload(add(add(swapData, 0x20), pos)))
                    pos:=add(pos,0x2)
                }
                if(swapParam.methodType==1||swapParam.methodType==4){//SwapFromEth or SimpleSwapFromEth
                    tokenTransfer(swapParam.tokenIn,pair0,amountInMax);
                }else{
                    tokenTransferFrom(swapParam.tokenIn,msg.sender,pair0,amountInMax);
                }
            }else{//需要回调支付
                if(swapParam.methodType==1||swapParam.methodType==4){//SwapFromEth or SimpleSwapFromEth
                    amountMax=amountInMax;
                }else{
                    payer=msg.sender;
                    srcToken=swapParam.tokenIn;
                    amountMax=amountInMax;
                }
            }
            if(swapParam.methodType==0){//Swap
                //0->SingleSwap,1->,SingleSwapWithFee,2->SingleSwap手续费买,3->,SingleSwapWithFee手续费买,4->SingleSwap手续费卖,5->,SingleSwapWithFee手续费卖
                if(swapParam.swapType==0){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)四个个参数不需要,从0x23(35)开始
                    aggregationExecutor.SingleSwap(slice(swapData,0x23));
                }else if(swapParam.swapType==1){
                    aggregationExecutor.SingleSwapWithFee(slice(swapData,0x23));
                }else if(swapParam.swapType==2){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32) 五个参数不需要,从0x43(67)开始,同时要把amountInMax,再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwap(abi.encodePacked(amountInMax,slice(swapData,0x43)));
                }else if(swapParam.swapType==3){
                    aggregationExecutor.SingleSwapWithFee(abi.encodePacked(amountInMax,slice(swapData,0x43)));
                }else if(swapParam.swapType==4){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32)+recipient(20)六个参数不需要,从0x57(87)开始,同时要把amountInMax,address(this)再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwap(abi.encodePacked(amountInMax,address(this),slice(swapData,0x57)));
                }else{//swapParam.swapType==5
                    aggregationExecutor.SingleSwapWithFee(abi.encodePacked(amountInMax,address(this),slice(swapData,0x57)));
                }
            }else if(swapParam.methodType==1){//SwapFromEth
                if(swapParam.swapType==0||swapParam.swapType==2){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1) 四个参数不需要,从0x23(35)开始,同时要把amountInMax,传入aggregationExecutor合约
                    aggregationExecutor.SingleSwapFromEth(abi.encodePacked(amountInMax,slice(swapData,0x23)));
                }else if(swapParam.swapType==1||swapParam.swapType==3){
                    aggregationExecutor.SingleSwapFromEthWithFee(abi.encodePacked(amountInMax,slice(swapData,0x23)));
                }else if(swapParam.swapType==4){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+recipient(20) 五个参数不需要,从0x37(55)开始,同时要把amountInMax,address(this)再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwapFromEth(abi.encodePacked(amountInMax,address(this),slice(swapData,0x37)));
                }else{//swapParam.swapType==5
                    aggregationExecutor.SingleSwapFromEthWithFee(abi.encodePacked(amountInMax,address(this),slice(swapData,0x37)));
                }
            }else if(swapParam.methodType==2){//SwapForEth
                //0->SingleSwap,1->,SingleSwapWithFee,2->SingleSwap手续费买,3->,SingleSwapWithFee手续费买,4->SingleSwap手续费卖,5->,SingleSwapWithFee手续费卖
                if(swapParam.swapType==0){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)四个个参数不需要,从0x23(35)开始
                    aggregationExecutor.SingleSwapForEth(slice(swapData,0x23));
                }else if(swapParam.swapType==1){
                    aggregationExecutor.SingleSwapForEthWithFee(slice(swapData,0x23));
                }else if(swapParam.swapType==2){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32) 五个参数不需要,从0x43(67)开始,同时要把amountInMax,再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwapForEth(abi.encodePacked(amountInMax,slice(swapData,0x43)));
                }else if(swapParam.swapType==3){
                    aggregationExecutor.SingleSwapForEthWithFee(abi.encodePacked(amountInMax,slice(swapData,0x43)));
                }else if(swapParam.swapType==4){
                    ////amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32)+recipient(20)六个参数不需要,从0x57(87)开始开始,同时要把amountInMax,address(this)再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwapForEth(abi.encodePacked(amountInMax,address(this),slice(swapData,0x57)));
                }else{//swapParam.swapType==5
                    aggregationExecutor.SingleSwapForEthWithFee(abi.encodePacked(amountInMax,address(this),slice(swapData,0x57)));
                }
            }else if(swapParam.methodType==3){//SimpleSwap
                //0->SingleSwap,1->,SingleSwapWithFee,2->SingleSwap手续费买,3->,SingleSwapWithFee手续费买,4->SingleSwap手续费卖,5->,SingleSwapWithFee手续费卖
                if(swapParam.swapType==0||swapParam.swapType==2){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32) 五个参数不需要,从0x43(67)开始,同时要把amountInMax,msg.sender再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwap(abi.encodePacked(amountInMax,msg.sender,slice(swapData,0x43)));
                }else if(swapParam.swapType==1||swapParam.swapType==3){
                    aggregationExecutor.SingleSwapWithFee(abi.encodePacked(amountInMax,msg.sender,slice(swapData,0x43)));
                }else if(swapParam.swapType==4){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32) 五个参数不需要,从0x43(67)开始,同时要把amountInMax,address(this)再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwap(abi.encodePacked(amountInMax,address(this),slice(swapData,0x43)));
                }else{//swapParam.swapType==5
                    aggregationExecutor.SingleSwapWithFee(abi.encodePacked(amountInMax,address(this),slice(swapData,0x43)));
                }
            }else if(swapParam.methodType==4){//SimpleSwapFromEth
                //0->SingleSwap,1->,SingleSwapWithFee,2->SingleSwap手续费买,3->,SingleSwapWithFee手续费买,4->SingleSwap手续费卖,5->,SingleSwapWithFee手续费卖
                if(swapParam.swapType==0||swapParam.swapType==2){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1) 四个参数不需要,从0x23(35)开始,同时要把amountInMax,msg.sender再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwapFromEth(abi.encodePacked(amountInMax,msg.sender,slice(swapData,0x23)));
                }else if(swapParam.swapType==1||swapParam.swapType==3){
                    aggregationExecutor.SingleSwapFromEthWithFee(abi.encodePacked(amountInMax,msg.sender,slice(swapData,0x23)));
                }else if(swapParam.swapType==4){
                    aggregationExecutor.SingleSwapFromEth(abi.encodePacked(amountInMax,address(this),slice(swapData,0x23)));
                }else{//swapParam.swapType==5
                    aggregationExecutor.SingleSwapFromEthWithFee(abi.encodePacked(amountInMax,address(this),slice(swapData,0x23)));
                }
            }else{//swapParam.methodType==5 SimpleSwapForEth
                //0->SingleSwap,1->,SingleSwapWithFee,2->SingleSwap手续费买,3->,SingleSwapWithFee手续费买,4->SingleSwap手续费卖,5->,SingleSwapWithFee手续费卖
                if(swapParam.swapType==0||swapParam.swapType==2){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32) 五个参数不需要,从0x43(67)开始,同时要把amountInMax,msg.sender再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwapForEth(abi.encodePacked(amountInMax,msg.sender,slice(swapData,0x43)));
                }else if(swapParam.swapType==1||swapParam.swapType==3){
                    aggregationExecutor.SingleSwapForEthWithFee(abi.encodePacked(amountInMax,msg.sender,slice(swapData,0x43)));
                }else if(swapParam.swapType==4){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32) 五个参数不需要,从0x43(67)开始,同时要把amountInMax,address(this)再次传入aggregationExecutor合约
                    aggregationExecutor.SingleSwapForEth(abi.encodePacked(amountInMax,address(this),slice(swapData,0x43)));
                }else{//swapParam.swapType==5
                    aggregationExecutor.SingleSwapForEthWithFee(abi.encodePacked(amountInMax,address(this),slice(swapData,0x43)));
                }
            }
        }else if(swapParam.swapType<12){//多个路由交易 [6,7 不收手续费] [8,9 收手续费buy] [10,11 收手续费sell]
            if(swapParam.methodType==1||swapParam.methodType==4){
                ////SwapFromEth,SimpleSwapFromEth
                amountMax=amountInMax;
            }else{
                payer=msg.sender;
                srcToken=swapParam.tokenIn;
                amountMax=amountInMax;
            }
            uint8 swapLength;
            assembly {
                swapLength := mload(add(add(swapData, 0x1), pos))
                pos:=add(pos,0x1)
            }
            for(uint k;k<swapLength;++k){
                {
                    uint8 dataLength;
                    uint16 feeRate;
                    assembly {
                        dataLength := mload(add(add(swapData, 0x1), pos))//start:pos,length:1(0x1),每条路由参数长度
                        feeRate := mload(add(add(swapData, 0x2), add(pos,0x1)))//start:1(0x1)+pos,length:2(0x2)
                    }
                    swapParam.dataLength=dataLength;
                    swapParam.feeRate=feeRate;
                }
                if(swapParam.feeRate<10000){//不需要回调支付
                    uint amountIn;
                    address pair0;
                    assembly {
                        amountIn := mload(add(add(swapData, 0x20), add(pos,0x3)))//start:3(0x3)+pos,length:32(0x20)
                        pair0 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x23))))//start:35(0x23)+pos,length:20(0x14)
                    }
                    amountMax=amountMax-amountIn;//记录已经消耗的回调
                    if(swapParam.methodType==1||swapParam.methodType==4){
                        tokenTransfer(swapParam.tokenIn,pair0,amountIn);
                    }else{
                        tokenTransferFrom(swapParam.tokenIn,msg.sender,pair0,amountIn);
                    }

                }
                pos=pos+swapParam.dataLength;
            }
            if(swapParam.methodType==0){//Swap
                //6->AggregationSwap,7->,AggregationSwapWithFee,8->AggregationSwap手续费买,9->,AggregationSwapWithFee手续费买,10->AggregationSwap手续费卖,11->,AggregationSwapWithFee手续费卖
                if(swapParam.swapType==6||swapParam.swapType==8){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32) 五个参数不需要,从0x43(67)开始,
                    aggregationExecutor.AggregationSwap(slice(swapData,0x43));
                }else if(swapParam.swapType==7||swapParam.swapType==9){
                    aggregationExecutor.AggregationSwapWithFee(slice(swapData,0x43));
                }else if(swapParam.swapType==10){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32)+recipient(20)六个参数不需要,从0x57(87)开始,同时要把recipient(address(this))传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwap(abi.encodePacked(
                        address(this),
                        slice(swapData,0x57)
                    ));
                }else{//swapParam.swapType==11
                    aggregationExecutor.AggregationSwapWithFee(abi.encodePacked(
                        address(this),
                        slice(swapData,0x57)
                    ));
                }
            }else if(swapParam.methodType==1){//SwapFromEth
                //6->AggregationSwap,7->,AggregationSwapWithFee,8->AggregationSwap手续费买,9->,AggregationSwapWithFee手续费买,10->AggregationSwap手续费卖,11->,AggregationSwapWithFee手续费卖
                if(swapParam.swapType==6||swapParam.swapType==8){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1) 四个参数不需要,从0x23(35)开始,
                    aggregationExecutor.AggregationSwapFromEth(slice(swapData,0x23));
                }else if(swapParam.swapType==7||swapParam.swapType==9){
                    aggregationExecutor.AggregationSwapFromEthWithFee(slice(swapData,0x23));
                }else if(swapParam.swapType==10){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+recipient(20)五个参数不需要,从0x37(55)开始,同时要把recipient(address(this))传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwapFromEth(abi.encodePacked(
                        address(this),
                        slice(swapData,0x37)
                    ));
                }else{//swapParam.swapType==11
                    aggregationExecutor.AggregationSwapFromEthWithFee(abi.encodePacked(
                        address(this),
                        slice(swapData,0x37)
                    ));
                }
            }else if(swapParam.methodType==2){//SwapForEth
                //6->AggregationSwap,7->,AggregationSwapWithFee,8->AggregationSwap手续费买,9->,AggregationSwapWithFee手续费买,10->AggregationSwap手续费卖,11->,AggregationSwapWithFee手续费卖
                if(swapParam.swapType==6||swapParam.swapType==8){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32) 五个参数不需要,从0x43(67)开始,
                    aggregationExecutor.AggregationSwapForEth(slice(swapData,0x43));
                }else if(swapParam.swapType==7||swapParam.swapType==9){
                    aggregationExecutor.AggregationSwapForEthWithFee(slice(swapData,0x43));
                }else if(swapParam.swapType==10){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32)+recipient(20)六个参数不需要,从0x57(87)开始,同时要把recipient(address(this))传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwapForEth(abi.encodePacked(
                        address(this),
                        slice(swapData,0x57)
                    ));
                }else{//swapParam.swapType==11
                    aggregationExecutor.AggregationSwapForEthWithFee(abi.encodePacked(
                        address(this),
                        slice(swapData,0x57)
                    ));
                }
            }else if(swapParam.methodType==3){//SimpleSwap
                //6->AggregationSwap,7->,AggregationSwapWithFee,8->AggregationSwap手续费买,9->,AggregationSwapWithFee手续费买,10->AggregationSwap手续费卖,11->,AggregationSwapWithFee手续费卖
                if(swapParam.swapType==6||swapParam.swapType==8){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32)五个参数不需要,从0x43(67)开始,同时要把recipient(msg.sender)传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwap(abi.encodePacked(
                        msg.sender,
                        slice(swapData,0x43)
                    ));
                }else if(swapParam.swapType==7||swapParam.swapType==9){
                    aggregationExecutor.AggregationSwapWithFee(abi.encodePacked(
                        msg.sender,
                        slice(swapData,0x43)
                    ));
                }else if(swapParam.swapType==10){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32)五个参数不需要,从0x43(67)开始,,从0x57(87)开始,同时要把recipient(address(this))传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwap(abi.encodePacked(
                        address(this),
                        slice(swapData,0x43)
                    ));
                }else{//swapParam.swapType==11
                    aggregationExecutor.AggregationSwapWithFee(abi.encodePacked(
                        address(this),
                        slice(swapData,0x43)
                    ));
                }
            }else if(swapParam.methodType==4){//SimpleSwapFromEth
                //6->AggregationSwap,7->,AggregationSwapWithFee,8->AggregationSwap手续费买,9->,AggregationSwapWithFee手续费买,10->AggregationSwap手续费卖,11->,AggregationSwapWithFee手续费卖
                if(swapParam.swapType==6||swapParam.swapType==8){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)四个参数不需要,从0x23(35)开始,同时要把recipient(msg.sender)传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwapFromEth(abi.encodePacked(
                        msg.sender,
                        slice(swapData,0x23)
                    ));
                }else if(swapParam.swapType==7||swapParam.swapType==9){
                    aggregationExecutor.AggregationSwapFromEthWithFee(abi.encodePacked(
                        msg.sender,
                        slice(swapData,0x23)
                    ));
                }else if(swapParam.swapType==10){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)四个参数不需要,从0x23(35)开始,同时要把recipient(address(this))传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwapFromEth(abi.encodePacked(
                        address(this),
                        slice(swapData,0x23)
                    ));
                }else{//swapParam.swapType==11
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)四个参数不需要,从0x23(35)开始,同时要把recipient(address(this))传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwapFromEthWithFee(abi.encodePacked(
                        address(this),
                        slice(swapData,0x23)
                    ));
                }
            }else{//swapParam.methodType==5 SimpleSwapForEth
                //6->AggregationSwap,7->,AggregationSwapWithFee,8->AggregationSwap手续费买,9->,AggregationSwapWithFee手续费买,10->AggregationSwap手续费卖,11->,AggregationSwapWithFee手续费卖
                if(swapParam.swapType==6||swapParam.swapType==8){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32)五个参数不需要,从0x43(67)开始,同时要把recipient(msg.sender)传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwapForEth(abi.encodePacked(
                        msg.sender,
                        slice(swapData,0x43)
                    ));
                }else if(swapParam.swapType==7||swapParam.swapType==9){
                    aggregationExecutor.AggregationSwapForEthWithFee(abi.encodePacked(
                        msg.sender,
                        slice(swapData,0x43)
                    ));
                }else if(swapParam.swapType==10){
                    //amountOutMin(32)+methodType(1)+swapType(1)+swapFee(1)+amountInMax(32)五个参数不需要,从0x43(67)开始,,从0x57(87)开始,同时要把recipient(address(this))传入aggregationExecutor合约
                    aggregationExecutor.AggregationSwapForEth(abi.encodePacked(
                        address(this),
                        slice(swapData,0x43)
                    ));
                }else{//swapParam.swapType==11
                    aggregationExecutor.AggregationSwapForEthWithFee(abi.encodePacked(
                        address(this),
                        slice(swapData,0x43)
                    ));
                }
            }
        }else{//第三方交易 [receipt 12,13,14,15不收手续费] [this 16,17,18,19 收手续费buy] [20,21,22,23 收手续费sell]
            //param.swapTyp>11 第三方聚合
            address contractAddr;//swapParam.swapType==12,14
            assembly {
                contractAddr := shr(96, mload(add(add(swapData, 0x20), pos)))
                pos:=add(pos,0x14)
            }
            if(swapParam.methodType!=1&&swapParam.methodType!=4){//not Swap From Eth
                tokenTransferFrom(swapParam.tokenIn,msg.sender,address(proxSwap),amountInMax);
            }else{
                tokenTransfer(swapParam.tokenIn,address(proxSwap),amountInMax);
            }
            if(swapParam.swapType==12||swapParam.swapType==16||swapParam.swapType==20){
                proxSwap.callThirdPartySwap(
                    abi.encodePacked(swapParam.tokenIn,contractAddr,amountInMax),
                    slice(swapData, pos)
                ); //start:pos
            }else if(swapParam.swapType==13||swapParam.swapType==17){
                proxSwap.callThirdPartySwapOut(
                    abi.encodePacked(recipient,swapParam.tokenOut,swapParam.tokenIn,contractAddr,amountInMax),
                    slice(swapData, pos)
                ); //pos
            }else if(swapParam.swapType==21){
                proxSwap.callThirdPartySwapOut(
                    abi.encodePacked(address(this),swapParam.tokenOut,swapParam.tokenIn,contractAddr,amountInMax),
                    slice(swapData, pos)
                ); //start:pos
            }else if (
                swapParam.swapType==14||
                swapParam.swapType==15||
                swapParam.swapType==18||
                swapParam.swapType==19||
                swapParam.swapType==22||
                swapParam.swapType==23
            ) {
                address approveAddr;
                assembly {
                    approveAddr := shr(96,mload(add(add(swapData, 0x20), pos)))
                    pos:=add(pos,0x14)
                }
                if(swapParam.swapType==14||swapParam.swapType==18||swapParam.swapType==22){
                    proxSwap.callThirdPartySwap(
                        abi.encodePacked(swapParam.tokenIn,amountInMax,contractAddr,approveAddr),
                        slice(swapData, pos)
                    ); //start:pos
                }else if(swapParam.swapType==15||swapParam.swapType==19){
                    proxSwap.callThirdPartySwapOut(
                        abi.encodePacked(recipient,swapParam.tokenOut,swapParam.tokenIn,contractAddr,amountInMax,approveAddr),
                        slice(swapData, pos)
                    ); //pos
                }else {//swapParam.swapType==23
                    proxSwap.callThirdPartySwapOut(
                        abi.encodePacked(address(this),swapParam.tokenOut,swapParam.tokenIn,amountInMax,contractAddr,approveAddr),
                        slice(swapData, pos)
                    ); //start:pos
                }
            }
        }
        if(swapParam.methodType==2||swapParam.methodType==5){
            //SwapForEth,SimpleSwapForEth
            if(
                swapParam.swapType==4||swapParam.swapType==5||//单个路由收取手续费卖
                swapParam.swapType==10||swapParam.swapType==11||//多个路由收取手续费卖
                swapParam.swapType==20||swapParam.swapType==21||swapParam.swapType==22||swapParam.swapType==23//第三方收取手续费卖
            ){
                amount=address(this).balance-outBalBefore;
                (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee2(amount,swapParam.swapFee);
                amount=amount-feeAmount;//扣掉手续费
                if (amount < amountOutMin) {
                    //滑点保护
                    revert OutIsLessThanOutMin();
                }
                _ethTransfer(recipient,amount);
                _ethTransfer(feeTo,feeAmount);
                emit SwapWithFee(
                    address(0),
                    feeTo,
                    feeAmount
                );
            }else{
                amount=recipient.balance-outBalBefore;
                if (amount < amountOutMin) {
                    //滑点保护
                    revert OutIsLessThanOutMin();
                }
            }
        }else{
            if(
                swapParam.swapType==4||swapParam.swapType==5||//单个路由收取手续费卖
                swapParam.swapType==10||swapParam.swapType==11||//多个路由收取手续费卖
                swapParam.swapType==20||swapParam.swapType==21||swapParam.swapType==22||swapParam.swapType==23//第三方收取手续费卖
            ){
                amount=getTokenBalanceOf(swapParam.tokenOut,address(this))-outBalBefore;
                (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee2(amount,swapParam.swapFee);
                amount=amount-feeAmount;//扣掉手续费
                tokenTransfer(swapParam.tokenOut,recipient,amount);
                tokenTransfer(swapParam.tokenOut,feeTo,feeAmount);
                emit SwapWithFee(
                    swapParam.tokenOut,
                    feeTo,
                    feeAmount
                );
            }else{
                amount=getTokenBalanceOf(swapParam.tokenOut,recipient)-outBalBefore;
            }

            if (amount < amountOutMin) {
                //滑点保护
                revert OutIsLessThanOutMin();
            }
        }
        if(
            swapParam.swapType==2||swapParam.swapType==3||//单个路由收取手续费买
            swapParam.swapType==8||swapParam.swapType==9||//多个路由收取手续费买
            swapParam.swapType==16||swapParam.swapType==17||swapParam.swapType==18||swapParam.swapType==19//第三方由收取手续费买
        ){
            if(swapParam.methodType==1||swapParam.methodType==4){//SwapFromEth or SimpleSwapFromEth
                _ethTransfer(feeTo,feeAmount);
                emit SwapWithFee(
                    address(0),
                    feeTo,
                    feeAmount
                );
            }else{
                tokenTransferFrom(payer,swapParam.tokenIn,feeTo,feeAmount);
                emit SwapWithFee(
                    swapParam.tokenIn,
                    feeTo,
                    feeAmount
                );
            }
        }
    }
    /**
    ** 0x14[recipient(20)]+
    ** 0x20[amountOutMin(32)]+
    ** 0x1[swapType(1)]+
    ** 0x14[tokenOut(20)]+swap datas
    **/
    function AggregationSwapFromEthDirect(
        bytes memory swapData
    )external payable whenNotPaused nonReentrant returns(uint amount){
        address recipient;
        uint amountOutMin;
        address tokenOut;
        uint8 swapType;
        uint8 swapFee;
        assembly {
            recipient := shr(96, mload(add(add(swapData, 0x20), 0x0)))//start:0,length:20(0x14)
            amountOutMin := mload(add(add(swapData, 0x20), 0x14))//start:0x14(20),length:32(0x20)
            swapType := mload(add(add(swapData, 0x1), 0x34))//start:0x34(52),length:1(0x1)
            swapFee := mload(add(add(swapData, 0x1), 0x35))//start:0x35(53),length:1(0x1)
            tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x36)))//start:0x36(54),length:20(0x14)
        }
        amountMax=msg.value;
        address feeTo;
        uint feeAmount;
        if(swapType==1||swapType==3){//需要扣除手续费
            (feeTo,feeAmount)=IAggregationExecutor(aggregationExecutor).getFee2(amountMax,swapFee);
            amountMax=amountMax-feeAmount;//扣掉手续费
        }
        payer=address(1);
        uint outBalBefore=getTokenBalanceOf(tokenOut,recipient);
        //amountOutMin(32)+swapType(1)+swapFee(1)三个参数不需要,从0x22(34)开始
        if(swapType==0||swapType==1){
            aggregationExecutor.AggregationSwapFromEthDirect(slice(swapData,0x22));
        }else{
            aggregationExecutor.AggregationSwapFromEthDirectWithFee(slice(swapData,0x22));
        }
        amount=getTokenBalanceOf(tokenOut,recipient)-outBalBefore;
        if(amount<amountOutMin){//滑点保护
            revert OutIsLessThanOutMin();
        }
        if(swapType==1||swapType==3){
            _ethTransfer(feeTo,feeAmount);
            emit SwapWithFee(
                address(0),
                feeTo,
                feeAmount
            );
        }
    }
}
