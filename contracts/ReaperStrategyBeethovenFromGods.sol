// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv2.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IBeetVault.sol";
import "./interfaces/ILinearPool.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "hardhat/console.sol";

/**
 * @dev LP compounding strategy for the From Gods, Boosted And Blessed Beethoven-X pool.
 */
contract ReaperStrategyBeethovenFromGods is ReaperBaseStrategyv2 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    address public constant BEET_VAULT = address(0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce);
    address public constant MASTER_CHEF = address(0x8166994d9ebBe5829EC86Bd81258149B87faCfd3);
    address public constant SPOOKY_ROUTER = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    /**
     * @dev Tokens Used:
     * {WFTM} - Required for charging fees. May also be used to join pool if there's {WFTM} underlying.
     * {USDC} - Underlying token of the want LP used to swap in to the want
     * {BEETS} - Reward token for depositing LP into MasterChef. May also be used to join pool if there's {BEETS} underlying.
     * {DEUS} - Secondary reward token for depositing LP into MasterChef.
     * {DEI} - Underlying token of the want LP used to swap in to the want
     * {want} - LP token for the Beethoven-x pool.
     */
    address public constant WFTM = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public constant USDC = address(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    address public constant BEETS = address(0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e);
    address public constant DEUS = address(0xDE5ed76E7c05eC5e4572CfC88d1ACEA165109E44);
    address public constant DEI = address(0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3);
    address public constant BB_YV_USD = address(0x5ddb92A5340FD0eaD3987D3661AfcD6104c3b757);
    address public want;

    // pools used to swap tokens
    bytes32 public constant WFTM_BEETS_POOL = 0xcde5a11a4acb4ee4c805352cec57e236bdbc3837000200000000000000000019;
    bytes32 public constant USDC_BEETS_POOL = 0x03c6b3f09d2504606936b1a4decefad204687890000200000000000000000015;
    bytes32 public constant DEI_DEUS_POOL = 0x0e8e7307e43301cf28c5d21d5fd3ef0876217d410002000000000000000003f1;
    bytes32 public constant BB_YV_USD_POOL = 0x3b998ba87b11a1c5bc1770de9793b17a0da61561000000000000000000000185;

    /**
     * @dev Strategy variables
     * {mcPoolId} - ID of MasterChef pool in which to deposit LP tokens
     * {beetsPoolId} - bytes32 ID of the Beethoven-X pool corresponding to {want}
     */
    uint256 public mcPoolId;
    bytes32 public beetsPoolId;

    /**
     * @dev Initializes the strategy. Sets parameters and saves routes.
     * @notice see documentation for each variable above its respective declaration.
     */
    function initialize(
        address _vault,
        address[] memory _feeRemitters,
        address[] memory _strategists,
        address _want,
        uint256 _mcPoolId
    ) public initializer {
        __ReaperBaseStrategy_init(_vault, _feeRemitters, _strategists);
        want = _want;
        mcPoolId = _mcPoolId;
        beetsPoolId = IBasePool(want).getPoolId();
    }

    /**
     * @dev Function that puts the funds to work.
     *      It gets called whenever someone deposits in the strategy's vault contract.
     */
    function _deposit() internal override {
        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBalance != 0) {
            IERC20Upgradeable(want).safeIncreaseAllowance(MASTER_CHEF, wantBalance);
            // IMasterChef(MASTER_CHEF).deposit(mcPoolId, wantBalance, address(this));
        }
    }

    /**
     * @dev Withdraws funds and sends them back to the vault.
     */
    function _withdraw(uint256 _amount) internal override {
        uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBal < _amount) {
            // IMasterChef(MASTER_CHEF).withdrawAndHarvest(mcPoolId, _amount - wantBal, address(this));
        }

        IERC20Upgradeable(want).safeTransfer(vault, _amount);
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     *      1. It claims rewards from the masterChef.
     *      2. It charges the system fees to simplify the split.
     *      3. It swaps {BEEST} and {DEUS} for {want}.
     *      4. It deposits the new {want} tokens into the masterchef.
     */
    function _harvestCore() internal override {
        console.log("----------------------------------------------");
        console.log("_harvestCore()");
        uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        console.log("wantBal before: ", wantBal);
        _claimRewards();
        _performSwapsAndChargeFees();
        _addLiquidity();
        deposit();
        wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        console.log("wantBal after: ", wantBal);
    }

    function _claimRewards() internal {
        // IMasterChef(MASTER_CHEF).harvest(mcPoolId, address(this));
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of WFTM gained from reward
     */
    function _performSwapsAndChargeFees() internal {
        console.log("_performSwapsAndChargeFees()");
        uint256 beetsBal = IERC20Upgradeable(BEETS).balanceOf(address(this));
        uint256 deusBal = IERC20Upgradeable(DEUS).balanceOf(address(this));
        console.log("beetsBal: ", beetsBal);
        console.log("deusBal: ", deusBal);
        IERC20Upgradeable wftm = IERC20Upgradeable(WFTM);
        uint256 startingWftmBal = wftm.balanceOf(address(this));
        uint256 wftmFee = 0;

        _routerSwap(
            DEUS,
            WFTM,
            (IERC20Upgradeable(DEUS).balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR,
            SPOOKY_ROUTER
        );
        wftmFee += wftm.balanceOf(address(this)) - startingWftmBal;
        startingWftmBal = wftm.balanceOf(address(this));

        _beethovenSwap(BEETS, WFTM, IERC20Upgradeable(BEETS).balanceOf(address(this)) * totalFee / PERCENT_DIVISOR, WFTM_BEETS_POOL, true);
        wftmFee += wftm.balanceOf(address(this)) - startingWftmBal;

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
     *      Converts reward tokens to want
     */
    function _addLiquidity() internal {
        console.log("_addLiquidity()");
        // DEUS -> DEI -> want
        // _beethovenSwap(
        //     DEUS,
        //     DEI,
        //     IERC20Upgradeable(DEUS).balanceOf(address(this)),
        //     DEI_DEUS_POOL,
        //     true
        // );
        // _beethovenSwap(
        //     DEI,
        //     want,
        //     IERC20Upgradeable(DEI).balanceOf(address(this)),
        //     beetsPoolId,
        //     true
        // );
        // // BEETS -> USDC -> bb-yv-USD -> want
        _beethovenSwap(
            BEETS,
            USDC,
            IERC20Upgradeable(BEETS).balanceOf(address(this)),
            USDC_BEETS_POOL,
            true
        );
        _beethovenSwap(
            USDC,
            BB_YV_USD,
            IERC20Upgradeable(USDC).balanceOf(address(this)),
            BB_YV_USD_POOL,
            true
        );
        _beethovenSwap(
            BB_YV_USD,
            want,
            IERC20Upgradeable(BB_YV_USD).balanceOf(address(this)),
            beetsPoolId,
            false
        );
    }

    /**
     * @dev Core harvest function. Swaps {_amount} of {_from} to {_to} using {_poolId}.
     *      Prior to requesting the swap, allowance is increased iff {_shouldIncreaseAllowance}
     *      is true. This needs to false for the linear pool since they already have max allowance
     *      for {BEET_VAULT}.
     */
    function _beethovenSwap(
        address _from,
        address _to,
        uint256 _amount,
        bytes32 _poolId,
        bool _shouldIncreaseAllowance
    ) internal {
        console.log("_beethovenSwap()");
        console.log("_from: ", _from);
        console.log("_to: ", _to);
        console.log("_amount: ", _amount);

        if (_from == _to || _amount == 0) {
            return;
        }

        
        console.logBytes32(_poolId);

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
     * @dev Core harvest function. Swaps {_amount} of {_from} to {_to} using {_router}.
     */
    function _routerSwap(
        address _from,
        address _to,
        uint256 _amount,
        address _router
    ) internal {
        if (_from == _to || _amount == 0) {
            return;
        }

        IUniswapV2Router02 router = IUniswapV2Router02(_router);
        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;

        if (router.getAmountsOut(_amount, path)[1] != 0) {
            IERC20Upgradeable(_from).safeIncreaseAllowance(_router, _amount);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amount,
                0,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    /**
     * @dev Function to calculate the total {want} held by the strat.
     *      It takes into account both the funds in hand, plus the funds in the MasterChef.
     */
    function balanceOf() public view override returns (uint256) {
        // (uint256 amount, ) = IMasterChef(MASTER_CHEF).userInfo(mcPoolId, address(this));
        // return amount + IERC20Upgradeable(want).balanceOf(address(this));
        return IERC20Upgradeable(want).balanceOf(address(this));
    }

    /**
     * @dev Returns the approx amount of profit from harvesting.
     *      Profit is denominated in WFTM, and takes fees into account.
     */
    function estimateHarvest() external view override returns (uint256 profit, uint256 callFeeToUser) {
        // uint256 pendingReward = IMasterChef(MASTER_CHEF).pendingBeets(mcPoolId, address(this));
        uint256 pendingReward = 0;
        uint256 totalRewards = pendingReward + IERC20Upgradeable(BEETS).balanceOf(address(this));

        if (totalRewards != 0) {
            // use SPOOKY_ROUTER here since IBeetVault doesn't have a view query function
            address[] memory beetsToWftmPath = new address[](2);
            beetsToWftmPath[0] = BEETS;
            beetsToWftmPath[1] = WFTM;
            profit += IUniswapV2Router02(SPOOKY_ROUTER).getAmountsOut(totalRewards, beetsToWftmPath)[1];
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
        // (uint256 poolBal, ) = IMasterChef(MASTER_CHEF).userInfo(mcPoolId, address(this));
        // IMasterChef(MASTER_CHEF).withdrawAndHarvest(mcPoolId, poolBal, address(this));

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
        // IMasterChef(MASTER_CHEF).emergencyWithdraw(mcPoolId, address(this));
    }
}
