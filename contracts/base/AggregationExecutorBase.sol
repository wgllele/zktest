// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interface/IUniswapV3PoolActions.sol";
import "../interface/IWETH.sol";
import "../interface/ISwapCallBack.sol";
import "../interface/IAggregationExecutor.sol";
import "../interface/IAerodromePairV2.sol";
import "../interface/IBalancer.sol";
import "../interface/ICurveAavePool.sol";
import "../interface/ICurveCryptoPool.sol";
import "../interface/IDODO.sol";
import "../interface/IFRouter.sol";

import "../interface/ICallbackValidation.sol";

abstract contract AggregationExecutorBase is Ownable,Pausable,IAggregationExecutor{
    ISwapCallBack immutable swapCallBack;
    IWETH immutable WETH;
    uint256 immutable chainId;
    struct UintParam{
        uint16 feeRate0;
        uint16 feeRate1;
        uint8 dataLength;
    }
    struct FeeSeting{
        address feeTo;
        uint32 fee;
        uint32 base;
    }
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }
    receive() external payable {}
    fallback() external payable {}
    ICallbackValidation callbackValidation;
    address transient midToken;
    address transient caller;
    address immutable curveAavePool;
    address immutable curveCryptoPool;
    address immutable factory1;//UniswapV3
    address immutable factory2;//PancakeV3
    address immutable factory3;//AlgebraSwapV3
    bytes32 immutable hashedInitCode1;//UniswapV3
    bytes32 immutable hashedInitCode2;//PancakeV3
    address internal constant balancerAddr=0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    uint160 internal constant MIN_SQRT_RATIO = 4295128740;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;
    IFRouter internal constant fRouter=IFRouter(0x8292B43aB73EfAC11FAF357419C38ACF448202C5);
    mapping(address => bytes32) internal balancerPoolIds;
    mapping(address => int128) internal curveTokenInt128Index;
    mapping(address => uint256) internal curveTokenUint256Index;
    uint256 internal constant UINT256_MAX = ~ uint256(0);
    error EthTransfer(address recipient, uint256 amount);
    constructor (
        address _WETH,
        ISwapCallBack _swapCallBack,
        ICallbackValidation _callbackValidation,
        address _curveAavePool,
        address _curveCryptoPool,
        address _factory1,
        address _factory2,
        address _factory3,
        bytes32 _hashedInitCode1,
        bytes32 _hashedInitCode2
    )Ownable(msg.sender)payable{
        WETH=IWETH(_WETH);
        swapCallBack=_swapCallBack;
        callbackValidation=_callbackValidation;
        curveAavePool=_curveAavePool;
        curveCryptoPool=_curveCryptoPool;
        factory1=_factory1;
        factory2=_factory2;
        factory3=_factory3;
        hashedInitCode1=_hashedInitCode1;
        hashedInitCode2=_hashedInitCode2;
        uint _chainId;
        assembly {
        _chainId :=chainid()
        }
        chainId=_chainId;
    }

    function setCurveTokenIndexs(
        address[] memory curveTokens,
        int128[] memory int128s,
        uint256[] memory uint256s
    ) onlyOwner external {
        uint length=curveTokens.length;
        for (uint i;i<length;++i) {
            curveTokenInt128Index[curveTokens[i]]=int128s[i];
            curveTokenUint256Index[curveTokens[i]]=uint256s[i];
        }
    }
    function setBalancerPoolIds(
        address[] memory balancerPools,
        bytes32[] memory poolIds
    ) onlyOwner external{
        uint length=balancerPools.length;
        for (uint i;i<length;++i) {
            balancerPoolIds[balancerPools[i]]=poolIds[i];
        }
    }
    // gas optimization on transfer token
    function tokenTransfer(address token, address recipient, uint256 amount) internal {
        bool failed = false;
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(emptyPointer, 0x04), recipient)
            mstore(add(emptyPointer, 0x24), amount)
            failed := iszero(call(gas(), token, 0, emptyPointer, 0x44, 0, 0))
            if failed {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        //if (failed) revert TokenTransfer(token,recipient,amount);
    }
    function tokenApprove(address token, address spender, uint256 amount) internal {
        bool failed = false;
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(emptyPointer, 0x04), spender)
            mstore(add(emptyPointer, 0x24), amount)
            failed := iszero(call(gas(), token, 0, emptyPointer, 0x44, 0, 0))
            if failed {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        //if (failed) revert TokenTransfer(token,recipient,amount);
    }
    // gas optimization on swap operation using a liquidity pool
    function uniSwapV2Swap(address pair, uint amount0Out, uint amount1Out, address receiver) internal {
        bool failed = false;
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x022c0d9f00000000000000000000000000000000000000000000000000000000)
            mstore(add(emptyPointer, 0x04), amount0Out)
            mstore(add(emptyPointer, 0x24), amount1Out)
            mstore(add(emptyPointer, 0x44), receiver)
            mstore(add(emptyPointer, 0x64), 0x80)
            mstore(add(emptyPointer, 0x84), 0)
            failed := iszero(call(gas(), pair, 0, emptyPointer, 0xa4, 0, 0))
            if failed {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        //if (failed) revert CallUiniswapV2Swap(pair,amount0Out,amount1Out,receiver);
    }
    // gas optimization on get balanceOf fron BEP20 or ERC20 token
    function getTokenBalanceOf(address token, address holder) internal  view returns (uint112 tokenBalance) {
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(emptyPointer, 0x04), holder)
            let success := staticcall(gas(), token, emptyPointer, 0x24, emptyPointer, 0x40)
            if success {
                tokenBalance := mload(emptyPointer)
            }
        }
    }
    // gas optimization on get reserves from liquidity pool
    function getTokenReserves(address pairAddress) internal  view returns (uint112 reserve0, uint112 reserve1) {
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
            let success := staticcall(gas(), pairAddress, emptyPointer, 0x4, emptyPointer, 0x40)
            if success{
                reserve0 := mload(emptyPointer)
                reserve1 := mload(add(emptyPointer, 0x20))
            }
        }
    }
    ///The approach is consistent with uniswap, https://github.com/Uniswap/v3-periphery/blob/697c2474757ea89fec12a4e6db16a574fe259610/contracts/base/PeripheryPayments.sol#L30
    function sweepToken(
        address token,
        uint256 amountMinimum
    ) external payable {
        uint256 balanceToken=getTokenBalanceOf(token,address(this));
        if (balanceToken > amountMinimum) {
            tokenTransfer(token,owner(),balanceToken);
        }
    }
    ///The approach is consistent with uniswap, https://github.com/Uniswap/v3-periphery/blob/697c2474757ea89fec12a4e6db16a574fe259610/contracts/base/PeripheryPayments.sol#L44
    function refundETH() external payable  {
        address recipient=owner();
        uint256 amount=address(this).balance;
        bool callStatus;
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), recipient, amount, 0, 0, 0, 0)
        }
        if (!callStatus) {
            revert EthTransfer(recipient, amount);
        }
    }
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut,
        uint feeRate
    )internal pure returns (uint amountOut) {
        assembly {
            let amountInWithFee := mul(amountIn, feeRate)
            let numerator := mul(amountInWithFee, reserveOut)
            let denominator := add(mul(reserveIn, 10000), amountInWithFee)
            amountOut := div(numerator, denominator)
        }
    }
    function swapMid(
        uint amountIn,
        uint16 feeRate0,
        uint16 feeRate1,
        address pair0,
        address pair1,
        address path0,
        address path1
    )internal returns (uint256 amount){
        if (feeRate0==1) {//AerodromePairV2
            amount=IAerodromePairV2(pair0).getAmountOut(amountIn, path0);
            if(path0<path1){
                if(feeRate1<10000){
                    uniSwapV2Swap(pair0,0,amount,pair1);
                }else{
                    uniSwapV2Swap(pair0,0,amount,address(this));
                }
            }else{
                if(feeRate1<10000){
                    uniSwapV2Swap(pair0,amount,0,pair1);
                }else{
                    uniSwapV2Swap(pair0,amount,0,address(this));
                }
            }
        }else if(feeRate0==2){//IDODO(pair).sellBase
            if(feeRate1<10000){
                amount=IDODO(pair0).sellBase(pair1);
            }else{
                amount=IDODO(pair0).sellBase(address(this));
            }
        }else if(feeRate0==3){//IDODO(pair).sellQuote
            if(feeRate1<10000){
                amount=IDODO(pair0).sellQuote(pair1);
            }else{
                amount=IDODO(pair0).sellQuote(address(this));
            }
        }else if(feeRate0==4){//IDODO(pair).sellBaseToken
            amount=IDODO(pair0).sellBaseToken(amountIn,0,new bytes(0));
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, amount);
            }
        }else if(feeRate0==5){//IDODO(pair).querySellBaseToken
            amount=IDODO(pair0).buyBaseToken(IDODO(pair0).querySellBaseToken(amountIn),amountIn,new bytes(0));
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, amount);
            }
        }else if (feeRate0==10002) {//balancer
            IBalancer.SingleSwap memory singleSwap;
            IBalancer.FundManagement memory funds;
            singleSwap.poolId=balancerPoolIds[pair0];
            singleSwap.kind=IBalancer.SwapKind.GIVEN_IN;
            singleSwap.assetIn=IAsset(path0);
            singleSwap.assetOut=IAsset(path1);
            singleSwap.amount=amountIn;
            funds.sender=address(this);
            funds.fromInternalBalance=false;
            funds.toInternalBalance=false;
            singleSwap.amount=amountIn;
            if(feeRate1<10000){
                funds.recipient=payable(pair1);
            }else{
                funds.recipient=payable(address(this));
            }
            tokenApprove(path0, balancerAddr,amountIn+1);
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            amount=IBalancer(balancerAddr).swap(singleSwap,funds,10,UINT256_MAX);
        }else if (feeRate0==10003) {//CurveAavePool
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, curveAavePool,amountIn+1);
            amount=ICurveAavePool(curveAavePool).exchange_underlying(
                curveTokenInt128Index[path0], curveTokenInt128Index[path1], amountIn, 0
            );
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, amount);
            }
        }else if (feeRate0==10004) {//CurveCryptoPool
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, curveCryptoPool,amountIn+1);
            if(feeRate1<10000){
                amount=getTokenBalanceOf(path1,pair1);
                ICurveCryptoPool(curveCryptoPool).exchange_underlying(
                    curveTokenUint256Index[path0], curveTokenUint256Index[path1], amountIn, 0,pair1
                );
                amount=getTokenBalanceOf(path1,pair1)-amount;
            }else{
                ICurveCryptoPool(curveCryptoPool).exchange_underlying(
                    curveTokenUint256Index[path0], curveTokenUint256Index[path1], amountIn, 0,address(this)
                );
                amount=getTokenBalanceOf(path1,address(this));
            }
        }else if (feeRate0==10005) {//fRouter sell
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, address(fRouter),amountIn+1);
            (, amount) = fRouter.sell(
                amountIn,
                path0,
                address(this)
            );
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, amount);
            }
        }else if (feeRate0==10006) {//fRouter buy
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, address(fRouter),amountIn+1);
            (, amount) = fRouter.buy(
                amountIn,
                path0,
                address(this)
            );
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, amount);
            }
        }else if(feeRate0<10000){//uniswapV2
            (uint112 reserve0,uint112 reserve1) = getTokenReserves(pair0);
            if(path0<path1){
                amount=getAmountOut(amountIn, reserve0, reserve1,feeRate0);
                if(feeRate1<10000){
                    uniSwapV2Swap(pair0,0, amount, pair1);
                }else{
                    uniSwapV2Swap(pair0,0, amount, address(this));
                }
            }else{
                amount=getAmountOut(amountIn, reserve1, reserve0,feeRate0);
                if(feeRate1<10000){
                    uniSwapV2Swap(pair0,amount,0, pair1);
                }else{
                    uniSwapV2Swap(pair0,amount,0, address(this));
                }
            }
        }else{//
            if(midToken==address(0)){
                midToken=address(1);//控制回调route合约的权限
            }
            if(path0<path1){
                initCaller(feeRate0,pair0,path0,path1);
                if(feeRate1<10000){
                    (,int256 amount1)=IUniswapV3PoolActions(pair0).swap(
                        pair1,
                        true,
                        int256(amountIn),
                        MIN_SQRT_RATIO ,
                        new bytes(0)
                    );
                    amount=uint256(-amount1);
                }else{
                    (,int256 amount1)=IUniswapV3PoolActions(pair0).swap(
                        address(this),
                        true,
                        int256(amountIn),
                        MIN_SQRT_RATIO ,
                        new bytes(0)
                    );
                    amount=uint256(-amount1);
                }
            }else{
                initCaller(feeRate0,pair0,path1,path0);
                if(feeRate1<10000){
                    (int256 amount0,)=IUniswapV3PoolActions(pair0).swap(
                        pair1,
                        false,
                        int256(amountIn),
                        MAX_SQRT_RATIO,
                        new bytes(0)
                    );
                    amount=uint256(-amount0);
                }else{
                    (int256 amount0,)=IUniswapV3PoolActions(pair0).swap(
                        address(this),
                        false,
                        int256(amountIn),
                        MAX_SQRT_RATIO,
                        new bytes(0)
                    );
                    amount=uint256(-amount0);
                }
            }
            midToken=address(0);//重置回调route合约的权限
            caller=address(0);//重置回调route合约的权限
        }
    }
    function swapMidWithFee(
        uint amountIn,
        uint16 feeRate0,
        uint16 feeRate1,
        address pair0,
        address pair1,
        address path0,
        address path1
    )internal returns (uint256 amount){
        if (feeRate0==1) {//AerodromePairV2
            (uint112 reserve0,uint112 reserve1) = getTokenReserves(pair0);
            if(path0<path1){
                amountIn=getTokenBalanceOf(path0,pair0)-reserve0;
                amount=IAerodromePairV2(pair0).getAmountOut(amountIn, path0);
                if(feeRate1<10000){
                    uniSwapV2Swap(pair0,0,amount,pair1);
                }else{
                    uniSwapV2Swap(pair0,0,amount,address(this));
                }
            }else{
                amountIn=getTokenBalanceOf(path0,pair0)-reserve1;
                amount=IAerodromePairV2(pair0).getAmountOut(amountIn, path0);
                if(feeRate1<10000){
                    uniSwapV2Swap(pair0,amount,0, pair1);
                }else{
                    uniSwapV2Swap(pair0,amount,0, address(this));
                }
            }
        }else if(feeRate0==2){//IDODO(pair).sellBase
            if(feeRate1<10000){
                amount=IDODO(pair0).sellBase(pair1);
            }else{
                amount=IDODO(pair0).sellBase(address(this));
            }
        }else if(feeRate0==3){//IDODO(pair).sellQuote
            if(feeRate1<10000){
                amount=IDODO(pair0).sellQuote(pair1);
            }else{
                amount=IDODO(pair0).sellQuote(address(this));
            }
        }else if(feeRate0==4){//IDODO(pair).sellBaseToken
            amount=IDODO(pair0).sellBaseToken(amountIn,0,new bytes(0));
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, getTokenBalanceOf(path1,address(this)));
            }
        }else if(feeRate0==5){//IDODO(pair).querySellBaseToken
            amount=IDODO(pair0).buyBaseToken(IDODO(pair0).querySellBaseToken(amountIn),amountIn,new bytes(0));
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, getTokenBalanceOf(path1,address(this)));
            }
        }else if (feeRate0==10002) {//balancer
            IBalancer.SingleSwap memory singleSwap;
            IBalancer.FundManagement memory funds;
            singleSwap.poolId=balancerPoolIds[pair0];
            singleSwap.kind=IBalancer.SwapKind.GIVEN_IN;
            singleSwap.assetIn=IAsset(path0);
            singleSwap.assetOut=IAsset(path1);
            funds.sender=address(this);
            funds.fromInternalBalance=false;
            funds.toInternalBalance=false;
            if(feeRate1<10000){
                funds.recipient=payable(pair1);
            }else{
                funds.recipient=payable(address(this));
            }
            tokenApprove(path0, balancerAddr,amountIn+1);
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            singleSwap.amount=getTokenBalanceOf(path0,address(this));
            amount=IBalancer(balancerAddr).swap(singleSwap,funds,10,UINT256_MAX);
        }else if (feeRate0==10003) {//CurveAavePool
            tokenApprove(path0, curveAavePool,amountIn+1);
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            amount=ICurveAavePool(curveAavePool).exchange_underlying(
                curveTokenInt128Index[path0], curveTokenInt128Index[path1], amountIn, 0
            );
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, getTokenBalanceOf(path1,address(this)));
            }
        }else if (feeRate0==10004) {//CurveCryptoPool
            tokenApprove(path0, curveCryptoPool,amountIn+1);
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            if(feeRate1<10000){
                amount=getTokenBalanceOf(path1,pair1);
                ICurveCryptoPool(curveCryptoPool).exchange_underlying(
                    curveTokenUint256Index[path0], curveTokenUint256Index[path1], amountIn, 0,pair1
                );
                amount=getTokenBalanceOf(path1,pair1)-amount;
            }else{
                ICurveCryptoPool(curveCryptoPool).exchange_underlying(
                    curveTokenUint256Index[path0], curveTokenUint256Index[path1], amountIn, 0,address(this)
                );
                amount=getTokenBalanceOf(path1,address(this));
            }
        }else if (feeRate0==10005) {//fRouter sell
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, address(fRouter),amountIn+1);
            fRouter.sell(
                amountIn,
                path0,
                address(this)
            );
            amount=getTokenBalanceOf(path1,address(this));
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, amount);
            }
        }else if (feeRate0==10006) {//fRouter buy
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, address(fRouter),amountIn+1);
            fRouter.buy(
                amountIn,
                path0,
                address(this)
            );
            amount=getTokenBalanceOf(path1,address(this));
            if(feeRate1<10000){
                tokenTransfer(path1, pair1, amount);
            }
        }else if(feeRate0<10000){//uniSwapV2
            (uint112 reserve0,uint112 reserve1) = getTokenReserves(pair0);
            if(path0<path1){
                amountIn=getTokenBalanceOf(path0,pair0)-reserve0;
                amount=getAmountOut(amountIn, reserve0, reserve1,feeRate0);
                if(feeRate1<10000){
                    uniSwapV2Swap(pair0,0, amount, pair1);
                }else{
                    uniSwapV2Swap(pair0,0, amount, address(this));
                }
            }else{
                amountIn=getTokenBalanceOf(path0,pair0)-reserve1;
                amount=getAmountOut(amountIn, reserve1, reserve0,feeRate0);
                if(feeRate1<10000){
                    uniSwapV2Swap(pair0,amount,0, pair1);
                }else{
                    uniSwapV2Swap(pair0,amount,0, address(this));
                }
            }
        }else{//uniSwapV3
            if(midToken==address(0)){
                midToken=address(1);//回调route合约的权限
            }else{
                uint path0AmountIn=getTokenBalanceOf(path0,address(this));
                if(amountIn>path0AmountIn){
                    amountIn=path0AmountIn;
                }
            }
            if(path0<path1){
                initCaller(feeRate0,pair0,path0,path1);
                if(feeRate1<10000){
                    (,int256 amount1)=IUniswapV3PoolActions(pair0).swap(
                        pair1,
                        true,
                        int256(amountIn),
                        MIN_SQRT_RATIO,
                        new bytes(0)
                    );
                    amount=uint256(-amount1);
                }else{
                    (,int256 amount1)=IUniswapV3PoolActions(pair0).swap(
                        address(this),
                        true,
                        int256(amountIn),
                        MIN_SQRT_RATIO,
                        new bytes(0)
                    );
                    amount=uint256(-amount1);
                }
            }else{
                initCaller(feeRate0,pair0,path1,path0);
                if(feeRate1<10000){
                    (int256 amount0,)=IUniswapV3PoolActions(pair0).swap(
                        pair1,
                        false,
                        int256(amountIn),
                        MAX_SQRT_RATIO,
                        new bytes(0)
                    );
                    amount=uint256(-amount0);
                }else{
                    (int256 amount0,)=IUniswapV3PoolActions(pair0).swap(
                        address(this),
                        false,
                        int256(amountIn),
                        MAX_SQRT_RATIO,
                        new bytes(0)
                    );
                    amount=uint256(-amount0);
                }
            }
            midToken=address(0);//重置回调route合约的权限
            caller=address(0);//重置回调route合约的权限
        }
    }
    function swapLast(
        uint amountIn,
        address recipient,
        uint16 feeRate,
        address pair,
        address path0,
        address path1
    )internal {
        if (feeRate==1) {//AerodromePairV2
            if(path0<path1){
                uniSwapV2Swap(pair,0,IAerodromePairV2(pair).getAmountOut(amountIn, path0),recipient);
            }else{
                uniSwapV2Swap(pair,IAerodromePairV2(pair).getAmountOut(amountIn, path0),0, recipient);
            }
        }else if(feeRate==2){//IDODO(pair).sellBase
            IDODO(pair).sellBase(recipient);
        }else if(feeRate==3){//IDODO(pair).sellQuote
            IDODO(pair).sellQuote(recipient);
        }else if(feeRate==4){//IDODO(pair).sellBaseToken
            tokenTransfer(path1, recipient, IDODO(pair).sellBaseToken(amountIn,0,new bytes(0)));
        }else if(feeRate==5){//IDODO(pair).querySellBaseToken
            tokenTransfer(path1, recipient, IDODO(pair).buyBaseToken(IDODO(pair).querySellBaseToken(amountIn),amountIn,new bytes(0)));
        }else if (feeRate==10002) {//balancer
            IBalancer.SingleSwap memory singleSwap;
            IBalancer.FundManagement memory funds;
            singleSwap.poolId=balancerPoolIds[pair];
            singleSwap.kind=IBalancer.SwapKind.GIVEN_IN;
            singleSwap.assetIn=IAsset(path0);
            singleSwap.assetOut=IAsset(path1);
            singleSwap.amount=amountIn;
            funds.sender=address(this);
            funds.fromInternalBalance=false;
            funds.toInternalBalance=false;
            funds.recipient=payable(recipient);
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, balancerAddr,amountIn+1);
            IBalancer(balancerAddr).swap(singleSwap,funds,10,UINT256_MAX);
        }else if (feeRate==10003) {//CurveAavePool
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, curveAavePool,amountIn+1);
            tokenTransfer(path1, recipient, ICurveAavePool(curveAavePool).exchange_underlying(
                curveTokenInt128Index[path0], curveTokenInt128Index[path1], amountIn, 0
            ));
        }else if (feeRate==10004) {//CurveCryptoPool
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, curveCryptoPool,amountIn+1);
            ICurveCryptoPool(curveCryptoPool).exchange_underlying(
                curveTokenUint256Index[path0], curveTokenUint256Index[path1], amountIn, 0,recipient
            );
        }else if (feeRate==10005) {//fRouter sell
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, address(fRouter),amountIn+1);
            (, uint amount) = fRouter.sell(
                amountIn,
                path0,
                address(this)
            );
            tokenTransfer(path1, recipient, amount);
        }else if (feeRate==10006) {//fRouter buy
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, address(fRouter),amountIn+1);
            (,uint amount) = fRouter.buy(
                amountIn,
                path0,
                address(this)
            );
            tokenTransfer(path1, recipient, amount);
        }else if (feeRate<10000) {//uniSwapV2
            (uint112 reserve0,uint112 reserve1) = getTokenReserves(pair);
            if(path0<path1){
                uniSwapV2Swap(pair,0,getAmountOut(amountIn, reserve0, reserve1,feeRate),recipient);
            }else{
                uniSwapV2Swap(pair,getAmountOut(amountIn, reserve1, reserve0,feeRate),0, recipient);
            }
        }else{//uniSwapV3
            if(midToken==address(0)){
                midToken=address(1);//回调route合约的权限
            }
            if(path0<path1){
                initCaller(feeRate,pair,path0,path1);
                IUniswapV3PoolActions(pair).swap(
                    recipient,
                    true,
                    int256(amountIn),
                    MIN_SQRT_RATIO ,
                    new bytes(0)
                );
            }else{
                initCaller(feeRate,pair,path1,path0);
                IUniswapV3PoolActions(pair).swap(
                    recipient,
                    false,
                    int256(amountIn),
                    MAX_SQRT_RATIO,
                    new bytes(0)
                );
            }
            midToken=address(0);//重置回调route合约的权限
            caller=address(0);//重置回调route合约的权限
        }
    }
    function swapLastWithFee(
        uint amountIn,
        address recipient,
        uint16 feeRate,
        address pair,
        address path0,
        address path1
    )internal {
        if (feeRate==1) {//AerodromePairV2
            (uint112 reserve0,uint112 reserve1) = getTokenReserves(pair);
            if(path0<path1){
                amountIn=getTokenBalanceOf(path0,pair)-reserve0;
                uniSwapV2Swap(pair,0,IAerodromePairV2(pair).getAmountOut(amountIn, path0),recipient);
            }else{
                amountIn=getTokenBalanceOf(path0,pair)-reserve1;
                uniSwapV2Swap(pair,IAerodromePairV2(pair).getAmountOut(amountIn, path0),0, recipient);
            }
        }else if(feeRate==2){//IDODO(pair).sellBase
            IDODO(pair).sellBase(recipient);
        }else if(feeRate==3){//IDODO(pair).sellQuote
            IDODO(pair).sellQuote(recipient);
        }else if(feeRate==4){//IDODO(pair).sellBaseToken,不支持fee
            IDODO(pair).sellBaseToken(amountIn,0,new bytes(0));
            tokenTransfer(path1, recipient, getTokenBalanceOf(path1,address(this)));
        }else if(feeRate==5){//IDODO(pair).querySellBaseToken,不支持fee
            IDODO(pair).buyBaseToken(IDODO(pair).querySellBaseToken(amountIn),amountIn,new bytes(0));
            tokenTransfer(path1, recipient, getTokenBalanceOf(path1,address(this)));
        }else if (feeRate==10002) {//balancer
            IBalancer.FundManagement memory funds;
            funds.sender=address(this);
            funds.fromInternalBalance=false;
            funds.toInternalBalance=false;
            IBalancer.SingleSwap memory singleSwap;
            singleSwap.poolId=balancerPoolIds[pair];
            singleSwap.kind=IBalancer.SwapKind.GIVEN_IN;
            singleSwap.assetIn=IAsset(path0);
            singleSwap.assetOut=IAsset(path1);
            funds.recipient=payable(recipient);
            tokenApprove(path0, balancerAddr,amountIn+1);
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            singleSwap.amount=getTokenBalanceOf(path0,address(this));
            IBalancer(balancerAddr).swap(singleSwap,funds,10,UINT256_MAX);

        }else if (feeRate==10003) {//CurveAavePool
            tokenApprove(path0, curveAavePool,amountIn+1);
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            ICurveAavePool(curveAavePool).exchange_underlying(
                curveTokenInt128Index[path0], curveTokenInt128Index[path1], getTokenBalanceOf(path0,address(this)), 0
            );
            tokenTransfer(path1, recipient, getTokenBalanceOf(path1,address(this)));
        }else if (feeRate==10004) {//CurveCryptoPool
            tokenApprove(path0, curveCryptoPool,amountIn+1);
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            ICurveCryptoPool(curveCryptoPool).exchange_underlying(
                curveTokenUint256Index[path0], curveTokenUint256Index[path1], getTokenBalanceOf(path0,address(this)), 0,recipient
            );
        }else if (feeRate==10005) {//fRouter sell
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, address(fRouter),amountIn+1);
            fRouter.sell(
                amountIn,
                path0,
                address(this)
            );
            tokenTransfer(path1, recipient, getTokenBalanceOf(path1,address(this)));
        }else if (feeRate==10006) {//fRouter buy
            if(midToken==address(0)){//代表是否是中间代币
                swapCallBack.callBack(abi.encodePacked(address(this),amountIn));
            }
            tokenApprove(path0, address(fRouter),amountIn+1);
            fRouter.buy(
                amountIn,
                path0,
                address(this)
            );
            tokenTransfer(path1, recipient, getTokenBalanceOf(path1,address(this)));
        }else if (feeRate<10000) {//uniSwapV2
            (uint112 reserve0,uint112 reserve1) = getTokenReserves(pair);
            if(path0<path1){
                amountIn=getTokenBalanceOf(path0,pair)-reserve0;
                uniSwapV2Swap(pair,0,getAmountOut(amountIn, reserve0, reserve1,feeRate),recipient);
            }else{
                amountIn=getTokenBalanceOf(path0,pair)-reserve1;
                uniSwapV2Swap(pair,getAmountOut(amountIn, reserve1, reserve0,feeRate),0, recipient);
            }
        }else{//uniSwapV3
            if(midToken==address(0)){
                midToken=address(1);//回调route合约的权限
            }else{
                uint path0AmountIn=getTokenBalanceOf(path0,address(this));
                if(amountIn>path0AmountIn){
                    amountIn=path0AmountIn;
                }
            }
            if(path0<path1){
                initCaller(feeRate,pair,path0,path1);
                IUniswapV3PoolActions(pair).swap(
                    recipient,
                    true,
                    int256(amountIn),
                    MIN_SQRT_RATIO ,
                    new bytes(0)
                );
            }else{
                initCaller(feeRate,pair,path1,path0);
                IUniswapV3PoolActions(pair).swap(
                    recipient,
                    false,
                    int256(amountIn),
                    MAX_SQRT_RATIO,
                    new bytes(0)
                );
            }
            midToken=address(0);//重置回调route合约的权限
            caller=address(0);//重置回调route合约的权限
        }
    }
    //回调
    function _swapCallback(
        int256 amount,
        uint dexClassifications
    )private{
        if(caller==msg.sender||callbackValidation.verifyCallback(msg.sender,dexClassifications)){
            if(midToken==address(1)){
                swapCallBack.callBack(abi.encodePacked(msg.sender,uint256(amount)));
            }else{
                tokenTransfer(midToken, msg.sender, uint256(amount));
            }
        }
    }
    /*uniSwapV3 回调*/
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory
    )external{
        if (amount0Delta > 0) {
            _swapCallback(amount0Delta,1);
        }else{
            _swapCallback(amount1Delta,1);
        }
    }
   /*panCakeV3 回调*/
    function pancakeV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory
    )external{
        if (amount0Delta > 0) {
            _swapCallback(amount0Delta,2);
        }else{
            _swapCallback(amount1Delta,2);
        }
    }
    /*quickSwapV3*/
    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory
    )external{
        if (amount0Delta > 0) {
            _swapCallback(amount0Delta,3);
        }else{
            _swapCallback(amount1Delta,3);
        }
    }
    function initCaller(uint16 feeRate,address pair,address token0,address token1) internal  {
        if(feeRate==20000){//uniswapV3
            bytes32 salt=keccak256(abi.encode(
                token0,token1,IUniswapV3PoolActions(pair).fee()
            ));
            if(pair==computeAddress(salt,hashedInitCode1,factory1)){
                caller=pair;
            }
        }
        if(feeRate==20001){//pancakeV3
            bytes32 salt=keccak256(abi.encode(
                token0,token1,IUniswapV3PoolActions(pair).fee()
            ));
            if(pair==computeAddress(salt,hashedInitCode2,factory2)){
                caller=pair;
            }
        }
        if(feeRate==20003){//AlgebraSwapV3
            if(IUniswapV3PoolActions(factory3).isPool(pair)){
                caller=pair;
            }
        }
    }
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address factory) internal view returns (address addr) {
        bytes32 deployer=bytes32(uint256(uint160(factory)));
        if(chainId==324){//zksync_chain
            /// @solidity memory-safe-assembly
            assembly {
                let ptr := mload(0x40) // Get free memory pointer
                mstore(add(ptr, 0x80), 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470)
                mstore(add(ptr, 0x60), bytecodeHash)
                mstore(add(ptr, 0x40), salt)
                mstore(add(ptr, 0x20), deployer)
                mstore(ptr, 0x2020dba91b30cc0006188af794c2fb30dd8520db7e2c088b7fc7c103c00ca494)
                let start := add(ptr, 0x0)
                addr := and(keccak256(start, 160), 0xffffffffffffffffffffffffffffffffffffffff)
            }
        }else{
            /// @solidity memory-safe-assembly
            assembly {
                let ptr := mload(0x40) // Get free memory pointer
                mstore(add(ptr, 0x40), bytecodeHash)
                mstore(add(ptr, 0x20), salt)
                mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
                let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
                mstore8(start, 0xff)
                addr := and(keccak256(start, 85), 0xffffffffffffffffffffffffffffffffffffffff)
            }
        }
    }

}