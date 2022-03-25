// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILinearPool {
    function getBptIndex() external view returns (uint256);

    function getMainIndex() external view returns (uint256);

    function getMainToken() external view returns (address);

    function getPoolId() external view returns (bytes32);

    function getWrappedIndex() external view returns (uint256);

    function getWrappedToken() external view returns (address);

    function getWrappedTokenRate() external view returns (uint256);
}
