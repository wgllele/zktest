// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
import "./base/AggregationExecutorBase.sol";
import "./interface/ICallbackValidation.sol";
//import "hardhat/console.sol";
contract AggregationExecutor is AggregationExecutorBase{
    constructor (
        address _weth,
        ISwapCallBack _swapCallBack,
        ICallbackValidation _callbackValidation,
        address _curveAavePool,
        address _curveCryptoPool,
        address _factory1,
        address _factory2,
        address _factory3,
        bytes32 _hashedInitCode1,
        bytes32 _hashedInitCode2
    )payable AggregationExecutorBase(_weth,_swapCallBack,_callbackValidation,_curveAavePool,_curveCryptoPool,
        _factory1,_factory2,_factory3,_hashedInitCode1,_hashedInitCode2){
        feeSeting0=FeeSeting(msg.sender,500,1000000);
        feeSeting1=FeeSeting(msg.sender,500,1000000);
        feeSeting2=FeeSeting(msg.sender,100,10000);
    }
    FeeSeting private feeSeting0;
    FeeSeting private feeSeting1;
    FeeSeting private feeSeting2;
    function updateFeeSeting(
        uint index,
        address feeTo,
        uint32 fee,
        uint32 base
    )external onlyOwner returns (bool) {
        uint newFee=uint(fee);
        uint newBase=uint(base);
        uint amountIn=1000;
        uint feeAmount;
        assembly {
            let amountInWithFee := mul(amountIn, newFee)
            feeAmount := div(amountInWithFee, newBase)
        }
        require(feeAmount<20,"fee error");
        if(index==0){
            feeSeting0.feeTo=feeTo;
            feeSeting0.fee=fee;
            feeSeting0.base=base;
        }else if(index==1){
            feeSeting1.feeTo=feeTo;
            feeSeting1.fee=fee;
            feeSeting1.base=base;
        }else if(index==2){
            feeSeting2.feeTo=feeTo;
            feeSeting2.fee=fee;
            feeSeting2.base=base;
        }
        return true;
    }

    function getFee0(uint amountIn)external view returns (
        address feeTo,
        uint feeAmount
    ) {
        FeeSeting memory _feeSeting=feeSeting0;
        feeTo=_feeSeting.feeTo;
        uint fee=uint(_feeSeting.fee);
        uint base=uint(_feeSeting.base);
        assembly {
            let amountInWithFee := mul(amountIn, fee)
            feeAmount := div(amountInWithFee, base)
        }
    }
    function getFee1(uint amountIn)external view returns (
        address feeTo,
        uint feeAmount
    ) {
        FeeSeting memory _feeSeting=feeSeting1;
        feeTo=_feeSeting.feeTo;
        uint fee=uint(_feeSeting.fee);
        uint base=uint(_feeSeting.base);
        assembly {
            let amountInWithFee := mul(amountIn, fee)
            feeAmount := div(amountInWithFee, base)
        }
    }
    function getFee2(uint amountIn,uint8 fee)external view returns (
        address feeTo,
        uint feeAmount
    ) {
        FeeSeting memory _feeSeting=feeSeting2;
        feeTo=_feeSeting.feeTo;
        uint base=uint(_feeSeting.base);
        if(fee>_feeSeting.fee){
            uint newFee=uint(_feeSeting.fee);
            assembly {
                let amountInWithFee := mul(amountIn, newFee)
                feeAmount := div(amountInWithFee, base)
            }
        }else{
            uint newFee=uint(fee);
            assembly {
                let amountInWithFee := mul(amountIn, newFee)
                feeAmount := div(amountInWithFee, base)
            }
        }
    }

    /**
    ** 0x20[amountIn(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenOut(20)]+
    ** [0x1[swapLength(1)]+[0x1[swap datas length(1)]+0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x20[amountIn(32)]+0x14[pair0(20)]+swap datas]]
    **/
    function _SingleSwapFromEth(bytes memory swapData,uint swapType)private{
        uint amountIn;
        address recipient;
        address tokenIn=address(WETH);
        address tokenOut;
        uint length;
        uint16 feeRate0;
        address pair0;
        assembly {
            length := mload(swapData)
            amountIn := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
            recipient := shr(96, mload(add(add(swapData, 0x20), 0x20)))//start:32(0x20),length:20(0x14)
            tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x34)))//start:52(0x34),length:20(0x14)
            feeRate0 := mload(add(add(swapData, 0x2), 0x48))//start:72(0x48),length:2(0x2)
            pair0 := shr(96, mload(add(add(swapData, 0x20), 0x4a)))//start:74(0x4a),length:20(0x14)
        }
        if (length == 0x5e) {//one route 94(0x5e)
            if(swapType==0){
                swapLast(amountIn,recipient,feeRate0,pair0,tokenIn,tokenOut);
            }else{
                swapLastWithFee(amountIn,recipient,feeRate0,pair0,tokenIn,tokenOut);
            }
        } else {
            address tokenMid1;
            address pair1;
            uint16 feeRate1;
            assembly {
                tokenMid1 := shr(96, mload(add(add(swapData, 0x20), 0x5e)))//start:94(0x5e),length:20(0x14)
                pair1 := shr(96, mload(add(add(swapData, 0x20), 0x72)))//start:114(0x72),length:20(0x14)
                feeRate1 := mload(add(add(swapData, 0x2), 0x86))//start:134(0x86),length:2(0x2)
            }
            if(swapType==0){
                amountIn = swapMid(amountIn,feeRate0,feeRate1,pair0,pair1,tokenIn,tokenMid1);
            }else{
                amountIn = swapMidWithFee(amountIn,feeRate0,feeRate1,pair0,pair1,tokenIn,tokenMid1);
            }
            if (length == 0x88) {//two route 136(0x88)
                if (feeRate1>10000) {
                    midToken=tokenMid1;
                }
                if(swapType==0){
                    swapLast(amountIn,recipient,feeRate1,pair1,tokenMid1,tokenOut);
                }else{
                    swapLastWithFee(amountIn,recipient,feeRate1,pair1,tokenMid1,tokenOut);
                }
            }else if (length == 0xb2) {//three route 178(0xb2)
                assembly {
                    tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x88)))//start:136(0x88),length:20(0x14)
                    pair0 := shr(96, mload(add(add(swapData, 0x20), 0x9c)))//start:156(0x9c),length:20(0x14)
                    feeRate0 := mload(add(add(swapData, 0x2), 0xb0))//start:176(0xb0),length:2(0x2)
                }
                if (feeRate1>10000) {
                    midToken=tokenMid1;
                }
                if(swapType==0){
                    amountIn = swapMid(amountIn,feeRate1,feeRate0,pair1,pair0,tokenMid1,tokenIn);
                }else{
                    amountIn = swapMidWithFee(amountIn,feeRate1,feeRate0,pair1,pair0,tokenMid1,tokenIn);
                }
                if(feeRate0>10000){
                    midToken=tokenIn;
                }
                if(swapType==0){
                    swapLast(amountIn,recipient,feeRate0,pair0,tokenIn,tokenOut);
                }else{
                    swapLastWithFee(amountIn,recipient,feeRate0,pair0,tokenIn,tokenOut);
                }
            }
        }
    }
    function SingleSwapFromEth(bytes memory swapData)external{
        _SingleSwapFromEth(swapData,0);
    }
    function SingleSwapFromEthWithFee(bytes memory swapData)external{
        _SingleSwapFromEth(swapData,1);
    }
    /**
    ** 0x20[amountIn(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 如果是单个路由 0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x14[pair0(20)]+swap datas
    ** 如果是多个路由 0x1[swapLength(1)]+
    ** 多个路由数据[0x1[swap datas length(1)]+0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x20[amountIn(32)]+0x14[pair0(20)]+swap datas]
    **/
    function _SingleSwapForEth(
        bytes memory swapData,
        uint swapType
    ) private{
        uint amountIn;
        address recipient;
        address tokenIn;
        address tokenOut=address(WETH);
        uint length;
        uint16 feeRate0;
        address pair0;
        assembly {
            length := mload(swapData)
            amountIn := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
            recipient := shr(96, mload(add(add(swapData, 0x20), 0x20)))//start:32(0x20),length:20(0x14)
            tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x34)))//start:52(0x34),length:20(0x14)
            feeRate0 := mload(add(add(swapData, 0x2), 0x48))//start:72(0x48),length:2(0x2)
            pair0 := shr(96, mload(add(add(swapData, 0x20), 0x4a)))//start:74(0x4a),length:20(0x14)
        }
        if (length == 0x5e) {//one route 94(0x5e)
            if(swapType==0){
                swapLast(amountIn,address(this),feeRate0,pair0,tokenIn,tokenOut);
            }else{
                swapLastWithFee(amountIn,address(this),feeRate0,pair0,tokenIn,tokenOut);
            }
        } else {
            address tokenMid1;
            address pair1;
            uint16 feeRate1;
            assembly {
                tokenMid1 := shr(96, mload(add(add(swapData, 0x20), 0x5e)))//start:94(0x5e),length:20(0x14)
                pair1 := shr(96, mload(add(add(swapData, 0x20), 0x72)))//start:114(0x72),length:20(0x14)
                feeRate1 := mload(add(add(swapData, 0x2), 0x86))//start:134(0x86),length:2(0x2)
            }
            if(swapType==0){
                amountIn = swapMid(amountIn,feeRate0,feeRate1,pair0,pair1,tokenIn,tokenMid1);
            }else{
                amountIn = swapMidWithFee(amountIn,feeRate0,feeRate1,pair0,pair1,tokenIn,tokenMid1);
            }
            if (length == 0x88) {//two route 136(0x88)
                if (feeRate1>10000) {
                    midToken=tokenMid1;
                }
                if(swapType==0){
                    swapLast(amountIn,address(this),feeRate1,pair1,tokenMid1,tokenOut);
                }else{
                    swapLastWithFee(amountIn,address(this),feeRate1,pair1,tokenMid1,tokenOut);
                }
            }else if (length == 0xb2) {//three route 178(0xb2)
                assembly {
                    tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x88)))//start:136(0x88),length:20(0x14)
                    pair0 := shr(96, mload(add(add(swapData, 0x20), 0x9c)))//start:156(0x9c),length:20(0x14)
                    feeRate0 := mload(add(add(swapData, 0x2), 0xb0))//start:176(0xb0),length:2(0x2)
                }
                if (feeRate1>10000) {
                    midToken=tokenMid1;
                }
                if(swapType==0){
                    amountIn = swapMid(amountIn,feeRate1,feeRate0,pair1,pair0,tokenMid1,tokenIn);
                }else{
                    amountIn = swapMidWithFee(amountIn,feeRate1,feeRate0,pair1,pair0,tokenMid1,tokenIn);
                }
                if(feeRate0>10000){
                    midToken=tokenIn;
                }
                if(swapType==0){
                    swapLast(amountIn,address(this),feeRate0,pair0,tokenIn,tokenOut);
                }else{
                    swapLastWithFee(amountIn,address(this),feeRate0,pair0,tokenIn,tokenOut);
                }
            }
        }
        amountIn=getTokenBalanceOf(tokenOut,address(this));
        WETH.withdraw(amountIn);
        (bool success,) = recipient.call{value: amountIn}(new bytes(0));
        if(!success){
            revert EthTransfer(recipient,amountIn);
        }
    }
    function SingleSwapForEth(
        bytes memory swapData
    ) external{
        _SingleSwapForEth(swapData,0);
    }
    function SingleSwapForEthWithFee(
        bytes memory swapData
    ) external{
        _SingleSwapForEth(swapData,1);
    }
    /**
    ** 0x20[amountIn(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+swap datas
    **/
    function _SingleSwap(
        bytes memory swapData,
        uint swapType
    ) private{
        uint amountIn;
        address recipient;
        address tokenIn;
        address tokenOut;
        uint length;
        uint16 feeRate0;
        address pair0;
        assembly {
            length := mload(swapData)
            amountIn := mload(add(add(swapData, 0x20), 0x0))//start:0,length:32(0x20)
            recipient := shr(96, mload(add(add(swapData, 0x20), 0x20)))//start:32(0x20),length:20(0x14)
            tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x34)))//start:52(0x34),length:20(0x14)
            tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x48)))//start:72(0x48),length:20(0x14)
            feeRate0 := mload(add(add(swapData, 0x2), 0x5c))//start:92(0x5c),length:2(0x2)
            pair0 := shr(96, mload(add(add(swapData, 0x20), 0x5e)))//start:94(0x5e),length:20(0x14)
        }
        if (length == 0x72) {//one route 114(0x72)
            if(swapType==0){
                swapLast(amountIn,recipient,feeRate0,pair0,tokenIn,tokenOut);
            }else{
                swapLastWithFee(amountIn,recipient,feeRate0,pair0,tokenIn,tokenOut);
            }
        } else {
            address tokenMid1;
            address pair1;
            uint16 feeRate1;
            assembly {
                tokenMid1 := shr(96, mload(add(add(swapData, 0x20), 0x72)))//start:114(0x72),length:20(0x14)
                pair1 := shr(96, mload(add(add(swapData, 0x20), 0x86)))//start:134(0x86),length:20(0x14)
                feeRate1 := mload(add(add(swapData, 0x2), 0x9a))//start:154(0x9a),length:2(0x2)
            }
            if(swapType==0){
                amountIn = swapMid(amountIn,feeRate0,feeRate1,pair0,pair1,tokenIn,tokenMid1);
            }else{
                amountIn = swapMidWithFee(amountIn,feeRate0,feeRate1,pair0,pair1,tokenIn,tokenMid1);
            }
            if (length == 0x9c) {//two route 156(0x9c)
                if (feeRate1>10000) {
                    midToken=tokenMid1;
                }
                if(swapType==0){
                    swapLast(amountIn,recipient,feeRate1,pair1,tokenMid1,tokenOut);
                }else{
                    swapLastWithFee(amountIn,recipient,feeRate1,pair1,tokenMid1,tokenOut);
                }
            }else if (length == 0xc6) {//three route 198(0xc6)
                assembly {
                    tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x9c)))//start:156(0x9c),length:20(0x14)
                    pair0 := shr(96, mload(add(add(swapData, 0x20), 0xb0)))//start:176(0xb0),length:20(0x14)
                    feeRate0 := mload(add(add(swapData, 0x2), 0xc4))//start:196(0xc4),length:2(0x2)
                }
                if (feeRate1>10000) {
                    midToken=tokenMid1;
                }
                if(swapType==0){
                    amountIn = swapMid(amountIn,feeRate1,feeRate0,pair1,pair0,tokenMid1,tokenIn);
                }else{
                    amountIn = swapMidWithFee(amountIn,feeRate1,feeRate0,pair1,pair0,tokenMid1,tokenIn);
                }
                if(feeRate0>10000){
                    midToken=tokenIn;
                }
                if(swapType==0){
                    swapLast(amountIn,recipient,feeRate0,pair0,tokenIn,tokenOut);
                }else{
                    swapLastWithFee(amountIn,recipient,feeRate0,pair0,tokenIn,tokenOut);
                }
            }
        }
    }
    /**
    ** 0x20[amountIn(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+swap datas
    **/
    function SingleSwap(
        bytes memory swapData
    ) external{
        _SingleSwap(swapData,0);
    }
    /**
    ** 0x20[amountIn(32)]+
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+swap datas
    **/
    function SingleSwapWithFee(
        bytes memory swapData
    ) external{
        _SingleSwap(swapData,1);
    }
    /**
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** 0x14[tokenOut(20)]+
    ** 0x1[swapLength(1)+0x1[swap datas length(1)]+0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x20[amountIn(32)]+0x14[pair0(20)]+swap datas]]
    **/
    function _AggregationSwap(
        bytes memory swapData,
        uint swapType
    )private{
        UintParam memory uintParam= UintParam({
            feeRate0:0,
            feeRate1:0,
            dataLength:0
        });
        address recipient;
        address tokenIn;
        address tokenOut;
        uint8 swapLength;
        assembly {
            recipient := shr(96, mload(add(add(swapData, 0x20), 0x0)))//start:0,length:20(0x14)
            tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x14)))//start:20(0x14),length:20(0x14)
            tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x28)))//start:40(0x28),length:20(0x14)
            swapLength := mload(add(add(swapData, 0x1), 0x3c))//start:60(0x3c),length:1(0x1)
        }
        uint pos=0x3d;//61(0x3d)
        for(uint k;k<swapLength;++k){
            uint amountIn;
            address pair0;
            {
                uint8 dataLength;
                uint16 feeRate0;
                assembly {
                    dataLength := mload(add(add(swapData, 0x1), pos))////start:pos,length:1(0x1)
                    feeRate0 := mload(add(add(swapData, 0x2), add(pos,0x1)))//start:1(0x1)+pos,length:2(0x2)
                    amountIn := mload(add(add(swapData, 0x20), add(pos,0x3)))//start:3(0x3)+pos,length:32(0x20)
                    pair0 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x23))))//start:35(0x23)+pos,length:20(0x14)
                }
                uintParam.dataLength=dataLength;
                uintParam.feeRate0=feeRate0;
            }
            if (uintParam.dataLength == 0x37) {//one route 55(0x37)
                if(swapType==0){
                    swapLast(amountIn,recipient,uintParam.feeRate0,pair0,tokenIn,tokenOut);
                }else{
                    swapLastWithFee(amountIn,recipient,uintParam.feeRate0,pair0,tokenIn,tokenOut);
                }
            } else {
                address tokenMid;
                address pair1;
                {
                    uint16 feeRate1;
                    assembly {
                        tokenMid := shr(96, mload(add(add(swapData, 0x20), add(pos,0x37))))//start:55(0x37)+pos,length:20(0x14)
                        pair1 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x4b))))//start:75(0x4b)+pos,length:20(0x14)
                        feeRate1 := mload(add(add(swapData, 0x2), add(pos,0x5f)))//start:95(0x5f)+pos,length:2(0x2)
                    }
                    uintParam.feeRate1=feeRate1;
                }
                if(swapType==0){
                    amountIn = swapMid(amountIn,uintParam.feeRate0,uintParam.feeRate1,pair0,pair1,tokenIn,tokenMid);
                }else{
                    amountIn = swapMidWithFee(amountIn,uintParam.feeRate0,uintParam.feeRate1,pair0,pair1,tokenIn,tokenMid);
                }
                if (uintParam.dataLength == 0x61) {//two route 97(0x61)
                    if (uintParam.feeRate1>10000) {
                        midToken=tokenMid;
                    }
                    if(swapType==0){
                        swapLast(amountIn,recipient,uintParam.feeRate1,pair1,tokenMid,tokenOut);
                    }else{
                        swapLastWithFee(amountIn,recipient,uintParam.feeRate1,pair1,tokenMid,tokenOut);
                    }
                }else if (uintParam.dataLength == 0x8b) {//three route 139(0x8b)
                    {
                        uint16 feeRate0;
                        assembly {
                            tokenIn := shr(96, mload(add(add(swapData, 0x20), add(pos,0x61))))//start:97(0x61)+pos,length:20(0x14)
                            pair0 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x75))))//start:117(0x75)+pos,length:20(0x14)
                            feeRate0 := mload(add(add(swapData, 0x2), add(pos,0x89)))//start:137(0x89)+pos,length:2(0x2)
                        }
                        uintParam.feeRate0=feeRate0;
                    }
                    if (uintParam.feeRate1>10000) {
                        midToken=tokenMid;
                    }
                    if(swapType==0){
                        amountIn = swapMid(amountIn,uintParam.feeRate1,uintParam.feeRate0,pair1,pair0,tokenMid,tokenIn);
                    }else{
                        amountIn = swapMidWithFee(amountIn,uintParam.feeRate1,uintParam.feeRate0,pair1,pair0,tokenMid,tokenIn);
                    }
                    if(uintParam.feeRate0>10000){
                        midToken=tokenIn;
                    }
                    if(swapType==0){
                        swapLast(amountIn,recipient,uintParam.feeRate0,pair0,tokenIn,tokenOut);
                    }else{
                        swapLastWithFee(amountIn,recipient,uintParam.feeRate0,pair0,tokenIn,tokenOut);
                    }
                }
            }
            midToken=address(0);
            pos=pos+uintParam.dataLength;
        }
    }

    function AggregationSwap(bytes memory swapData)external{
        _AggregationSwap(swapData,0);
    }
    function AggregationSwapWithFee(bytes memory swapData)external{
        _AggregationSwap(swapData,1);
    }
    /**
    ** 0x14[recipient(20)]+
    ** 0x14[tokenOut(20)]+
    ** [0x1[swap datas length(1)]+0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x20[amountIn(32)]+0x14[pair0(20)]+swap datas]
    **/
    function _AggregationSwapFromEth(
        bytes memory swapData,
        uint swapType
    )private{
        UintParam memory uintParam= UintParam({
            feeRate0:0,
            feeRate1:0,
            dataLength:0
        });
        address recipient;
        address tokenIn=address(WETH);
        address tokenOut;
        uint8 swapLength;
        assembly {
            recipient := shr(96, mload(add(add(swapData, 0x20), 0x0)))//start:0,length:20(0x14)
            tokenOut := shr(96, mload(add(add(swapData, 0x20), 0x14)))//start:20(0x14),length:20(0x14)
            swapLength := mload(add(add(swapData, 0x1), 0x28))//start:40(0x28),length:1(0x1)
        }
        uint pos=0x29;//41(0x29)
        for(uint k;k<swapLength;++k){
            uint amountIn;
            address pair0;
            {
                uint8 dataLength;
                uint16 feeRate0;
                assembly {
                    dataLength := mload(add(add(swapData, 0x1), pos))////start:pos,length:1(0x1)
                    feeRate0 := mload(add(add(swapData, 0x2), add(pos,0x1)))//start:1(0x1)+pos,length:2(0x2)
                    amountIn := mload(add(add(swapData, 0x20), add(pos,0x3)))//start:3(0x3)+pos,length:32(0x20)
                    pair0 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x23))))//start:35(0x23)+pos,length:20(0x14)
                }
                uintParam.dataLength=dataLength;
                uintParam.feeRate0=feeRate0;
            }

            if (uintParam.dataLength == 0x37) {//one route 55(0x37)
                if(swapType==0){
                    swapLast(amountIn,recipient,uintParam.feeRate0,pair0,tokenIn,tokenOut);
                }else{
                    swapLastWithFee(amountIn,recipient,uintParam.feeRate0,pair0,tokenIn,tokenOut);
                }
            } else {
                address tokenMid;
                address pair1;
                {
                    uint16 feeRate1;
                    assembly {
                        tokenMid := shr(96, mload(add(add(swapData, 0x20), add(pos,0x37))))//start:55(0x37)+pos,length:20(0x14)
                        pair1 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x4b))))//start:75(0x4b)+pos,length:20(0x14)
                        feeRate1 := mload(add(add(swapData, 0x2), add(pos,0x5f)))//start:95(0x5f)+pos,length:2(0x2)
                    }
                    uintParam.feeRate1=feeRate1;
                }
                if(swapType==0){
                    amountIn = swapMid(amountIn,uintParam.feeRate0,uintParam.feeRate1,pair0,pair1,tokenIn,tokenMid);
                }else{
                    amountIn = swapMidWithFee(amountIn,uintParam.feeRate0,uintParam.feeRate1,pair0,pair1,tokenIn,tokenMid);
                }
                if (uintParam.dataLength == 0x61) {//two route 97(0x61)
                    if (uintParam.feeRate1>10000) {
                        midToken=tokenMid;
                    }
                    if(swapType==0){
                        swapLast(amountIn,recipient,uintParam.feeRate1,pair1,tokenMid,tokenOut);
                    }else{
                        swapLastWithFee(amountIn,recipient,uintParam.feeRate1,pair1,tokenMid,tokenOut);
                    }
                }else if (uintParam.dataLength == 0x8b) {//three route 139(0x8b)
                    {
                        uint16 feeRate0;
                        assembly {
                            tokenIn := shr(96, mload(add(add(swapData, 0x20), add(pos,0x61))))//start:97(0x61)+pos,length:20(0x14)
                            pair0 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x75))))//start:117(0x75)+pos,length:20(0x14)
                            feeRate0 := mload(add(add(swapData, 0x2), add(pos,0x89)))//start:137(0x89)+pos,length:2(0x2)
                        }
                        uintParam.feeRate0=feeRate0;
                    }
                    if (uintParam.feeRate1>10000) {
                        midToken=tokenMid;
                    }
                    if(swapType==0){
                        amountIn = swapMid(amountIn,uintParam.feeRate1,uintParam.feeRate0,pair1,pair0,tokenMid,tokenIn);
                    }else{
                        amountIn = swapMidWithFee(amountIn,uintParam.feeRate1,uintParam.feeRate0,pair1,pair0,tokenMid,tokenIn);
                    }
                    if(uintParam.feeRate0>10000){
                        midToken=tokenIn;
                    }
                    if(swapType==0){
                        swapLast(amountIn,recipient,uintParam.feeRate0,pair0,tokenIn,tokenOut);
                    }else{
                        swapLastWithFee(amountIn,recipient,uintParam.feeRate0,pair0,tokenIn,tokenOut);
                    }
                }
            }
            midToken=address(0);
            pos=pos+uintParam.dataLength;
        }
    }

    function AggregationSwapFromEth(bytes memory swapData)external{
        _AggregationSwapFromEth(swapData,0);
    }
    function AggregationSwapFromEthWithFee(bytes memory swapData)external{
        _AggregationSwapFromEth(swapData,1);
    }
    /**
    ** 0x14[recipient(20)]+
    ** 0x14[tokenIn(20)]+
    ** [0x1[swap datas length(1)]+0x2[feeRate0(2)](feeRate0<10000代表需要回调转账的协议类型)+0x20[amountIn(32)]+0x14[pair0(20)]+swap datas]
    **/
    function _AggregationSwapForEth(
        bytes memory swapData,
        uint swapType
    )private{
        UintParam memory uintParam= UintParam({
            feeRate0:0,
            feeRate1:0,
            dataLength:0
        });
        address recipient;
        address tokenIn;
        address tokenOut=address(WETH);
        uint8 swapLength;
        assembly {
            recipient := shr(96, mload(add(add(swapData, 0x20), 0x0)))//start:0,length:20(0x14)
            tokenIn := shr(96, mload(add(add(swapData, 0x20), 0x14)))//start:20(0x14),length:20(0x14)
            swapLength := mload(add(add(swapData, 0x1), 0x28))//start:40(0x28),length:1(0x1)
        }
        uint pos=0x29;//41(0x29)
        for(uint k;k<swapLength;++k){
            uint amountIn;
            address pair0;
            {
                uint8 dataLength;
                uint16 feeRate0;
                assembly {
                    dataLength := mload(add(add(swapData, 0x1), pos))////start:pos,length:1(0x1)
                    feeRate0 := mload(add(add(swapData, 0x2), add(pos,0x1)))//start:1(0x1)+pos,length:2(0x2)
                    amountIn := mload(add(add(swapData, 0x20), add(pos,0x3)))//start:3(0x3)+pos,length:32(0x20)
                    pair0 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x23))))//start:35(0x23)+pos,length:20(0x14)
                }
                uintParam.dataLength=dataLength;
                uintParam.feeRate0=feeRate0;
            }
            if (uintParam.dataLength == 0x37) {//one route 55(0x37)
                if(swapType==0){
                    swapLast(amountIn,address(this),uintParam.feeRate0,pair0,tokenIn,tokenOut);
                }else{
                    swapLastWithFee(amountIn,address(this),uintParam.feeRate0,pair0,tokenIn,tokenOut);
                }
            } else {
                address tokenMid;
                address pair1;
                {
                    uint16 feeRate1;
                    assembly {
                        tokenMid := shr(96, mload(add(add(swapData, 0x20), add(pos,0x37))))//start:55(0x37)+pos,length:20(0x14)
                        pair1 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x4b))))//start:75(0x4b)+pos,length:20(0x14)
                        feeRate1 := mload(add(add(swapData, 0x2), add(pos,0x5f)))//start:95(0x5f)+pos,length:2(0x2)
                    }
                    uintParam.feeRate1=feeRate1;
                }
                if(swapType==0){
                    amountIn = swapMid(amountIn,uintParam.feeRate0,uintParam.feeRate1,pair0,pair1,tokenIn,tokenMid);
                }else{
                    amountIn = swapMidWithFee(amountIn,uintParam.feeRate0,uintParam.feeRate1,pair0,pair1,tokenIn,tokenMid);
                }
                if (uintParam.dataLength == 0x61) {//two route 97(0x61)
                    if (uintParam.feeRate1>10000) {
                        midToken=tokenMid;
                    }
                    if(swapType==0){
                        swapLast(amountIn,address(this),uintParam.feeRate1,pair1,tokenMid,tokenOut);
                    }else{
                        swapLastWithFee(amountIn,address(this),uintParam.feeRate1,pair1,tokenMid,tokenOut);
                    }
                }else if (uintParam.dataLength == 0x8b) {//three route 139(0x8b)
                    {
                        uint16 feeRate0;
                        assembly {
                            tokenIn := shr(96, mload(add(add(swapData, 0x20), add(pos,0x61))))//start:97(0x61)+pos,length:20(0x14)
                            pair0 := shr(96, mload(add(add(swapData, 0x20), add(pos,0x75))))//start:117(0x75)+pos,length:20(0x14)
                            feeRate0 := mload(add(add(swapData, 0x2), add(pos,0x89)))//start:137(0x89)+pos,length:2(0x2)
                        }
                        uintParam.feeRate0=feeRate0;
                    }
                    if (uintParam.feeRate1>10000) {
                        midToken=tokenMid;
                    }
                    if(swapType==0){
                        amountIn = swapMid(amountIn,uintParam.feeRate1,uintParam.feeRate0,pair1,pair0,tokenMid,tokenIn);
                    }else{
                        amountIn = swapMidWithFee(amountIn,uintParam.feeRate1,uintParam.feeRate0,pair1,pair0,tokenMid,tokenIn);
                    }
                    if(uintParam.feeRate0>10000){
                        midToken=tokenIn;
                    }
                    if(swapType==0){
                        swapLast(amountIn,address(this),uintParam.feeRate0,pair0,tokenIn,tokenOut);
                    }else{
                        swapLastWithFee(amountIn,address(this),uintParam.feeRate0,pair0,tokenIn,tokenOut);
                    }
                }
            }
            midToken=address(0);
            pos=pos+uintParam.dataLength;
        }
        uint amount=getTokenBalanceOf(tokenOut,address(this));
        WETH.withdraw(amount);
        (bool success,) = recipient.call{value: amount}(new bytes(0));
        if(!success){
            revert EthTransfer(recipient,amount);
        }
    }
    function AggregationSwapForEth(bytes memory swapData)external{
        _AggregationSwapForEth(swapData,0);
    }
    function AggregationSwapForEthWithFee(bytes memory swapData)external{
        _AggregationSwapForEth(swapData,1);
    }

    function AggregationSwapFromEthDirect(bytes memory swapData)external{

    }
    function AggregationSwapFromEthDirectWithFee(bytes memory swapData)external{

    }
}