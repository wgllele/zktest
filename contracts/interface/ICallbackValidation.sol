// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
interface ICallbackValidation{
    function verifyCallback(address caller,uint dexClassifications)external view returns(bool);
}