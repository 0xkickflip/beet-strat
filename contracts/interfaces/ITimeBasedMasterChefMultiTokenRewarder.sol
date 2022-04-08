// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.0;

interface ITimeBasedMasterChefMultiTokenRewarder {
    function pendingTokens(
        uint256 pid,
        address userAddress,
        uint256
    ) external view returns (IERC20[] memory tokens, uint256[] memory rewardAmounts);
}
