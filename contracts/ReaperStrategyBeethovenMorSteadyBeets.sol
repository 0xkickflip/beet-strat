// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv2.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IBeetVault.sol";
import "./interfaces/IDeusRewarder.sol";
import "./interfaces/ILinearPool.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IBaseWeightedPool.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "hardhat/console.sol";

/**
 * @dev LP compounding strategy for the Mor Steady Beets, Yearn Boosted Beethoven-X pool.
 */
contract ReaperStrategyBeethovenMorSteadyBeets is ReaperBaseStrategyv2 {
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
     * {want} - LP token for the Beethoven-x pool.
     */
    address public constant WFTM = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public constant USDC = address(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    address public constant BEETS = address(0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e);
    address public constant BB_YV_USDC = address(0x3B998BA87b11a1c5BC1770dE9793B17A0dA61561);
    address public constant BB_YV_USD = address(0x5ddb92A5340FD0eaD3987D3661AfcD6104c3b757);
    address public want;
    IAsset[] underlyings;

    // pools used to swap tokens
    bytes32 public constant WFTM_BEETS_POOL = 0xcde5a11a4acb4ee4c805352cec57e236bdbc3837000200000000000000000019;
    bytes32 public constant USDC_BEETS_POOL = 0x03c6b3f09d2504606936b1a4decefad204687890000200000000000000000015;
    bytes32 public constant BB_YV_USDC_POOL = 0x3b998ba87b11a1c5bc1770de9793b17a0da61561000000000000000000000185;
    bytes32 public constant BB_YV_USD_POOL = 0x5ddb92a5340fd0ead3987d3661afcd6104c3b757000000000000000000000187;

    /**
     * @dev Strategy variables
     * {mcPoolId} - ID of MasterChef pool in which to deposit LP tokens
     * {beetsPoolId} - bytes32 ID of the Beethoven-X pool corresponding to {want}
     */
    uint256 public mcPoolId;
    bytes32 public beetsPoolId;
    uint256 public minBeetsToSwap;

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
        minBeetsToSwap = 100000000000000;
        beetsPoolId = IBasePool(want).getPoolId();

        (IERC20Upgradeable[] memory tokens, , ) = IBeetVault(BEET_VAULT).getPoolTokens(beetsPoolId);
        for (uint256 i = 0; i < tokens.length; i++) {
            underlyings.push(IAsset(address(tokens[i])));
        }
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
     *      1. It claims rewards from the masterChef.
     *      2. It charges the system fees to simplify the split.
     *      3. It swaps {BEEST} and {DEUS} for {want}.
     *      4. It deposits the new {want} tokens into the masterchef.
     */
    function _harvestCore() internal override {
        // _claimRewards();
        _performSwapsAndChargeFees();
        _addLiquidity();
        deposit();
    }

    function _claimRewards() internal {
        IMasterChef(MASTER_CHEF).harvest(mcPoolId, address(this));
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of WFTM gained from reward
     */
    function _performSwapsAndChargeFees() internal {
        IERC20Upgradeable wftm = IERC20Upgradeable(WFTM);
        uint256 startingWftmBal = wftm.balanceOf(address(this));
        uint256 wftmFee = 0;
        uint256 beetsBalance = IERC20Upgradeable(BEETS).balanceOf(address(this));

        if (beetsBalance >= minBeetsToSwap) {
            _beethovenSwap(
                BEETS,
                WFTM,
                (IERC20Upgradeable(BEETS).balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR,
                WFTM_BEETS_POOL,
                true
            );
        }

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
        uint256 beetsBalance = IERC20Upgradeable(BEETS).balanceOf(address(this));
        if (beetsBalance >= minBeetsToSwap) {
            _beethovenSwap(BEETS, USDC, IERC20Upgradeable(BEETS).balanceOf(address(this)), USDC_BEETS_POOL, true);
            console.log(IERC20Upgradeable(USDC).balanceOf(address(this)));
        }
        _beethovenSwap(USDC, BB_YV_USDC, IERC20Upgradeable(USDC).balanceOf(address(this)), BB_YV_USDC_POOL, true);
        _beethovenSwap(
            BB_YV_USDC,
            BB_YV_USD,
            IERC20Upgradeable(BB_YV_USDC).balanceOf(address(this)),
            BB_YV_USD_POOL,
            false
        );
        _beethovenSwap(BB_YV_USD, want, IERC20Upgradeable(BB_YV_USD).balanceOf(address(this)), beetsPoolId, false);
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

        // {BEETS} reward
        uint256 pendingReward = masterChef.pendingBeets(mcPoolId, address(this));
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
     * Withdraws all funds leaving rewards behind.
     */
    function _reclaimWant() internal override {
        IMasterChef(MASTER_CHEF).emergencyWithdraw(mcPoolId, address(this));
    }

    /**
     * Sets the minimum {BEETS} reward to swap
     */
    function _setMinBeetsToSwap(uint256 _minBeetsToSwap) external {
        _onlyStrategistOrOwner();
        minBeetsToSwap = _minBeetsToSwap;
    }
}
