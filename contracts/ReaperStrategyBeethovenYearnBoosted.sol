// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv2.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IBeetVault.sol";
import "./interfaces/ILinearPool.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @dev LP compounding strategy for Beethoven-X pools that use yearn-boosted linear pools as underlying
 *      "tokens".
 */
contract ReaperStrategyBeethovenYearnBoosted is ReaperBaseStrategyv2 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    address public constant BEET_VAULT = address(0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce);
    address public constant MASTER_CHEF = address(0x8166994d9ebBe5829EC86Bd81258149B87faCfd3);
    address public constant SPOOKY_ROUTER = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    /**
     * @dev Tokens Used:
     * {WFTM} - Required for charging fees. May also be used to join pool if there's {WFTM} underlying.
     * {USDC} - May be used to join pool if there's {USDC} underlying.
     * {BEETS} - Reward token for depositing LP into MasterChef. May also be used to join pool if there's {BEETS} underlying.
     * {want} - LP token for the Beethoven-x pool.
     * {underlyingToLinear} - Map of underlying token to linear pool, example {USDC} -> {bb-yv-USDC}
     */
    address public constant WFTM = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public constant USDC = address(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    address public constant BEETS = address(0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e);
    address public want;
    mapping(address => address) public underlyingToLinear;

    // pools used to swap tokens
    bytes32 public constant WFTM_BEETS_POOL = 0xcde5a11a4acb4ee4c805352cec57e236bdbc3837000200000000000000000019;
    bytes32 public constant USDC_BEETS_POOL = 0x03c6b3f09d2504606936b1a4decefad204687890000200000000000000000015;
    bytes32 public constant WFTM_USDC_POOL = 0xcdf68a4d525ba2e90fe959c74330430a5a6b8226000200000000000000000008;

    /**
     * @dev Strategy variables
     * {mcPoolId} - ID of MasterChef pool in which to deposit LP tokens
     * {beetsPoolId} - bytes32 ID of the Beethoven-X pool corresponding to {want}
     * {beetsUnderlying} - Whether {BEETS} is an underlying token for one of the linear pools.
     * {wftmUnderlying} - Whether {WFTM} is an underlying token for one of the linear pools.
     * {usdcUnderlying} - Whether {USDC} is an underlying token for one of the linear pools.
     */
    uint256 public mcPoolId;
    bytes32 public beetsPoolId;
    bool public beetsUnderlying;
    bool public wftmUnderlying;
    bool public usdcUnderlying;

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

        beetsUnderlying = false;
        wftmUnderlying = false;
        usdcUnderlying = false;

        (IERC20Upgradeable[] memory tokens, , ) = IBeetVault(BEET_VAULT).getPoolTokens(beetsPoolId);
        for (uint256 i = 0; i < tokens.length; i++) {
            // skip {want} since that's also registered as a pool token
            if (address(tokens[i]) == _want) {
                continue;
            }

            address underlying = ILinearPool(address(tokens[i])).getMainToken();
            underlyingToLinear[underlying] = address(tokens[i]);

            if (underlying == WFTM) {
                wftmUnderlying = true;
            } else if (underlying == USDC) {
                usdcUnderlying = true;
            } else if (underlying == BEETS) {
                beetsUnderlying = true;
            }
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
     *      3. It swaps {BEEST} for {want}.
     *      4. It deposits the new {want} tokens into the masterchef.
     */
    function _harvestCore() internal override {
        IMasterChef(MASTER_CHEF).harvest(mcPoolId, address(this));
        _chargeFees();

        if (beetsUnderlying) {
            _addLiquidity(BEETS);
        } else if (wftmUnderlying) {
            _addLiquidity(WFTM);
        } else if (usdcUnderlying) {
            _swap(BEETS, USDC, IERC20Upgradeable(BEETS).balanceOf(address(this)), USDC_BEETS_POOL, true);
            _addLiquidity(USDC);
        }

        deposit();
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of WFTM gained from reward
     */
    function _chargeFees() internal {
        IERC20Upgradeable wftm = IERC20Upgradeable(WFTM);
        uint256 wftmFee = 0;

        if (wftmUnderlying) {
            _swap(BEETS, WFTM, IERC20Upgradeable(BEETS).balanceOf(address(this)), WFTM_BEETS_POOL, true);
            wftmFee = (wftm.balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR;
        } else {
            _swap(
                BEETS,
                WFTM,
                (IERC20Upgradeable(BEETS).balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR,
                WFTM_BEETS_POOL,
                true
            );
            wftmFee = wftm.balanceOf(address(this));
        }

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
     *      Converts {_underlying} token (one of {BEETS}, {WFTM} or {USDC}) to {want} using
     *      two swaps involving linear pools.
     */
    function _addLiquidity(address _underlying) internal {
        _swap(
            _underlying,
            underlyingToLinear[_underlying],
            IERC20Upgradeable(_underlying).balanceOf(address(this)),
            ILinearPool(underlyingToLinear[_underlying]).getPoolId(),
            true
        );
        _swap(
            underlyingToLinear[_underlying],
            want,
            IERC20Upgradeable(underlyingToLinear[_underlying]).balanceOf(address(this)),
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
        uint256 pendingReward = IMasterChef(MASTER_CHEF).pendingBeets(mcPoolId, address(this));
        uint256 totalRewards = pendingReward + IERC20Upgradeable(BEETS).balanceOf(address(this));

        if (totalRewards != 0) {
            // use SPOOKY_ROUTER here since IBeetVault doesn't have a view query function
            address[] memory beetsToWftmPath = new address[](2);
            beetsToWftmPath[0] = BEETS;
            beetsToWftmPath[1] = WFTM;
            profit += IUniswapV2Router01(SPOOKY_ROUTER).getAmountsOut(totalRewards, beetsToWftmPath)[1];
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

        if (beetsUnderlying) {
            _addLiquidity(BEETS);
        } else if (wftmUnderlying) {
            _swap(BEETS, WFTM, IERC20Upgradeable(BEETS).balanceOf(address(this)), WFTM_BEETS_POOL, true);
            _addLiquidity(WFTM);
        } else if (usdcUnderlying) {
            _swap(BEETS, USDC, IERC20Upgradeable(BEETS).balanceOf(address(this)), USDC_BEETS_POOL, true);
            _addLiquidity(USDC);
        }

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
