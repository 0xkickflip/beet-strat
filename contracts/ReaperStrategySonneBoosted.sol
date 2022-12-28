// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv3.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IBaseWeightedPool.sol";
import "./interfaces/IBeetVault.sol";
import "./interfaces/IRewardsOnlyGauge.sol";
import "./interfaces/IVeloRouter.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @dev LP compounding strategy for the Happy Road Reloaded pool.
 */
contract ReaperStrategySonneBoosted is ReaperBaseStrategyv3 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    IBeetVault public constant BEET_VAULT = IBeetVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address public constant VELODROME_ROUTER = address(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);

    /**
     * @dev Tokens Used:
     * {OP} - Reward token for staking LP into gauge.
     * {USD_STABLE} - USD Composable stable pool.
     * {USDC} - Used to charge fees
     * {USDC_LINEAR} - USDC Linear pool, used as intermediary token to make {USDC}.
     * {want} - LP token for the Beethoven-x pool.
     * {underlyings} - Array of IAsset type to represent the underlying tokens of the pool.
     */
    IERC20Upgradeable public constant OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IERC20Upgradeable public constant SONNE = IERC20Upgradeable(0x1DB2466d9F5e10D7090E7152B68d62703a2245F0);
    IERC20Upgradeable public constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable public constant USDC_LINEAR = IERC20Upgradeable(0xEdcfaF390906a8f91fb35B7bAC23f3111dBaEe1C);
    IERC20Upgradeable public want;
    IAsset[] public underlyings;

    // pools used to swap tokens
    bytes32 public constant USDC_LINEAR_POOL = 0xedcfaf390906a8f91fb35b7bac23f3111dbaee1c00000000000000000000007c;

    /**
     * @dev Strategy variables
     * {gauge} - address of gauge in which LP tokens are staked
     * {beetsPoolId} - bytes32 ID of the Beethoven-X pool corresponding to {want}
     * {usdcLinearPosition} - Index of {USDC_LINEAR} in the main pool.
     */
    IRewardsOnlyGauge public gauge;
    bytes32 public beetsPoolId;
    uint256 public usdcLinearPosition;

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
    )
        public
        initializer
    {
        __ReaperBaseStrategy_init(_vault, _treasury, _strategists, _multisigRoles);
        want = _want;
        gauge = _gauge;
        beetsPoolId = IBasePool(address(want)).getPoolId();

        (IERC20Upgradeable[] memory tokens,,) = BEET_VAULT.getPoolTokens(beetsPoolId);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (address(tokens[i]) == address(USDC_LINEAR)) {
                usdcLinearPosition = i;
            }

            underlyings.push(IAsset(address(tokens[i])));
        }
    }

    /**
     * @dev Function that puts the funds to work.
     * It gets called whenever someone deposits in the strategy's vault contract.
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
     * 1. Claims {OP} from gauge.
     * 2. Swaps all {OP} and charges fee.
     * 3. Re-deposits.
     */
    function _harvestCore() internal override returns (uint256 callerFee) {
        _claimRewards();
        callerFee = _performSwapsAndChargeFees();
        deposit();
    }

    /**
     * @dev Core harvest function.
     * Claims rewards from gauge.
     */
    function _claimRewards() internal {
        gauge.claim_rewards(address(this));
    }

    /**
     * @dev Core harvest function.
     * Charges fees based on the amount of {OP} gained from reward.
     */
    function _performSwapsAndChargeFees() internal returns (uint256 callFeeToUser) {
        // OP and SONNE -> USDC using velo
        _swap(address(OP), address(USDC), OP.balanceOf(address(this)));
        _swap(address(SONNE), address(USDC), SONNE.balanceOf(address(this)));

        uint256 totalFee = (USDC.balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR;
        uint256 amountAfterFees = USDC.balanceOf(address(this)) - totalFee;
        // convert amountAfterFees of USDC to USD_LINEAR
        _beethovenSwap(USDC, USDC_LINEAR, amountAfterFees, USDC_LINEAR_POOL);

        uint256 usdcLinBal = USDC_LINEAR.balanceOf(address(this));

        _beethovenSwap(USDC_LINEAR, want, usdcLinBal, beetsPoolId);

        uint256 usdcFee = USDC.balanceOf(address(this));
        if (usdcFee != 0) {
            callFeeToUser = (usdcFee * callFee) / PERCENT_DIVISOR;
            uint256 treasuryFeeToVault = (usdcFee * treasuryFee) / PERCENT_DIVISOR;

            USDC.safeTransfer(msg.sender, callFeeToUser);
            USDC.safeTransfer(treasury, treasuryFeeToVault);
        }
    }

    /// @dev Helper function to swap {_from} to {_to} given an {_amount}. ONLY VOL
    function _swap(address _from, address _to, uint256 _amount) internal {
        if (_from == _to || _amount == 0) {
            return;
        }

        IERC20Upgradeable(_from).safeIncreaseAllowance(VELODROME_ROUTER, _amount);
        IVeloRouter router = IVeloRouter(VELODROME_ROUTER);

        IVeloRouter.route[] memory routes = new IVeloRouter.route[](1);
        routes[0] = IVeloRouter.route({from: _from, to: _to, stable: false});
        router.swapExactTokensForTokens(_amount, 0, routes, address(this), block.timestamp);
    }

    /**
     * @dev Core harvest function. Swaps {_amount} of {_from} to {_to} using {_poolId}.
     * Prior to requesting the swap, allowance is increased if necessary.
     */
    function _beethovenSwap(IERC20Upgradeable _from, IERC20Upgradeable _to, uint256 _amount, bytes32 _poolId)
        internal
    {
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
     * It takes into account both the funds in hand, plus the funds in the MasterChef.
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
