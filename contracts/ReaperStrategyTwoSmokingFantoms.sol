// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv2.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IBeetVault.sol";
import "./interfaces/ILinearPool.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/ISDRewarder.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @dev LP compounding strategy for Beethoven-X pools that use yearn-boosted linear pools as underlying
 *      "tokens".
 */
contract ReaperStrategyTwoSmokingFantoms is ReaperBaseStrategyv2 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    address public constant BEET_VAULT = address(0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce);
    address public constant MASTER_CHEF = address(0x8166994d9ebBe5829EC86Bd81258149B87faCfd3);
    address public constant SPOOKY_ROUTER = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    /**
     * @dev Tokens Used:
     * {want} - LP token for the Beethoven-x pool.
     * {BEETS} - Reward token for depositing LP into MasterChef.
     * {SD} - Secondary reward token for depositing LP into MasterChef.
     * {WFTM} - Required for charging fees and joining pool.
     * {USDC} - Used an intermediary token to convert {totalFee}% of {SD} to {WFTM}.
     * {sFTMx} - One of the pool tokens, used to join pool through a swap.
     * {WFTM_LINEAR_BPT} - Other pool token that's used to join pool via swaps.
     */
    address public constant want = address(0xc0064b291bd3D4ba0E44ccFc81bF8E7f7a579cD2);
    address public constant BEETS = address(0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e);
    address public constant SD = address(0x412a13C109aC30f0dB80AD3Bd1DeFd5D0A6c0Ac6);
    address public constant WFTM = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public constant USDC = address(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    address public constant sFTMx = address(0xd7028092c830b5C8FcE061Af2E593413EbbC1fc1);
    address public constant WFTM_LINEAR_BPT = address(0xC3BF643799237588b7a6B407B3fc028Dd4e037d2);

    // pools used to swap tokens
    bytes32 public constant WFTM_BEETS_POOL = 0xcde5a11a4acb4ee4c805352cec57e236bdbc3837000200000000000000000019;
    bytes32 public constant SD_USDC_sFTMx_POOL = 0x0b372f3a9039d02b87434d5c1297060c1ee4d5ff00010000000000000000042f;
    bytes32 public constant WFTM_USDC_POOL = 0xcdf68a4d525ba2e90fe959c74330430a5a6b8226000200000000000000000008;
    bytes32 public constant WFTM_LINEAR_POOL = 0xc3bf643799237588b7a6b407b3fc028dd4e037d200000000000000000000022d;

    /**
     * @dev Strategy variables
     * {mcPoolId} - ID of MasterChef pool in which to deposit LP tokens
     * {beetsPoolId} - bytes32 ID of the Beethoven-X pool corresponding to {want}
     */
    uint256 public constant mcPoolId = 82;
    bytes32 public constant beetsPoolId = 0xc0064b291bd3d4ba0e44ccfc81bf8e7f7a579cd200000000000000000000042c;

    /**
     * @dev Initializes the strategy. Sets parameters and saves routes.
     * @notice see documentation for each variable above its respective declaration.
     */
    function initialize(
        address _vault,
        address[] memory _feeRemitters,
        address[] memory _strategists
    ) public initializer {
        __ReaperBaseStrategy_init(_vault, _feeRemitters, _strategists);
    }

    /**
     * @dev Function that puts the funds to work.
     *      It gets called whenever someone deposits in the strategy's vault contract.
     */
    function _deposit() internal override {
        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBalance != 0) {
            IERC20Upgradeable(want).safeIncreaseAllowance(MASTER_CHEF, wantBalance);
            IMasterChef(MASTER_CHEF).deposit(mcPoolId, wantBalance, address(this));
        }
    }

    /**
     * @dev Withdraws funds and sends them back to the vault.
     */
    function _withdraw(uint256 _amount) internal override {
        uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBal < _amount) {
            IMasterChef(MASTER_CHEF).withdrawAndHarvest(mcPoolId, _amount - wantBal, address(this));
        }

        IERC20Upgradeable(want).safeTransfer(vault, _amount);
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     *      1. Claim {BEETS} and {SD} rewards from MasterChef.
     *      2. Perform swaps and charge fees.
     *      3. Create more {want} by "swapping in" to pool.
     *      4. Deposit.
     */
    function _harvestCore() internal override {
        IMasterChef(MASTER_CHEF).harvest(mcPoolId, address(this));
        _performSwapsAndChargeFees();
        _addLiquidity();
        deposit();
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of WFTM gained from reward
     */
    function _performSwapsAndChargeFees() internal {
        IERC20Upgradeable wftm = IERC20Upgradeable(WFTM);
        uint256 startingWftmBal = wftm.balanceOf(address(this));
        uint256 wftmFee = 0;

        _swap(
            SD,
            USDC,
            (IERC20Upgradeable(SD).balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR,
            SD_USDC_sFTMx_POOL,
            true
        );
        _swap(USDC, WFTM, IERC20Upgradeable(USDC).balanceOf(address(this)), WFTM_USDC_POOL, true);
        wftmFee += wftm.balanceOf(address(this)) - startingWftmBal;
        startingWftmBal = wftm.balanceOf(address(this));

        _swap(BEETS, WFTM, IERC20Upgradeable(BEETS).balanceOf(address(this)), WFTM_BEETS_POOL, true);
        wftmFee += ((wftm.balanceOf(address(this)) - startingWftmBal) * totalFee) / PERCENT_DIVISOR;

        if (wftmFee != 0) {
            uint256 callFeeToUser = (wftmFee * callFee) / PERCENT_DIVISOR;
            uint256 treasuryFeeToVault = (wftmFee * treasuryFee) / PERCENT_DIVISOR;
            uint256 feeToStrategist = (treasuryFeeToVault * strategistFee) / PERCENT_DIVISOR;
            treasuryFeeToVault -= feeToStrategist;

            wftm.safeTransfer(msg.sender, callFeeToUser);
            wftm.safeTransfer(treasury, treasuryFeeToVault);
            wftm.safeTransfer(strategistRemitter, feeToStrategist);
        }
    }

    /**
     * @dev Core harvest function.
     *      Creates new {want} tokens using {WFTM} and {SD} balance.
     */
    function _addLiquidity() internal {
        _swap(WFTM, WFTM_LINEAR_BPT, IERC20Upgradeable(WFTM).balanceOf(address(this)), WFTM_LINEAR_POOL, true);
        _swap(WFTM_LINEAR_BPT, want, IERC20Upgradeable(WFTM_LINEAR_BPT).balanceOf(address(this)), beetsPoolId, false);

        _swap(SD, sFTMx, IERC20Upgradeable(SD).balanceOf(address(this)), SD_USDC_sFTMx_POOL, true);
        _swap(sFTMx, want, IERC20Upgradeable(sFTMx).balanceOf(address(this)), beetsPoolId, true);
    }

    /**
     * @dev Core harvest function. Swaps {_amount} of {_from} to {_to} using {_poolId}.
     *      Prior to requesting the swap, allowance is increased iff {_shouldIncreaseAllowance}
     *      is true. This needs to false for the linear pool since they already have max allowance
     *      for {BEET_VAULT}.
     */
    function _swap(
        address _from,
        address _to,
        uint256 _amount,
        bytes32 _poolId,
        bool _shouldIncreaseAllowance
    ) internal {
        if (_from == _to || _amount == 0) {
            return;
        }

        IBeetVault.SingleSwap memory singleSwap;
        singleSwap.poolId = _poolId;
        singleSwap.kind = IBeetVault.SwapKind.GIVEN_IN;
        singleSwap.assetIn = IAsset(_from);
        singleSwap.assetOut = IAsset(_to);
        singleSwap.amount = _amount;
        singleSwap.userData = abi.encode(0);

        IBeetVault.FundManagement memory funds;
        funds.sender = address(this);
        funds.fromInternalBalance = false;
        funds.recipient = payable(address(this));
        funds.toInternalBalance = false;

        if (_shouldIncreaseAllowance) {
            IERC20Upgradeable(_from).safeIncreaseAllowance(BEET_VAULT, _amount);
        }
        IBeetVault(BEET_VAULT).swap(singleSwap, funds, 1, block.timestamp);
    }

    /**
     * @dev Function to calculate the total {want} held by the strat.
     *      It takes into account both the funds in hand, plus the funds in the MasterChef.
     */
    function balanceOf() public view override returns (uint256) {
        (uint256 amount, ) = IMasterChef(MASTER_CHEF).userInfo(mcPoolId, address(this));
        return amount + IERC20Upgradeable(want).balanceOf(address(this));
    }

    /**
     * @dev Returns the approx amount of profit from harvesting.
     *      Profit is denominated in WFTM, and takes fees into account.
     */
    function estimateHarvest() external view override returns (uint256 profit, uint256 callFeeToUser) {
        IMasterChef masterChef = IMasterChef(MASTER_CHEF);
        uint256 pendingReward = masterChef.pendingBeets(mcPoolId, address(this));
        uint256 totalRewards = pendingReward + IERC20Upgradeable(BEETS).balanceOf(address(this));

        if (totalRewards != 0) {
            // use SPOOKY_ROUTER here since IBeetVault doesn't have a view query function
            address[] memory beetsToWftmPath = new address[](2);
            beetsToWftmPath[0] = BEETS;
            beetsToWftmPath[1] = WFTM;
            profit += IUniswapV2Router01(SPOOKY_ROUTER).getAmountsOut(totalRewards, beetsToWftmPath)[1];
        }

        ISDRewarder rewarder = ISDRewarder(masterChef.rewarder(mcPoolId));
        pendingReward = rewarder.pendingToken(mcPoolId, address(this));
        totalRewards = pendingReward + IERC20Upgradeable(SD).balanceOf(address(this));
        if (totalRewards != 0) {
            address[] memory sdToWftmPath = new address[](3);
            sdToWftmPath[0] = SD;
            sdToWftmPath[1] = USDC;
            sdToWftmPath[2] = WFTM;
            profit += IUniswapV2Router01(SPOOKY_ROUTER).getAmountsOut(totalRewards, sdToWftmPath)[1];
        }

        profit += IERC20Upgradeable(WFTM).balanceOf(address(this));

        uint256 wftmFee = (profit * totalFee) / PERCENT_DIVISOR;
        callFeeToUser = (wftmFee * callFee) / PERCENT_DIVISOR;
        profit -= wftmFee;
    }

    /**
     * @dev Function to retire the strategy. Claims all rewards and withdraws
     *      all principal from external contracts, and sends everything back to
     *      the vault. Can only be called by strategist or owner.
     *
     * Note: this is not an emergency withdraw function. For that, see panic().
     */
    function _retireStrat() internal override {
        (uint256 poolBal, ) = IMasterChef(MASTER_CHEF).userInfo(mcPoolId, address(this));
        IMasterChef(MASTER_CHEF).withdrawAndHarvest(mcPoolId, poolBal, address(this));

        _swap(BEETS, WFTM, IERC20Upgradeable(BEETS).balanceOf(address(this)), WFTM_BEETS_POOL, true);
        _addLiquidity();

        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBalance != 0) {
            IERC20Upgradeable(want).safeTransfer(vault, wantBalance);
        }
    }

    /**
     * Withdraws all funds leaving rewards behind.
     */
    function _reclaimWant() internal override {
        IMasterChef(MASTER_CHEF).emergencyWithdraw(mcPoolId, address(this));
    }
}
