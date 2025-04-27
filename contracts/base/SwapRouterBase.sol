// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import "../interface/IWETH.sol";
import "../interface/ISwapCallBack.sol";
import "../interface/IAggregationExecutor.sol";
abstract contract SwapRouterBase is ISwapCallBack,Ownable,Pausable,ReentrancyGuardTransient{
    IWETH immutable WETH;
    IAggregationExecutor aggregationExecutor;
    address transient payer;
    address transient srcToken;
    uint transient amountMax;
    error EthTransfer(address recipient, uint256 amount);
    error OutIsLessThanOutMin();
    error InvalidCaller(address caller);
    struct SwapParam{
        uint8 dataLength;
        uint8 swapType;
        uint8 swapFee;
        address tokenIn;
        address tokenOut;
        uint8 methodType;
        uint16 feeRate;
    }
    struct UintParam{
        uint8 dataLength;
        uint8 swapType;
        uint16 feeRate;
    }
    constructor (address _WETH)  payable Ownable(msg.sender){
        WETH=IWETH(_WETH);
    }
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }
    receive() external payable {}
    fallback() external payable {}
    function updateAggregationExecutor(address _aggregationExecutor)external onlyOwner returns (bool) {
        aggregationExecutor=IAggregationExecutor(_aggregationExecutor);
        return true;
    }
    // gas optimization on get balanceOf fron BEP20 or ERC20 token
    function getTokenBalanceOf(address token, address holder) internal view returns (uint112 tokenBal) {
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(emptyPointer, 0x04), holder)
            let success := staticcall(gas(), token, emptyPointer, 0x24, emptyPointer, 0x40)
            if success {
                tokenBal := mload(emptyPointer)
            }
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
    }
    // gas optimization on transfer from token method
    function tokenTransferFrom(address token, address from, address recipient, uint256 amount) internal {
        bool failed = false;
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(emptyPointer, 0x04), from)
            mstore(add(emptyPointer, 0x24), recipient)
            mstore(add(emptyPointer, 0x44), amount)
            failed := iszero(call(gas(), token, 0, emptyPointer, 0x64, 0, 0))
            if failed {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
    ///The approach is consistent with uniswap, https://github.com/Uniswap/v3-periphery/blob/697c2474757ea89fec12a4e6db16a574fe259610/contracts/base/PeripheryPayments.sol#L30
    function sweepToken(
        address token,
        uint256 amountMinimum
    ) public payable onlyOwner{
        uint256 balanceToken=getTokenBalanceOf(token,address(this));
        require(balanceToken >= amountMinimum, 'Insufficient token');
        if (balanceToken > 0) {
            tokenTransfer(token,msg.sender,balanceToken);
        }
    }
    ///The approach is consistent with uniswap, https://github.com/Uniswap/v3-periphery/blob/697c2474757ea89fec12a4e6db16a574fe259610/contracts/base/PeripheryPayments.sol#L44
    function refundETH() external payable  onlyOwner{
        uint bal=address(this).balance;
        if (bal > 0){
            (bool success,) = payable(msg.sender).call{value: bal}(new bytes(0));
            require(success, 'refundETH:STE');
        }
    }
    function callBack(bytes memory callData)external{
        if(msg.sender!=address(aggregationExecutor)){
            revert InvalidCaller(msg.sender);
        }
        address recipient;
        uint value;
        assembly {
            recipient := shr(96, mload(add(add(callData, 0x20), 0x0)))
            value := mload(add(add(callData, 0x20), 0x14))
        }
        amountMax=amountMax-value;
        if(payer==address(0)){//transfer token WETH
            tokenTransfer(address(WETH),recipient,value);
        }else if(payer==address(1)){//transfer ETH
            _ethTransfer(recipient,value);
        }else{
            tokenTransferFrom(srcToken,payer,recipient,value);
        }
    }
    function _ethTransfer(address recipient, uint256 amount) internal {
        bool callStatus;
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), recipient, amount, 0, 0, 0, 0)
        }
        if (!callStatus) {
            revert EthTransfer(recipient, amount);
        }
    }

    function slice(
        bytes memory _bytes,
        uint256 _start
    ) internal pure returns (bytes memory) {
        uint256 _length=_bytes.length-_start;
        bytes memory tempBytes;
        assembly {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
            tempBytes := mload(0x40)
            // The first word of the slice result is potentially a partial
            // word read from the original array. To read it, we calculate
            // the length of that partial word and start copying that many
            // bytes into the array. The first word we copy will start with
            // data we don't care about, but the last `lengthmod` bytes will
            // land at the beginning of the contents of the new array. When
            // we're done copying, we overwrite the full first word with
            // the actual length of the slice.
            let lengthmod := and(_length, 31)

            // The multiplication in the next line is necessary
            // because when slicing multiples of 32 bytes (lengthmod == 0)
            // the following copy loop was copying the origin's length
            // and then ending prematurely not copying everything it should.
            let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
            let end := add(mc, _length)

            for {
                // The multiplication in the next line has the same exact purpose
                // as the one above.
                let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            mstore(tempBytes, _length)

            //update free-memory pointer
            //allocating the array padded to 32 bytes like the compiler does now
            mstore(0x40, and(add(mc, 31), not(31)))
        }

        return tempBytes;
    }

}
