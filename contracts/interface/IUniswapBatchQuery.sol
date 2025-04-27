// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface IUniswapBatchQuery {
    function getFactoryInfos() external view returns(
        address[] memory _factorys,
        address[] memory _positionManagers,
        uint[] memory _poolfees,
        uint[] memory _flags,
        uint[] memory _lens,
        uint[] memory _classifications,
        string[] memory _names,
        bytes32[] memory _hashedInitCodes
    );
    function getDexInfos() external view returns(
        address[] memory _factorys,
        uint[] memory _flags,
        uint[] memory _classifications,
        bytes32[] memory _hashedInitCodes
    );
    function getHashedInitCode(address factory) external view returns(
        bytes32 hashedInitCode
    );
}