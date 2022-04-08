// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv2.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IBeetVault.sol";
import "./interfaces/ILinearPool.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IBaseV1Router01.sol";
import "./interfaces/ITimeBasedMasterChefMultiTokenRewarder.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "hardhat/console.sol";

/**
 * @dev LP compounding strategy for the Beethoven-X 4Pool that uses yearn-boosted linear pools as underlying
 *      "tokens".
 */
contract ReaperStrategyBeethoven4Pool is ReaperBaseStrategyv2 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    address public constant BEET_VAULT = address(0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce);
    address public constant MASTER_CHEF = address(0x8166994d9ebBe5829EC86Bd81258149B87faCfd3);
    address public constant SPOOKY_ROUTER = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    address public constant SPIRIT_ROUTER = address(0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52);
    address public constant SOLIDLY_ROUTER = 0xa38cd27185a464914D3046f0AB9d43356B34829D;

    /**
     * @dev Tokens Used:
     * {WFTM} - Required for charging fees. May also be used to join pool if there's {WFTM} underlying.
     * {USDC} - Used to join pool.
     * {UST} - Reward, also used to join pool.
     * {BEETS} - Reward token for depositing LP into MasterChef.
     * {FXS} - Reward, converted into FRAX to join the pool
     * {FRAX} - Used to join pool
     * {want} - LP token for the Beethoven-x pool.
     * {underlyingToLinear} - Map of underlying token to linear pool, example {USDC} -> {bb-yv-USDC}
     */
    address public constant WFTM = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public constant USDC = address(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    address public constant UST = address(0x846e4D51d7E2043C1a87E0Ab7490B93FB940357b);
    address public constant BEETS = address(0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e);
    address public constant FXS = address(0x7d016eec9c25232b01F23EF992D98ca97fc2AF5a);
    address public constant FRAX = address(0xdc301622e621166BD8E82f2cA0A26c13Ad0BE355);
    address public want;
    mapping(address => address) public underlyingToLinear;

    // pools used to swap tokens
    bytes32 public constant WFTM_BEETS_POOL = 0xcde5a11a4acb4ee4c805352cec57e236bdbc3837000200000000000000000019;
    bytes32 public constant USDC_BEETS_POOL = 0x03c6b3f09d2504606936b1a4decefad204687890000200000000000000000015;
    bytes32 public constant WFTM_USDC_POOL = 0xcdf68a4d525ba2e90fe959c74330430a5a6b8226000200000000000000000008;
    bytes32 public constant WFTM_UST_POOL = 0x2fbb1ef03c02f9bb2bd6f8c8c24f8de347979d9e00010000000000000000039a;

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

        (IERC20Upgradeable[] memory tokens, , ) = IBeetVault(BEET_VAULT).getPoolTokens(beetsPoolId);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (address(tokens[i]) == _want || address(tokens[i]) == UST) {
                continue;
            }

            address underlying = ILinearPool(address(tokens[i])).getMainToken();
            underlyingToLinear[underlying] = address(tokens[i]);
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
     *      2. Swaps rewards into WFTM (for fees) and the underlying stablecoins (USDC, FRAX)
     *      3. Charges fees from the WFTM balance
     *      4. It swaps the underlying stablecoins in to the want tokens
     *      4. It deposits the new {want} tokens into the masterchef.
     */
    function _harvestCore() internal override {
        _claimRewards();
        _swapRewards();
        _chargeFees();
        _addLiquidity();
        deposit();
    }

    function _claimRewards() internal {
        IMasterChef(MASTER_CHEF).harvest(mcPoolId, address(this));
    }

    function _swapRewards() internal {
        _swapFXS();
        _swapUST();
        _swapBEETS();
    }

    function _swapFXS() internal {
        uint256 fxsBalance = IERC20Upgradeable(FXS).balanceOf(address(this));
        address fxsRouter =  _findBestRouterForSwap(FXS, FRAX, fxsBalance);
        _swap(FXS, FRAX, fxsBalance, fxsRouter);
        uint256 fraxFee = IERC20Upgradeable(FRAX).balanceOf(address(this)) * totalFee / PERCENT_DIVISOR;
        _swap(FRAX, WFTM, fraxFee, SPIRIT_ROUTER);
    }

    function _swapUST() internal {
        uint256 ustFee = IERC20Upgradeable(UST).balanceOf(address(this)) * totalFee / PERCENT_DIVISOR;
        _swapBeetx(UST, WFTM, ustFee, WFTM_UST_POOL, true);
    }

    function _swapBEETS() internal {
        uint256 beetsFee = IERC20Upgradeable(BEETS).balanceOf(address(this)) * totalFee / PERCENT_DIVISOR;
        _swapBeetx(BEETS, WFTM, beetsFee, WFTM_BEETS_POOL, true);
        uint256 beetsBalance = IERC20Upgradeable(BEETS).balanceOf(address(this));
        _swapBeetx(BEETS, USDC, beetsBalance, USDC_BEETS_POOL, true);
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of WFTM gained from reward
     */
    function _chargeFees() internal {
        IERC20Upgradeable wftm = IERC20Upgradeable(WFTM);
        uint256 wftmFee = wftm.balanceOf(address(this));

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
     *      Swaps underlying stablecoins in to the want token
     */
    function _addLiquidity() internal {
        _linearPoolSwap(FRAX);
        _linearPoolSwap(USDC);
        _swapBeetx(
            UST,
            want,
            IERC20Upgradeable(UST).balanceOf(address(this)),
            beetsPoolId,
            true
        );
    }

    /**
     * @dev Core harvest function.
     *      Converts {_underlying} token (one of {USDC}, {FRAX} or {fUSDT}) to {want} using
     *      two swaps involving linear pools.
     */
    function _linearPoolSwap(address _underlying) internal {
        _swapBeetx(
            _underlying,
            underlyingToLinear[_underlying],
            IERC20Upgradeable(_underlying).balanceOf(address(this)),
            ILinearPool(underlyingToLinear[_underlying]).getPoolId(),
            true
        );
        _swapBeetx(
            underlyingToLinear[_underlying],
            want,
            IERC20Upgradeable(underlyingToLinear[_underlying]).balanceOf(address(this)),
            beetsPoolId,
            false
        );
    }

    function _swap(
        address _from,
        address _to,
        uint256 _amount,
        address routerAddress
    ) internal {
        if (_amount != 0) {
            IERC20Upgradeable(_from).safeIncreaseAllowance(routerAddress, _amount);
            if (routerAddress == SOLIDLY_ROUTER) {
                IBaseV1Router01 router = IBaseV1Router01(routerAddress);
                router.swapExactTokensForTokensSimple(_amount, 0, _from, _to, false, address(this), block.timestamp);
            } else {
                IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
                address[] memory path = new address[](2);
                path[0] = _from;
                path[1] = _to;
                
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    _amount,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
            }
        }
    }

    /** @dev Returns address of router that would return optimum output for _from->_to swap. */
    function _findBestRouterForSwap(
        address _from,
        address _to,
        uint256 _amount
    ) internal view returns (address) {
        (uint256 fromSolid, ) = IBaseV1Router01(SOLIDLY_ROUTER).getAmountOut(_amount, _from, _to);

        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;
        uint256 fromSpooky = IUniswapV2Router02(SPIRIT_ROUTER).getAmountsOut(_amount, path)[1];

        return fromSolid > fromSpooky ? SOLIDLY_ROUTER : SPIRIT_ROUTER;
    }

    /**
     * @dev Core harvest function. Swaps {_amount} of {_from} to {_to} using {_poolId}.
     *      Prior to requesting the swap, allowance is increased iff {_shouldIncreaseAllowance}
     *      is true. This needs to false for the linear pool since they already have max allowance
     *      for {BEET_VAULT}.
     */
    function _swapBeetx(
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
        ITimeBasedMasterChefMultiTokenRewarder rewarder = ITimeBasedMasterChefMultiTokenRewarder(masterChef.rewarder(mcPoolId));

        uint256 pendingReward = IMasterChef(MASTER_CHEF).pendingBeets(mcPoolId, address(this));
        uint256 totalRewards = pendingReward + IERC20Upgradeable(BEETS).balanceOf(address(this));

        if (totalRewards != 0) {
            // use SPOOKY_ROUTER here since IBeetVault doesn't have a view query function
            address[] memory beetsToWftmPath = new address[](2);
            beetsToWftmPath[0] = BEETS;
            beetsToWftmPath[1] = WFTM;
            profit += IUniswapV2Router02(SPOOKY_ROUTER).getAmountsOut(totalRewards, beetsToWftmPath)[1];
        }

        (, uint256[] memory rewardAmounts) = rewarder.pendingTokens(mcPoolId, address(this), 0);
        uint256 fxsAmount = rewardAmounts[0];
        uint256 ustAmount = rewardAmounts[1];

        if (fxsAmount != 0) {
            address[] memory fxsToWftmPath = new address[](3);
            fxsToWftmPath[0] = FXS;
            fxsToWftmPath[1] = FRAX;
            fxsToWftmPath[2] = WFTM;
            profit += IUniswapV2Router02(SPIRIT_ROUTER).getAmountsOut(fxsAmount, fxsToWftmPath)[1];
        }

        if (ustAmount != 0) {
            address[] memory ustToWftmPath = new address[](2);
            ustToWftmPath[0] = UST;
            ustToWftmPath[1] = WFTM;
            profit += IUniswapV2Router02(SPIRIT_ROUTER).getAmountsOut(ustAmount, ustToWftmPath)[1];
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

        _swapRewards();
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
