// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv3.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IBaseWeightedPool.sol";
import "./interfaces/IBeetVault.sol";
import "./interfaces/IMasterChef.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @dev LP compounding strategy for the Happy Road Reloaded pool.
 */
contract ReaperStrategyHappyRoadReloaded is ReaperBaseStrategyv3 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    IBeetVault public constant BEET_VAULT = IBeetVault(0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce);
   
    /**
     * @dev Tokens Used:
     * {WFTM} - Pool token.
     * {axlBTC} - Pool token.
     * {ERN} - Pool token.
     * {axlETH} - Pool token.
     * {BEETS} - Emissions token.
     * {OATH} - Emissions token.
     * {axlUSDC} - Emissions token.
     * {want} - LP token for the Beethoven-x pool.
     * {underlyings} - Array of IAsset type to represent the underlying tokens of the pool.
     */
    IERC20Upgradeable public constant WFTM = IERC20Upgradeable(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    IERC20Upgradeable public constant axlBTC = IERC20Upgradeable(0x448d59B4302aB5d2dadf9611bED9457491926c8e);
    IERC20Upgradeable public constant ERN = IERC20Upgradeable(0xce1E3cc1950D2aAEb47dE04DE2dec2Dc86380E0A);
    IERC20Upgradeable public constant axlETH = IERC20Upgradeable(0xfe7eDa5F2c56160d406869A8aA4B2F365d544C7B);
    IERC20Upgradeable public constant BEETS = IERC20Upgradeable(0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e);
    IERC20Upgradeable public constant OATH = IERC20Upgradeable(0x21Ada0D2aC28C3A5Fa3cD2eE30882dA8812279B6);
    IERC20Upgradeable public constant axlUSDC = IERC20Upgradeable(0x1B6382DBDEa11d97f24495C9A90b7c88469134a4);
    IERC20Upgradeable public want;
    IAsset[] public underlyings;

    // pools used to swap tokens
    bytes32 public constant BEET_MASONS_OATH = 0x644dd9c08e1848cae0ddf892686a642acefc9ccf0002000000000000000002d0;
    bytes32 public constant FRESH_BEETS = 0x9e4341acef4147196e99d648c5e43b3fc9d026780002000000000000000005ec;
    bytes32 public constant A_STABLE_CHORD = 0x4e87cc8043ef97a21282e72ab172722634fc2127000000000000000000000766;
    address public constant MASTER_CHEF = address(0x8166994d9ebBe5829EC86Bd81258149B87faCfd3);

    /**
     * @dev Strategy variables
     * {gauge} - address of gauge in which LP tokens are staked
     * {beetsPoolId} - bytes32 ID of the Beethoven-X pool corresponding to {want}
     * {opLinearPosition} - Index of {OP_LINEAR} in the main pool.
     */
    bytes32 public beetsPoolId;
    uint256 public wftmPosition;
    uint256 public mcPoolId;

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
        uint256 _mcPoolId
    ) public initializer {
        __ReaperBaseStrategy_init(_vault, _treasury, _strategists, _multisigRoles);
        want = _want;
        mcPoolId = _mcPoolId;
        beetsPoolId = IBasePool(address(want)).getPoolId();

        (IERC20Upgradeable[] memory tokens, , ) = BEET_VAULT.getPoolTokens(beetsPoolId);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (address(tokens[i]) == address(WFTM)) {
                wftmPosition = i;
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
            want.safeIncreaseAllowance(MASTER_CHEF, wantBalance);
            IMasterChef(MASTER_CHEF).deposit(mcPoolId, wantBalance, address(this));        }
    }

    /**
     * @dev Withdraws funds and sends them back to the vault.
     */
    function _withdraw(uint256 _amount) internal override {
        uint256 wantBal = want.balanceOf(address(this));
        if (wantBal < _amount) {
            IMasterChef(MASTER_CHEF).withdrawAndHarvest(mcPoolId, _amount - wantBal, address(this));
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
        IMasterChef(MASTER_CHEF).harvest(mcPoolId, address(this));
        callerFee = _performSwapsAndChargeFees();
        _addLiquidity();
        deposit();
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of {OP} gained from reward.
     */
    function _performSwapsAndChargeFees() internal returns (uint256 callFeeToUser) {
        // OP -> OP_LINEAR using OP_LINEAR_POOL
        _beethovenSwap(BEETS, WFTM, BEETS.balanceOf(address(this)), FRESH_BEETS);
        _beethovenSwap(OATH, WFTM, OATH.balanceOf(address(this)), BEET_MASONS_OATH);
        _beethovenSwap(axlUSDC, ERN, axlUSDC.balanceOf(address(this)), A_STABLE_CHORD);
        _beethovenSwap(ERN, WFTM, ERN.balanceOf(address(this)), beetsPoolId);

        uint256 wftmBal = WFTM.balanceOf(address(this));
        if (wftmBal != 0) {
            // callFeeToUser = 0;
            uint256 wftmFee = (wftmBal * totalFee) / PERCENT_DIVISOR;
            WFTM.safeTransfer(treasury, wftmFee);
        }
    }

    /**
     * @dev Core harvest function.
     *      Converts reward tokens to want
     */
    function _addLiquidity() internal {
        // remaining OP_LINEAR used to join pool
        uint256 wftmBal = WFTM.balanceOf(address(this));
        if (wftmBal != 0) {
            IBaseWeightedPool.JoinKind joinKind = IBaseWeightedPool.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT;
            uint256[] memory amountsIn = new uint256[](underlyings.length);
            amountsIn[wftmPosition] = wftmBal;
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
        (uint256 amount, ) = IMasterChef(MASTER_CHEF).userInfo(mcPoolId, address(this));
        return amount + IERC20Upgradeable(want).balanceOf(address(this));
    }

    /**
     * Withdraws all funds leaving rewards behind.
     */
    function _reclaimWant() internal override {
        IMasterChef(MASTER_CHEF).emergencyWithdraw(mcPoolId, address(this));
    }
}
