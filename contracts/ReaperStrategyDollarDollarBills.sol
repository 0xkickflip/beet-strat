// SPDX-License-Identifier: agpl-3.0

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
 * @dev LP compounding strategy for the Dollar Dollar Bills pool.
 */
contract ReaperStrategyDollarDollarBills is ReaperBaseStrategyv3 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    IBeetVault public constant BEET_VAULT = IBeetVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    /**
     * @dev Tokens Used:
     * {OP} - Reward token for staking LP into gauge.
     * {OP_LINEAR} - OP Linear pool, used as intermediary token to swap {OP} to {USDC}.
     * {USD_STABLE} - USD Composable stable pool.
     * {USDC} - Used to charge fees
     * {USDC_LINEAR} - USDC Linear pool, used as intermediary token to make {USDC}.
     * {want} - LP token for the Beethoven-x pool.
     * {underlyings} - Array of IAsset type to represent the underlying tokens of the pool.
     */
    IERC20Upgradeable public constant BAL = IERC20Upgradeable(0xFE8B128bA8C78aabC59d4c64cEE7fF28e9379921);
    IERC20Upgradeable public constant OP = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    IERC20Upgradeable public constant OATH = IERC20Upgradeable(0x39FdE572a18448F8139b7788099F0a0740f51205);
    IERC20Upgradeable public constant WETH = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable public constant USDC = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable public constant USDC_LINEAR = IERC20Upgradeable(0x20715545C15C76461861Cb0D6ba96929766D05A5);
    IERC20Upgradeable public want;
    IAsset[] public underlyings;

    // pools used to swap tokens
    bytes32 public constant ALL_YOU_NEED_IS_LOVE = 0xd6e5824b54f64ce6f1161210bc17eebffc77e031000100000000000000000006; //BAL to OP
    bytes32 public constant BONDED_OATH_TOKEN = 0xd20f6f1d8a675cdca155cb07b5dc9042c467153f0002000000000000000000bc; //OATH to WETH
    bytes32 public constant HAPPY_ROAD = 0x39965c9dab5448482cf7e002f583c812ceb53046000100000000000000000003; //OP to USDC, WETH to USDC
    bytes32 public constant USDC_LINEAR_POOL = 0x20715545c15c76461861cb0d6ba96929766d05a50000000000000000000000e8 ;

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
    ) public initializer {
        __ReaperBaseStrategy_init(_vault, _treasury, _strategists, _multisigRoles);
        want = _want;
        gauge = _gauge;
        beetsPoolId = IBasePool(address(want)).getPoolId();

        (IERC20Upgradeable[] memory tokens, , ) = BEET_VAULT.getPoolTokens(beetsPoolId);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (address(tokens[i]) == address(USDC_LINEAR)) {
                usdcLinearPosition = i;
            }

            underlyings.push(IAsset(address(tokens[i])));
        }
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
     *      1. Claims {TOKENS} from gauge.
     *      2. Swaps all {TOKENS} and charges fee.
     *      3. Re-deposits.
     */
    function _harvestCore() internal override returns (uint256 callerFee) {
        _claimRewards();
        callerFee = _performSwapsAndChargeFees();
        _addLiquidity();
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
     *      Charges fees based on the amount of {TOKENS} gained from reward.
     */
    function _performSwapsAndChargeFees() internal returns (uint256 callFeeToUser) {
        // BAL to OP using ALL_YOU_NEED_IS_LOVE
        _beethovenSwap(BAL, OP, BAL.balanceOf(address(this)), ALL_YOU_NEED_IS_LOVE);
        // OP to USDC using HAPPY_ROAD
        _beethovenSwap(OP, USDC, OP.balanceOf(address(this)), HAPPY_ROAD);
        // OATH to WETH using BONDED_OATH_TOKEN
        _beethovenSwap(OATH, WETH, OATH.balanceOf(address(this)), BONDED_OATH_TOKEN);
        // WETH to USDC using HAPPY_ROAD
        _beethovenSwap(WETH, USDC, WETH.balanceOf(address(this)), HAPPY_ROAD);

        uint256 usdcFee = USDC.balanceOf(address(this))* totalFee / PERCENT_DIVISOR;
        if (usdcFee != 0) {
            callFeeToUser = (usdcFee * callFee) / PERCENT_DIVISOR;
            uint256 treasuryFeeToVault = (usdcFee * treasuryFee) / PERCENT_DIVISOR;

            USDC.safeTransfer(msg.sender, callFeeToUser);
            USDC.safeTransfer(treasury, treasuryFeeToVault);
        }
    }

    /**
     * @dev Core harvest function.
     *      Converts reward tokens to want
     */
    function _addLiquidity() internal {
        // remaining USDC used to join pool
        uint256 usdcBal = USDC.balanceOf(address(this));
        if (usdcBal != 0) {
            // USDC to USDC_LINEAR using USDC_LINEAR_POOL
            _beethovenSwap(USDC, USDC_LINEAR, USDC.balanceOf(address(this)), USDC_LINEAR_POOL);

            IBaseWeightedPool.JoinKind joinKind = IBaseWeightedPool.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT;
            uint256[] memory amountsIn = new uint256[](underlyings.length);
            amountsIn[usdcLinearPosition] = USDC_LINEAR.balanceOf(address(this));
            uint256 minAmountOut = 1;
            bytes memory userData = abi.encode(joinKind, amountsIn, minAmountOut);

            IBeetVault.JoinPoolRequest memory request;
            request.assets = underlyings;
            request.maxAmountsIn = amountsIn;
            request.userData = userData;
            request.fromInternalBalance = false;

            BEET_VAULT.joinPool(beetsPoolId, address(this), address(this), request);
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
