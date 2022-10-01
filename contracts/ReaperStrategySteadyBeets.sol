// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv3.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IBaseWeightedPool.sol";
import "./interfaces/IBeetVault.sol";
import "./interfaces/IRewardsOnlyGauge.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @dev LP compounding strategy for the Steady Beets, Boosted pool.
 */
contract ReaperStrategySteadyBeets is ReaperBaseStrategyv3 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    IBeetVault public constant BEET_VAULT = IBeetVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    /**
     * @dev Tokens Used:
     * {OP} - Reward token for staking LP into gauge.
     * {OP_LINEAR} - OP Linear pool, used as intermediary token to swap {OP} to {USDC}.
     * {USD_STABLE} - USD Composable stable pool, also happens to be want.
     * {USDC} - Underlying token of the want LP used to swap in to the want. Also used to charge fees
     * {USDC_LINEAR} - USDC Linear pool, used as intermediary token to make more want.
     * {want} - LP token for the Beethoven-x pool.
     */
    IERC20Upgradeable public constant OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IERC20Upgradeable public constant OP_LINEAR = IERC20Upgradeable(0xA4e597c1bD01859B393b124ce18427Aa4426A871);
    IERC20Upgradeable public constant USD_STABLE = IERC20Upgradeable(0x6222ae1d2a9f6894dA50aA25Cb7b303497f9BEbd);
    IERC20Upgradeable public constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable public constant USDC_LINEAR = IERC20Upgradeable(0xba7834bb3cd2DB888E6A06Fb45E82b4225Cd0C71);
    IERC20Upgradeable public want;

    // pools used to swap tokens
    bytes32 public constant OP_LINEAR_POOL = 0xa4e597c1bd01859b393b124ce18427aa4426a87100000000000000000000004c;
    bytes32 public constant HAPPY_ROAD_RELOADED = 0xb0de49429fbb80c635432bbad0b3965b2856017700010000000000000000004e;
    bytes32 public constant USDC_LINEAR_POOL = 0xba7834bb3cd2db888e6a06fb45e82b4225cd0c71000000000000000000000043;

    /**
     * @dev Strategy variables
     * {gauge} - address of gauge in which LP tokens are staked
     * {beetsPoolId} - bytes32 ID of the Beethoven-X pool corresponding to {want}
     */
    IRewardsOnlyGauge public gauge;
    bytes32 public beetsPoolId;

    /**
     * @dev Initializes the strategy. Sets parameters and saves routes.
     * @notice see documentation for each variable above its respective declaration.
     */
    function initialize(
        address _vault,
        address _treasury,
        address[] memory _strategists,
        address[] memory _multisigRoles,
        IERC20Upgradeable _want,
        IRewardsOnlyGauge _gauge
    ) public initializer {
        __ReaperBaseStrategy_init(_vault, _treasury, _strategists, _multisigRoles);
        want = _want;
        gauge = _gauge;
        beetsPoolId = IBasePool(address(want)).getPoolId();
    }

    /**
     * @dev Function that puts the funds to work.
     *      It gets called whenever someone deposits in the strategy's vault contract.
     */
    function _deposit() internal override {
        uint256 wantBalance = want.balanceOf(address(this));
        if (wantBalance != 0) {
            want.safeIncreaseAllowance(address(gauge), wantBalance);
            gauge.deposit(wantBalance);
        }
    }

    /**
     * @dev Withdraws funds and sends them back to the vault.
     */
    function _withdraw(uint256 _amount) internal override {
        uint256 wantBal = want.balanceOf(address(this));
        if (wantBal < _amount) {
            gauge.withdraw(_amount - wantBal);
        }

        want.safeTransfer(vault, _amount);
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     *      1. Claims {OP} from gauge.
     *      2. Swaps all {OP} and charges fee.
     *      3. Re-deposits.
     */
    function _harvestCore() internal override returns (uint256 callerFee) {
        _claimRewards();
        callerFee = _performSwapsAndChargeFees();
        deposit();
    }

    /**
     * @dev Core harvest function.
     *      Claims rewards from gauge.
     */
    function _claimRewards() internal {
        gauge.claim_rewards(address(this));
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of {OP} gained from reward.
     */
    function _performSwapsAndChargeFees() internal returns (uint256 callFeeToUser) {
        // OP -> OP_LINEAR using OP_LINEAR_POOL
        _beethovenSwap(OP, OP_LINEAR, OP.balanceOf(address(this)), OP_LINEAR_POOL);

        uint256 wantBalance = want.balanceOf(address(this));
        // OP_LINEAR -> USD_STABLE using HAPPY_ROAD_RELOADED
        _beethovenSwap(OP_LINEAR, USD_STABLE, OP_LINEAR.balanceOf(address(this)), HAPPY_ROAD_RELOADED);
        uint256 usdStableGenerated = USD_STABLE.balanceOf(address(this)) - wantBalance;

        // convert totalFee% of usdStableGenerated to USDC for fee. Leave rest as want to re-deposit.
        uint256 usdStableFee = (usdStableGenerated * totalFee) / PERCENT_DIVISOR;
        if (usdStableFee != 0) {
            // USD_STABLE -> USDC_LINEAR using beetsPoolId
            _beethovenSwap(USD_STABLE, USDC_LINEAR, usdStableFee, beetsPoolId);

            // USDC_LINEAR -> USDC using USDC_LINEAR_POOL
            _beethovenSwap(USDC_LINEAR, USDC, USDC_LINEAR.balanceOf(address(this)), USDC_LINEAR_POOL);

            uint256 usdcFee = USDC.balanceOf(address(this));
            if (usdcFee != 0) {
                callFeeToUser = (usdcFee * callFee) / PERCENT_DIVISOR;
                uint256 treasuryFeeToVault = (usdcFee * treasuryFee) / PERCENT_DIVISOR;

                USDC.safeTransfer(msg.sender, callFeeToUser);
                USDC.safeTransfer(treasury, treasuryFeeToVault);
            }
        }
    }

    /**
     * @dev Core harvest function. Swaps {_amount} of {_from} to {_to} using {_poolId}.
     *      Prior to requesting the swap, allowance is increased if necessary.
     */
    function _beethovenSwap(
        IERC20Upgradeable _from,
        IERC20Upgradeable _to,
        uint256 _amount,
        bytes32 _poolId
    ) internal {
        if (_from == _to || _amount == 0) {
            return;
        }

        IBeetVault.SingleSwap memory singleSwap;
        singleSwap.poolId = _poolId;
        singleSwap.kind = IBeetVault.SwapKind.GIVEN_IN;
        singleSwap.assetIn = IAsset(address(_from));
        singleSwap.assetOut = IAsset(address(_to));
        singleSwap.amount = _amount;
        singleSwap.userData = abi.encode(0);

        IBeetVault.FundManagement memory funds;
        funds.sender = address(this);
        funds.fromInternalBalance = false;
        funds.recipient = payable(address(this));
        funds.toInternalBalance = false;

        uint256 currentAllowance = _from.allowance(address(this), address(BEET_VAULT));
        if (_amount > currentAllowance) {
            _from.safeIncreaseAllowance(address(BEET_VAULT), _amount - currentAllowance);
        }
        BEET_VAULT.swap(singleSwap, funds, 1, block.timestamp);
    }

    /**
     * @dev Function to calculate the total {want} held by the strat.
     *      It takes into account both the funds in hand, plus the funds in the MasterChef.
     */
    function balanceOf() public view override returns (uint256) {
        return want.balanceOf(address(this)) + gauge.balanceOf(address(this));
    }

    /**
     * Withdraws all funds leaving rewards behind.
     */
    function _reclaimWant() internal override {
        gauge.withdraw(gauge.balanceOf(address(this)));
    }
}
