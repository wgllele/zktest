// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
import "../interface/IUniswapV2Factory.sol";
import "../interface/IUniswapV3PoolImmutables.sol";
import "../interface/ICallbackValidation.sol";

abstract contract CallbackValidation is ICallbackValidation {
    error CallbackInvalidCaller(address caller);
    address[] public factorys;
    mapping(address => bytes32) hashedInitCodes;
    mapping(address => uint) classifications;
    uint256 immutable chainId;

    function verifyCallback(address caller,uint dexClassifications)external view returns(bool){
        if(dexClassifications==3){
            if(IUniswapV2Factory(IUniswapV3PoolImmutables(caller).factory()).isPool(caller)){
                return true;
            }else{
                revert CallbackInvalidCaller(caller);
            }
        }
        bytes32 salt=keccak256(abi.encode(
            IUniswapV3PoolImmutables(caller).token0(),
            IUniswapV3PoolImmutables(caller).token1(),
            IUniswapV3PoolImmutables(caller).fee()
        ));
        address factory=IUniswapV3PoolImmutables(caller).factory();
        if(dexClassifications==2){//PancakeV3
            factory=IUniswapV2Factory(factory).poolDeployer();
        }
        if (caller==computeAddress(salt,hashedInitCodes[factory],factory)){
            return true;
        }
        revert CallbackInvalidCaller(caller);
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