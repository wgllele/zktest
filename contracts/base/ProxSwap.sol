// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import "../interface/IProxSwap.sol";
contract ProxSwap is IProxSwap {
    error CallThirdPartySwapError(address contractAddr);
    address immutable router;
    error UnauthorizedAccount(address account);
    modifier onlyRouter() {
        if (router != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
        _;
    }
    constructor() {
        router = msg.sender;
    }
    function callThirdPartySwap(
        bytes memory paramData,
        bytes memory swapData
    ) external onlyRouter{
        address tokenIn;
        address contractAddr;
        uint amountIn;
        uint length;
        assembly {
            length := mload(paramData)
            tokenIn := shr(96, mload(add(add(paramData, 0x20), 0x0)))//start:0,length:20(0x14)
            contractAddr := shr(96, mload(add(add(paramData, 0x20), 0x14)))//start:20(0x14),length:20(0x14)
            amountIn := mload(add(add(paramData, 0x20), 0x28))//start:40(0x28),length:32(0x20)
        }
        address approveAddr;
        if(length>0x48){
            assembly {
                approveAddr := shr(96, mload(add(add(paramData, 0x20), 0x48)))//start:72(0x48),length:20(0x14)
            }
        }else{
            approveAddr=contractAddr;
        }
        tokenApprove(tokenIn, approveAddr, amountIn);
        (bool success, bytes memory returndata) = contractAddr.call(swapData);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert CallThirdPartySwapError(contractAddr);
            }
        }
        tokenApprove(tokenIn, approveAddr, 1);
    }

    function callThirdPartySwapOut(
        bytes memory paramData,
        bytes memory swapData
    ) external onlyRouter{
        address recipient;
        address tokenOut;
        address tokenIn;
        address contractAddr;
        uint amountIn;
        uint length;
        assembly {
            length := mload(paramData)
            recipient := shr(96, mload(add(add(paramData, 0x20), 0x0)))//start:0,length:20(0x14)
            tokenOut := shr(96, mload(add(add(paramData, 0x20), 0x14)))//start:20(0x14),length:20(0x14)
            tokenIn := shr(96, mload(add(add(paramData, 0x20), 0x28)))//start:40(0x28),length:20(0x14)
            contractAddr := shr(96, mload(add(add(paramData, 0x20), 0x3c)))//start:60(0x3c),length:20(0x14)
            amountIn := mload(add(add(paramData, 0x20), 0x50))//start:80(0x50),length:32(0x20)
        }
        address approveAddr;
        if(length>0x70){
            assembly {
                approveAddr := shr(96, mload(add(add(paramData, 0x20), 0x70)))//start:112(0x70),length:20(0x14)
            }
        }else{
            approveAddr=contractAddr;
        }
        tokenApprove(tokenIn, approveAddr, amountIn);
        (bool success, bytes memory returndata) = contractAddr.call(swapData);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert CallThirdPartySwapError(contractAddr);
            }
        }
        tokenApprove(tokenIn, approveAddr, 1);
        tokenTransfer(tokenOut,recipient,getTokenBalanceOf(tokenOut,address(this)));
    }

    function getTokenBalanceOf(
        address token,
        address holder
    ) internal view returns (uint112 tokenBalance) {
        assembly {
            let emptyPointer := mload(0x40)
            mstore(
                emptyPointer,
                0x70a0823100000000000000000000000000000000000000000000000000000000
            )
            mstore(add(emptyPointer, 0x04), holder)
            if staticcall(
                gas(),
                token,
                emptyPointer,
                0x24,
                emptyPointer,
                0x40
            ) {
                tokenBalance := mload(emptyPointer)
            }
        }
    }
    // gas optimization on transfer token
    function tokenTransfer(
        address token,
        address recipient,
        uint256 amount
    ) internal {
        assembly {
            let emptyPointer := mload(0x40)
            mstore(
                emptyPointer,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(emptyPointer, 0x04), recipient)
            mstore(add(emptyPointer, 0x24), amount)
            if iszero(call(gas(), token, 0, emptyPointer, 0x44, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function tokenApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        assembly {
            let emptyPointer := mload(0x40)
            mstore(
                emptyPointer,
                0x095ea7b300000000000000000000000000000000000000000000000000000000
            )
            mstore(add(emptyPointer, 0x04), spender)
            mstore(add(emptyPointer, 0x24), amount)
            if iszero(call(gas(), token, 0, emptyPointer, 0x44, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
    function refundETH() external payable{
        uint bal=address(this).balance;
        if (bal > 0){
            (bool success,) = payable(router).call{value: bal}(new bytes(0));
            require(success, 'refundETH:STE');
        }
    }
    function sweepToken(
        address token,
        uint256 amountMinimum
    ) external payable{
        uint256 balanceToken=getTokenBalanceOf(token,address(this));
        require(balanceToken >= amountMinimum, 'Insufficient token');
        if (balanceToken > 0) {
            tokenTransfer(token,router,balanceToken);
        }
    }
}
