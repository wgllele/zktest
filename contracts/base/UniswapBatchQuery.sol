// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
import "../interface/IUniswapBatchQuery.sol";
import "../interface/INonfungiblePositionManager.sol";
import "../interface/IUniswapV2Pair.sol";
import "./CallbackValidation.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract UniswapBatchQuery is Ownable,Pausable,CallbackValidation,IUniswapBatchQuery{
    mapping(address => string) names;

    mapping(address => address) positionManagers;
    mapping(address => address) positiondeployer;
    mapping(address => uint) poolfees;
    mapping(address => uint) flags;
    mapping(address => bytes4) allPairsLengthSelectors;
    mapping(address => bytes4) allPairsSelectors;
    mapping (address  => bool) public adminMap;
    constructor () Ownable(msg.sender)payable {
        adminMap[msg.sender]=true;
        uint _chainId;
        assembly {
            _chainId :=chainid()
        }
        chainId=_chainId;
    }
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }
    receive() external payable {}
    fallback() external payable {}


    function _computeAddress(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        bytes32 bytecodeHash
    ) private view returns (address pool) {
        require(token0 < token1);
        pool=computeAddress(keccak256(abi.encode(token0, token1, fee)),bytecodeHash,factory);
    }

    function getFactoryInfos() external view returns(
        address[] memory _factorys,
        address[] memory _positionManagers,
        uint[] memory _poolfees,
        uint[] memory _flags,
        uint[] memory _lens,
        uint[] memory _classifications,
        string[] memory _names,
        bytes32[] memory _hashedInitCodes
    ){
        _factorys=factorys;
        uint len=_factorys.length;
        _positionManagers=new address[](len);
        _poolfees=new uint[](len);
        _flags=new uint[](len);
        _lens=new uint[](len);
        _classifications=new uint[](len);
        _names=new string[](len);
        _hashedInitCodes=new bytes32[](len);
        for(uint i;i<len;++i){
            bytes4 selector=allPairsLengthSelectors[_factorys[i]];
            if(selector!=0x0){
                (bool success, bytes memory data) = _factorys[i].staticcall(
                    abi.encodeWithSelector(selector)
                );
                if(success){
                    _lens[i]=abi.decode(data, (uint256));
                }
            }
            _positionManagers[i]=positionManagers[_factorys[i]];
            _names[i]=names[_factorys[i]];
            _classifications[i]=classifications[_factorys[i]];
            _poolfees[i]=poolfees[_factorys[i]];
            _flags[i]=flags[_factorys[i]];
            _hashedInitCodes[i]=hashedInitCodes[_factorys[i]];
        }
    }
    function getDexInfos() external view returns(
        address[] memory _factorys,
        uint[] memory _flags,
        uint[] memory _classifications,
        bytes32[] memory _hashedInitCodes
    ){
        _factorys=factorys;
        uint len=_factorys.length;
        _flags=new uint[](len);
        _classifications=new uint[](len);
        _hashedInitCodes=new bytes32[](len);
        for(uint i;i<len;++i){
            _classifications[i]=classifications[_factorys[i]];
            _flags[i]=flags[_factorys[i]];
            _hashedInitCodes[i]=hashedInitCodes[_factorys[i]];
        }
    }
    function getHashedInitCode(address factory) external view returns(
        bytes32 hashedInitCode
    ){
        hashedInitCode=hashedInitCodes[factory];
    }
    function addUniV3Info(
        address _deployer,
        uint classification,
        string memory name,
        address _positionManager,
        bytes32 _hashedInitCode
    ) public{
        require(adminMap[msg.sender],"not admin");
        factorys.push(_deployer);
        positiondeployer[_positionManager]=_deployer;
        positionManagers[_deployer]=_positionManager;
        classifications[_deployer]=classification;
        names[_deployer]=name;
        hashedInitCodes[_deployer]=_hashedInitCode;
    }
    function addV2FactoryInfo(
        address _factory,
        uint _poolfee,
        uint classification,
        string memory name
    ) public{
        require(adminMap[msg.sender],"not admin");
        factorys.push(_factory);
        classifications[_factory]=classification;
        names[_factory]=name;
        poolfees[_factory]=_poolfee;
        allPairsSelectors[_factory]=IUniswapV2Factory.allPairs.selector;
        allPairsLengthSelectors[_factory]=IUniswapV2Factory.allPairsLength.selector;
    }
    function addAlgebraSwapV3FactoryInfo(
        address _factory,
        uint _poolfee,
        uint classification,
        string memory name
    ) public{
        require(adminMap[msg.sender],"not admin");
        factorys.push(_factory);
        classifications[_factory]=classification;
        names[_factory]=name;
        poolfees[_factory]=_poolfee;
        allPairsSelectors[_factory]=IUniswapV2Factory.allPools.selector;
        allPairsLengthSelectors[_factory]=IUniswapV2Factory.allPoolsLength.selector;
    }

    function addV2FactoryInfo(
        address _factory,
        uint _poolfee,
        uint classification,
        string memory name,
        bytes4 _allPairsSelectors,
        bytes4 _allPairsLengthSelectors
    ) external{
        require(adminMap[msg.sender],"not admin");
        factorys.push(_factory);
        classifications[_factory]=classification;
        names[_factory]=name;
        poolfees[_factory]=_poolfee;
        allPairsSelectors[_factory]=_allPairsSelectors;
        allPairsLengthSelectors[_factory]=_allPairsLengthSelectors;
    }
    function setFactoryInfo(
        address _factory,
        uint _poolfee,
        uint _classification,
        string memory _name,
        address _positionManager,
        bytes32 _hashedInitCode
    ) external{
        require(adminMap[msg.sender],"not admin");
        positionManagers[_factory]=_positionManager;
        positiondeployer[_positionManager]=_factory;
        poolfees[_factory]=_poolfee;
        classifications[_factory]=_classification;
        names[_factory]=_name;
        hashedInitCodes[_factory]=_hashedInitCode;
    }
    function setFactoryFlag(
        address _factory,
        bytes32 _hashedInitCode,
        uint _flag
    ) external{
        require(adminMap[msg.sender],"not admin");
        hashedInitCodes[_factory]=_hashedInitCode;
        flags[_factory]=_flag;
    }
    function addAdmin(address addr) external onlyOwner returns(bool) {
        require(!adminMap[addr]);
        adminMap[addr] = true;
        return true;
    }
    function deleteAdmin(address addr) external onlyOwner returns(bool) {
        require(adminMap[addr]);
        adminMap[addr] =false;
        return true;
    }

    function positions(uint256 tokenId,address pm) internal   view returns (
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpace,
        address poolAddr
    ){
        (bool success, bytes memory data) =
                            pm.staticcall(abi.encodeWithSelector(INonfungiblePositionManager.positions.selector, tokenId));
        if(success && data.length >= 32){
            (,,token0,token1,fee,,,,,,,
            )=abi.decode(data, (uint96,
                address,
                address,
                address,
                uint24,
                int24,
                int24,
                uint128,
                uint256,
                uint256,
                uint128 ,
                uint128));
            address deployer=positiondeployer[pm];
            poolAddr=_computeAddress(deployer,token0,token1,fee,hashedInitCodes[deployer]);
            tickSpace=IUniswapV3PoolImmutables(poolAddr).tickSpacing();

        }
    }
    function batchpositions(uint256[] memory tokenIds,address pm) public view returns (
        address[] memory token0s,
        address[] memory token1s,
        uint24[] memory fees,
        int24[] memory tickSpaces,
        address[] memory poolAddrs
    ){
        uint l=tokenIds.length;
        token0s=new address[](l);
        token1s=new address[](l);
        fees=new uint24[](l);
        tickSpaces=new int24[](l);
        poolAddrs=new address[](l);
        for(uint i;i<l;++i){
            (token0s[i],token1s[i],fees[i],tickSpaces[i],poolAddrs[i])=positions(tokenIds[i],pm);
        }
    }
    function batchpositionsStep(uint256 tokenIdStart,uint nums,address pm) external view returns (
        address[] memory token0s,
        address[] memory token1s,
        uint24[] memory fees,
        int24[] memory tickSpaces,
        address[] memory poolAddrs
    ){
        uint256[] memory tokenIds=new uint256[](nums);
        for(uint i;i<nums;++i){
            tokenIds[i]=tokenIdStart+i;
        }
        return batchpositions(tokenIds,pm);
    }
    function tokenByIndex(uint256 index,address pm) external view returns (uint256){
        return INonfungiblePositionManager(pm).tokenByIndex(index);
    }
    function totalSupply(address pm) external view returns (uint256){
        return INonfungiblePositionManager(pm).totalSupply();
    }
    function lastTokenId(address pm) external view returns (uint256){
        return INonfungiblePositionManager(pm).tokenByIndex(INonfungiblePositionManager(pm).totalSupply()-1);
    }
    function getPairs(
        uint[] memory pairAddrIndexs,
        address factory
    ) public view returns (
        address[] memory pairAddrs,
        address[] memory token0s,
        address[] memory token1s
    ) {
        uint length=pairAddrIndexs.length;
        pairAddrs=new address[](length);
        token0s=new address[](length);
        token1s=new address[](length);
        for(uint i;i<length;i++){
            bytes4 selector=allPairsSelectors[factory];
            (bool success, bytes memory data) = factory.staticcall(
                abi.encodeWithSelector(selector,pairAddrIndexs[i])
            );
            if(success){
                pairAddrs[i]=abi.decode(data, (address));
            }
            token0s[i]=IUniswapV2Pair(pairAddrs[i]).token0();
            token1s[i]=IUniswapV2Pair(pairAddrs[i]).token1();
        }
    }
    function getErcInfos(
        address[] calldata tokens
    ) external view returns(
        bytes[] memory decimals,
        bytes[] memory _names,
        bytes[] memory symbols
    ){
        uint length=tokens.length;
        decimals=new bytes[](length);
        _names=new bytes[](length);
        symbols=new bytes[](length);
        for(uint i;i<length;++i){
            (decimals[i],_names[i],symbols[i])= _getTokenInfo(tokens[i]);
        }
    }
    function getPairInfos(
        address[] calldata pairs
    ) external view returns(
        bytes[] memory token0s,
        bytes[] memory token1s,
        bytes[] memory fees
    ){
        uint length=pairs.length;
        token0s=new bytes[](length);
        token1s=new bytes[](length);
        fees=new bytes[](length);
        for(uint i;i<length;++i){
            (token0s[i],token1s[i],fees[i])= _getPairInfo(pairs[i]);
        }
    }
    function _getPairInfo(
        address pair
    ) private view returns (
        bytes memory token0,
        bytes memory token1,
        bytes memory fee
    ) {
        (bool b, bytes memory _token0) = pair.staticcall(
            abi.encodeWithSelector(IUniswapV3PoolImmutables.token0.selector)
        );
        if (b){
            token0=_token0;
        }
        bytes memory _token1;
        (b,_token1) = pair.staticcall(
            abi.encodeWithSelector(IUniswapV3PoolImmutables.token1.selector)
        );
        if (b){
            token1=_token1;
        }
        bytes memory _fee;
        (b, _fee) = pair.staticcall(
            abi.encodeWithSelector(IUniswapV3PoolImmutables.fee.selector)
        );
        if (b){
            fee=_fee;
        }
    }
    function _getTokenInfo(
        address token
    ) private view returns (
        bytes memory decimals,
        bytes memory name,
        bytes memory symbol
    ) {
        (bool b, bytes memory _decimals) = token.staticcall(
            abi.encodeWithSelector(IERC20Metadata.decimals.selector)
        );
        if (b){
            decimals=_decimals;
        }
        bytes memory _name;
        (b,_name) = token.staticcall(
            abi.encodeWithSelector(IERC20Metadata.name.selector)
        );
        if (b){
            name=_name;
        }
        bytes memory _symbol;
        (b,_symbol) = token.staticcall(
            abi.encodeWithSelector(IERC20Metadata.symbol.selector)
        );
        if (b){
            symbol=_symbol;
        }
    }
    function getReservesByPairs(bytes memory _pairs) external view returns (bytes32[] memory) {
        uint pairsCount;
        assembly {
            pairsCount := div(mload(_pairs), 0x14)
        }
        bytes32[] memory  result = new bytes32[](pairsCount * 3);
        assembly {
            let size := 0x60 // Size of the return data (reserve0, reserve1, blockTimestampLast)
            let callData := mload(0x40) // Allocate memory for the function selector
            mstore(callData, 0x0902f1ac00000000000000000000000000000000000000000000000000000000) // 4-byte function selector of the getReserves() function
        // Update the free memory pointer
            mstore(0x40, add(callData, 0x04))
        // let pairsCount := shr(0xe0, calldataload(sub(_pairs.offset, 0x20))) // Get the length of the _pairs array
            for { let i := 0 } lt(i, pairsCount) { i := add(i, 1) } {
            // Load the pair address from the calldata
                let pair := shr(96, mload(add(add(_pairs, 0x20), mul(0x14, i))))
            // Call the getReserves() function with preallocated memory for function selector
                pop(staticcall(gas(), pair, callData, 0x04, add(add(result, 0x20),mul(i, size)), size))
            }
        // Update the free memory pointer
            mstore(0x40, add(mload(0x40), mul(pairsCount, size)))
        }
        return result;
    }
    function getTokenBalances(bytes memory transactions) external  view returns (bytes32[] memory result) {
        uint count;
        assembly {
            count := div(mload(transactions), 0x38)
        }
        result = new bytes32[](count);
        assembly {
            for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                let pos:=mul(0x38, i)
                let token := shr(96, mload(add(add(transactions, 0x20), pos)))
                let data := add(add(transactions, 0x20), add(pos,0x14))
                pop(staticcall(gas(), token, data, 0x24, add(add(result, 0x20),mul(i, 0x20)), 0x20))
            }
        }
    }
    function getTokenUintBalances(bytes memory transactions) external  view returns (uint[] memory result) {
        uint count;
        assembly {
            count := div(mload(transactions), 0x38)
        }
        result = new uint[](count);
        assembly {
            for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                let pos:=mul(0x38, i)
                let token := shr(96, mload(add(add(transactions, 0x20), pos)))
                let data := add(add(transactions, 0x20), add(pos,0x14))
                pop(staticcall(gas(), token, data, 0x24, add(add(result, 0x20),mul(i, 0x20)), 0x20))
            }
        }
    }
}
//0x7AE681C07C24641F36e763779a768D6b4c42EEd3