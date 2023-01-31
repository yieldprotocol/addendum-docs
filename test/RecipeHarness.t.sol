// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console2.sol";

import {CastBytes32Bytes6}      from "lib/yield-utils-v2/contracts/cast/CastBytes32Bytes6.sol";
import {CastU256I128}           from "lib/yield-utils-v2/contracts/cast/CastU256I128.sol";
import {CastU256U128}           from "lib/yield-utils-v2/contracts/cast/CastU256U128.sol";
import {DataTypes}              from "lib/vault-v2/packages/foundry/contracts/interfaces/DataTypes.sol";

import {IERC20}                 from "lib/yield-utils-v2/contracts/token/IERC20.sol";
import {IERC20Metadata}         from "lib/yield-utils-v2/contracts/token/IERC20Metadata.sol";
import {IERC2612}               from "lib/yield-utils-v2/contracts/token/IERC2612.sol";
import {ERC20Permit}            from "lib/yield-utils-v2/contracts/token/ERC20Permit.sol";

import {ICauldron}              from "lib/vault-v2/packages/foundry/contracts/interfaces/ICauldron.sol";
import {IFYToken}               from "lib/vault-v2/packages/foundry/contracts/interfaces/IFYToken.sol";
import {IJoin}                  from "lib/vault-v2/packages/foundry/contracts/interfaces/IJoin.sol";
import {ILadle}                 from "lib/vault-v2/packages/foundry/contracts/interfaces/ILadle.sol";
import {RepayFromLadleModule}   from "lib/vault-v2/packages/foundry/contracts/modules/RepayFromLadleModule.sol";
import {IPool}                  from "lib/yieldspace-tv/src/interfaces/IPool.sol";
import {IStrategy}              from "lib/strategy-v2/contracts/interfaces/IStrategy.sol";

import {TestConstants}          from "./TestConstants.sol";
import {TestExtensions}         from "./TestExtensions.sol";

using stdStorage for StdStorage;
using CastBytes32Bytes6 for bytes32;
using CastU256I128 for uint256;
using CastU256U128 for uint256;

/// @dev This test harness tests that basic functions on the Ladle are functional.

abstract contract ZeroState is Test, TestConstants, TestExtensions {
    ICauldron cauldron;
    ILadle ladle;
    RepayFromLadleModule repayFromLadleModule;

    uint256 userPrivateKey = 0xBABE;
    address user = vm.addr(userPrivateKey);
    uint256 otherPrivateKey = 0xBEEF;
    address other = vm.addr(otherPrivateKey);

    bytes6 seriesId;
    bytes6 ilkId;
    bytes6 baseId;

    IFYToken fyToken;
    IERC20 ilk;
    IERC20 base;
    IJoin ilkJoin;
    IJoin baseJoin;
    IPool pool;
    IStrategy strategy;

    uint256 fyTokenUnit;
    uint256 ilkUnit;
    uint256 baseUnit;
    uint256 poolUnit;

    bytes[] batch;

    bool ilkEnabled; // Skip tests if the ilk is not enabled for the series
    bool ilkInCauldron; // Skip tests if the ilk is not in the cauldron
    bool matchStrategy; // Skip tests if the series is not the selected for the strategy

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    modifier canSkip() {
        if (!ilkEnabled) {
            console.log("Ilk not enabled for series, skipping test");
            return;
        }
        if (!ilkInCauldron) {
            console.log("Ilk not in cauldron, skipping test");
            return;
        }
        _;
    }

    function setUp() public virtual {
        string memory rpc = vm.envOr(RPC, HARNESS);
        vm.createSelectFork(rpc);

        string memory network = vm.envOr(NETWORK, MAINNET);

        cauldron = ICauldron(addresses[network][CAULDRON]);
        vm.label(address(cauldron), "cauldron");
        ladle = ILadle(addresses[network][LADLE]);
        vm.label(address(ladle), "ladle");
        repayFromLadleModule = RepayFromLadleModule(0xd47a7473C83a1cC145407e82Def5Ae15F8b338c2);
        vm.label(address(repayFromLadleModule), "repayFromLadleModule");

        strategy = IStrategy(vm.envAddress(STRATEGY));
        vm.label(address(strategy), "strategy");
        seriesId = vm.envOr(SERIES_ID, bytes32(0)).b6();
        ilkId = vm.envOr(ILK_ID, bytes32(0)).b6();
        baseId = cauldron.series(seriesId).baseId;

        ilkInCauldron = cauldron.assets(ilkId) != address(0);
        ilkEnabled = cauldron.ilks(seriesId, ilkId);

        if (ilkInCauldron && ilkEnabled) {
            fyToken = IFYToken(cauldron.series(seriesId).fyToken);
            vm.label(address(fyToken), "fyToken");
            ilk = IERC20(cauldron.assets(ilkId));
            vm.label(address(ilk), "ilk");
            base = IERC20(cauldron.assets(baseId));
            vm.label(address(base), "base");
            ilkJoin = IJoin(ladle.joins(ilkId));
            vm.label(address(ilkJoin), "ilkJoin");
            baseJoin = IJoin(ladle.joins(baseId));
            vm.label(address(baseJoin), "baseJoin");
            pool = IPool(ladle.pools(seriesId));
            vm.label(address(pool), "pool");

            fyTokenUnit = 10 ** IERC20Metadata(address(fyToken)).decimals();
            ilkUnit = 10 ** IERC20Metadata(address(ilk)).decimals();
            baseUnit = 10 ** IERC20Metadata(address(base)).decimals();
            poolUnit = 10 ** IERC20Metadata(address(pool)).decimals();

            matchStrategy = (address(strategy.fyToken()) == address(fyToken));
        }
    }

    /*//////////////////////
    /// HELPER FUNCTIONS ///
    //////////////////////*/

    function _clearBatch(uint256 length) internal {
        for (uint256 i = 0; i < length; i++) {
            batch.pop();
        }
    }

    function _afterMaturity() internal {
        vm.warp(fyToken.maturity());
    }

    function _lend(address guy, uint256 totalBase) internal {
        uint256 baseSold = totalBase;

        cash(base, guy, baseSold);
        vm.prank(guy);
        base.approve(address(ladle), baseSold);

        uint256 poolBaseBalance = pool.getBaseBalance();

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), baseSold));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector, address(pool), abi.encodeWithSelector(IPool.sellBase.selector, guy, 0)
            )
        );

        vm.prank(guy);
        ladle.batch(batch);

        assertEq(base.balanceOf(guy), 0);
        assertEq(pool.getBaseBalance(), poolBaseBalance + baseSold);
    }

    function _buildVault(address guy, uint256 ilkAmount, uint256 baseAmount) internal returns (bytes12 vaultId) {
        vm.startPrank(guy);
        (bytes12 vaultId,) = ladle.build(seriesId, ilkId, 0);
        ladle.pour(vaultId, user, ilkAmount.i128(), baseAmount.i128());
        vm.stopPrank();

        return vaultId;
    }

    function _borrowAndPool(address guy, uint256 totalBase) internal returns (bytes12 vaultId) {
        // Get borrowed amount
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec);
        borrowed = borrowed == 0 ? totalBase : borrowed;

        // Get posted amount
        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = (2 * borrowValue * spot.ratio) / 1e6;

        // Approve amount of ilk for user
        cash(ilk, guy, posted);
        vm.prank(guy);
        ilk.approve(address(ilkJoin), posted);

        // Build vault
        bytes12 vaultId = _buildVault(guy, posted, 0);
        
        // Get vault's initial balance
        DataTypes.Balances memory initialBalances = cauldron.balances(vaultId);

        // WETH has no DOMAIN_SEPARATOR but this code is how it would work
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(
        //     userPrivateKey,
        //     keccak256(
        //         abi.encodePacked(
        //             "\x19\x01",
        //             ERC20Permit(address(base)).DOMAIN_SEPARATOR(),
        //             keccak256(abi.encode(PERMIT_TYPEHASH, user, other, 1e18, 0, block.timestamp))
        //         )
        //     )
        // );

        // Get amounts to provide to the pool
        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 fyTokenToPool = (totalBase * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        uint256 baseToPool = totalBase - fyTokenToPool;

        // Approve amount of base for user
        cash(base, guy, totalBase);
        vm.prank(guy);
        base.approve(address(ladle), totalBase);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), baseToPool));
        batch.push(abi.encodeWithSelector(ladle.pour.selector, vaultId, address(pool), 0, fyTokenToPool));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.mint.selector, user, user, 0, type(uint256).max)
            )
        );

        vm.prank(guy);
        ladle.batch(batch);

        // Get vault's final balance
        DataTypes.Balances memory finalBalances = cauldron.balances(vaultId);

        assertApproxEqAbs(pool.getBaseBalance(), poolBaseBalance + baseToPool, 1); // off-by-1 error
        assertEq(pool.getFYTokenBalance() - pool.totalSupply(), poolFYTokenBalance + fyTokenToPool);
        assertEq(finalBalances.ink, initialBalances.ink);
        assertEq(finalBalances.art, initialBalances.art + fyTokenToPool);

        return vaultId;
    }

    function _borrowAndPoolStrategy(address guy, uint256 totalBase) internal {
        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 fyTokenToPool = (totalBase * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        uint256 baseToPool = totalBase - fyTokenToPool;

        cash(base, guy, totalBase);
        vm.prank(guy);
        base.approve(address(ladle), totalBase);

        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, baseId, 0));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(baseJoin), fyTokenToPool));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), baseToPool));
        batch.push(abi.encodeWithSelector(ladle.pour.selector, bytes12(0), address(pool), fyTokenToPool, fyTokenToPool));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.mint.selector, address(strategy), address(guy), 0, type(uint256).max)
            )
        );
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector, address(strategy), abi.encodeWithSelector(IStrategy.mint.selector, address(guy))
            )
        );

        vm.prank(guy);
        ladle.batch(batch);
    }
}

contract ZeroStateTest is ZeroState {

    /*//////////////////////
    /// VAULT MANAGEMENT ///
    //////////////////////*/

    function testBuildVault() public canSkip {
        bytes12 vaultId = _buildVault(user, 0, 0);

        assertEq(cauldron.vaults(vaultId).owner, user);
    }

    function testDestroyVault() public canSkip {
        bytes12 vaultId = _buildVault(user, 0, 0);

        vm.prank(user);
        ladle.destroy(vaultId);

        assertEq(cauldron.vaults(vaultId).owner, address(0));
    }

    function testMergeVaults() public canSkip {
        // Get borrowed amount
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec);
        borrowed = borrowed == 0 ? baseUnit : borrowed;

        // Get posted amount
        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = (2 * borrowValue * spot.ratio) / 1e6;

        // Approve amounts for users
        cash(ilk, user, posted * 2);
        vm.prank(user);
        ilk.approve(address(ilkJoin), posted * 2);

        // Build first vault
        bytes12 vaultId1 = _buildVault(user, posted, 0);

        // Build second vault
        bytes12 vaultId2 = _buildVault(user, posted, 0);

        // Get balances of each
        DataTypes.Balances memory balances = cauldron.balances(vaultId1);
        DataTypes.Balances memory otherBalances = cauldron.balances(vaultId1);
        uint128 inkSum = balances.ink + otherBalances.ink;
        uint128 artSum = balances.art + otherBalances.art;

        batch.push(abi.encodeWithSelector(ladle.stir.selector, vaultId1, vaultId2, balances.ink, balances.art));
        batch.push(abi.encodeWithSelector(ladle.destroy.selector, vaultId1));

        vm.prank(user);
        ladle.batch(batch);

        DataTypes.Balances memory mergedBalances = cauldron.balances(vaultId2);
        assertEq(mergedBalances.ink, inkSum);
        assertEq(mergedBalances.art, artSum);
    }

    function testSplitVaults() public canSkip {
        // Get borrowed amount
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec);
        borrowed = borrowed == 0 ? baseUnit : borrowed;

        // Get posted amount
        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = (2 * borrowValue * spot.ratio) / 1e6;

        // Approve amounts for user
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ilkJoin), posted);

        // Build vault
        bytes12 vaultId = _buildVault(user, posted, borrowed);

        // Get vault balances
        DataTypes.Balances memory initialBalances = cauldron.balances(vaultId);

        // ladle.stir doesn't use getVaults and can't referenced the cachedVaultId
        // batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, ilkId, 0));
        // batch.push(abi.encodeWithSelector(ladle.stir.selector, vaultId, 0, posted / 2, 0));

        vm.startPrank(user);
        (bytes12 newVaultId,) = ladle.build(seriesId, ilkId, 0);
        ladle.stir(vaultId, newVaultId, uint128(posted / 2), uint128(borrowed / 2));
        vm.stopPrank();

        DataTypes.Balances memory newBalances = cauldron.balances(vaultId);
        DataTypes.Balances memory otherNewBalances = cauldron.balances(newVaultId);
        assertEq(newBalances.ink, initialBalances.ink / 2);
        assertEq(newBalances.art, initialBalances.art / 2);
        assertEq(otherNewBalances.ink, initialBalances.ink / 2);
        assertEq(otherNewBalances.art, initialBalances.art / 2);
    }

    /*//////////////////////////////
    /// COLLATERAL AND BORROWING ///
    //////////////////////////////*/

    function testBorrowFYToken() public canSkip {
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec); // We borrow `dust`
        borrowed = borrowed == 0 ? baseUnit : borrowed; // If dust is 0 (ETH/ETH), we borrow 1 base unit

        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = (2 * borrowValue * spot.ratio) / 1e6; // We collateralize to twice the bare minimum. TODO: Collateralize to the minimum
        
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ladle), posted);

        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, ilkId, 0));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, ilk, address(ilkJoin), posted));
        batch.push(abi.encodeWithSelector(ladle.pour.selector, bytes12(0), other, posted, borrowed));

        vm.prank(user);
        ladle.batch(batch);

        assertEq(fyToken.balanceOf(other), borrowed);
    }

    function testBorrowUnderlying() public canSkip {
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec); // We borrow `dust` but in base, which always will be a bit more than `dust`
        borrowed = borrowed == 0 ? baseUnit : borrowed; // If dust is 0 (ETH/ETH), we borrow 1 base unit

        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = (2 * borrowValue * spot.ratio) / 1e6; // We collateralize to twice the bare minimum. TODO: Collateralize to the minimum

        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ladle), posted);

        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, ilkId, 0));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, ilk, address(ilkJoin), posted));
        batch.push(
            abi.encodeWithSelector(
                ladle.serve.selector, bytes12(0), other, uint128(posted), uint128(borrowed), type(uint128).max
            )
        );

        vm.prank(user);
        ladle.batch(batch);

        assertApproxEqAbs(base.balanceOf(other), borrowed, 1); // TODO: Is it ok that we get 1 wei less thna expected?
    }

    function testWithdrawCollateral() public canSkip {
        // Get borrowed amount
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec);
        borrowed = borrowed == 0 ? baseUnit : borrowed;

        // Get posted amount
        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = (2 * borrowValue * spot.ratio) / 1e6;

        // Approve amounts for user
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ilkJoin), posted);

        // Build vault
        bytes12 vaultId = _buildVault(user, posted, 0);

        // Get vault balances
        DataTypes.Balances memory initialBalances = cauldron.balances(vaultId);

        batch.push(abi.encodeWithSelector(ladle.pour.selector, vaultId, user, posted.i128() * -1, 0));
        batch.push(abi.encodeWithSelector(ladle.destroy.selector, vaultId)); // will only succeed if vault has no collateral or debt

        vm.prank(user);
        ladle.batch(batch);
    }

    /*////////////////////
    /// DEBT REPAYMENT ///
    ////////////////////*/

    function testRepayUnderlyingBeforeMaturity() public canSkip {

    }

    function testRepayVaultUnderlyingBeforeMaturity() public canSkip {

    }

    function testRepayUnderlyingAfterMaturity() public canSkip {

    }

    function testReedem() public canSkip {

    }

    function testRollDebtBeforeMaturity() public canSkip {

    }

    /*/////////////
    /// LENDING ///
    /////////////*/

    function testLend() public canSkip {
        _lend(user, baseUnit);
    }

    function testCloseLendBeforeMaturity() public canSkip {
        _lend(user, baseUnit);
        _clearBatch(batch.length);

        uint256 userFYTokens = fyToken.balanceOf(user);
        uint256 poolFYTokens = fyToken.balanceOf(address(pool));

        vm.prank(user);
        fyToken.approve(address(ladle), baseUnit);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, fyToken, address(pool), baseUnit));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector, address(pool), abi.encodeWithSelector(IPool.sellFYToken.selector, user, 0)
            )
        );

        vm.prank(user);
        ladle.batch(batch);

        // not sure why the user has > 1 baseUnit of fyTokens before this call
        assertEq(fyToken.balanceOf(user), userFYTokens - baseUnit);
        assertEq(fyToken.balanceOf(address(pool)), poolFYTokens + baseUnit);
        // this one could maybe be improved, buyBasePreview is not the correct way however
        assertGt(base.balanceOf(user), 0); // will have just below one baseUnit
    }

    function testCloseLendAfterMaturity() public canSkip {
        _lend(user, baseUnit);
        _afterMaturity();

        uint256 userFYTokens = fyToken.balanceOf(user);

        vm.startPrank(user);
        fyToken.approve(address(fyToken), fyToken.balanceOf(user));
        // fyToken.redeem(user, fyToken.balanceOf(user));
        fyToken.redeem(fyToken.balanceOf(user), user, user);
        vm.stopPrank();

        assertEq(base.balanceOf(user), userFYTokens); // redeemed all fyTokens 1-1
        assertEq(fyToken.balanceOf(user), 0);
    }

    function testRollLendingBeforeMaturity() public canSkip {
        _lend(user, baseUnit);
    }

    function testRollLendingAfterMaturity() public canSkip {
        _lend(user, baseUnit);
        _afterMaturity();
    }

    /*/////////////////////////
    /// LIQUIDITY PROVIDING ///
    /////////////////////////*/

    function testProvideLiquidityByBorrowing() public canSkip {
        _borrowAndPool(user, baseUnit);
    }

    function testProvideLiquidityWithUnderlying() public canSkip {
        // Get amounts to provide to the pool
        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 baseToFYToken = (baseUnit * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        uint256 baseToPool = baseUnit - baseToFYToken;

        // Approve amount of base for user
        cash(base, user, baseToPool + baseToFYToken);
        vm.prank(user);
        base.approve(address(ladle), baseToPool + baseToFYToken);

        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, baseId, 0));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(baseJoin), baseToFYToken));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), baseToPool));
        batch.push(abi.encodeWithSelector(ladle.pour.selector, 0, address(pool), baseToFYToken, baseToFYToken));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.mint.selector, user, user, 0, type(uint256).max)
            )
        );

        vm.prank(user);
        ladle.batch(batch);

        assertEq(pool.getBaseBalance(), poolBaseBalance + baseToPool - 1);
        assertEq(pool.getFYTokenBalance() - pool.totalSupply(), poolFYTokenBalance + baseToFYToken);
        assertLt(base.balanceOf(user), baseUnit); // user ends with 1 wei
        assertGt(pool.balanceOf(user), 0); // user will have a little less than one lp token
    }

    function testProvideLiquidityByBuying() public canSkip {
        uint256 baseWithSlippage = baseUnit * 4; // Better way to do this so it doesn't revert with NotEnoughBaseIn?
        uint256 fyTokenToBuy = baseUnit;

        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 fyTokenToPool = (baseUnit * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        // (1 * 50.89) / (148.28 * 50.89)

        cash(base, user, baseUnit * 4);
        vm.prank(user);
        base.approve(address(ladle), baseUnit * 4);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), baseWithSlippage));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.mintWithBase.selector, user, user, fyTokenToBuy, 0, type(uint256).max)
            )
        );

        vm.prank(user);
        ladle.batch(batch);

        // not really sure about the math of these changes
        // user is left with a small amount of base and an amount of lp tokens less than baseUnit * 4
        assertLt(base.balanceOf(user), baseUnit * 4);
        assertGt(pool.balanceOf(user), 0);
    }

    // not confident in the assertions for these liquidity removal functions
    function testRemoveLiquidityAndRepay() public canSkip {
        bytes12 vaultId = _borrowAndPool(user, baseUnit);
        uint256 lpTokensBurnt = pool.balanceOf(user);

        uint256 userBaseTokens = base.balanceOf(user);

        _clearBatch(batch.length);

        vm.prank(user);
        pool.approve(address(ladle), lpTokensBurnt);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(pool), address(pool), lpTokensBurnt));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.burn.selector, user, address(ladle), 0, type(uint256).max)
            )
        );
        batch.push(
            abi.encodeWithSelector(
                ladle.moduleCall.selector,
                address(repayFromLadleModule),
                abi.encodeWithSelector(repayFromLadleModule.repayFromLadle.selector, vaultId, user, user)
            )
        );

        vm.prank(user);
        ladle.batch(batch);

        assertApproxEqAbs(base.balanceOf(user), userBaseTokens + baseUnit, 10);
        assertEq(pool.balanceOf(user), 0);
    }

    function testRemoveLiquidityRepayAndSell() public canSkip {
        bytes12 vaultId = _borrowAndPool(user, baseUnit);
        uint256 lpTokensBurnt = pool.balanceOf(user);

        uint256 userBaseTokens = base.balanceOf(user);

        _clearBatch(batch.length);

        vm.prank(user);
        pool.approve(address(ladle), lpTokensBurnt);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(pool), address(pool), lpTokensBurnt));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.burn.selector, user, address(ladle), 0, type(uint256).max)
            )
        );
        batch.push(
            abi.encodeWithSelector(
                ladle.moduleCall.selector,
                address(repayFromLadleModule),
                abi.encodeWithSelector(repayFromLadleModule.repayFromLadle.selector, vaultId, user, address(pool))
            )
        );
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector, address(pool), abi.encodeWithSelector(IPool.sellFYToken.selector, user, 0)
            )
        );

        vm.prank(user);
        ladle.batch(batch);

        assertApproxEqAbs(base.balanceOf(user), userBaseTokens + baseUnit, 10e16);
        assertEq(pool.balanceOf(user), 0);
    }

    function testRemoveLiquidityAndRedeem() public canSkip {
        bytes12 vaultId = _borrowAndPool(user, baseUnit);
        uint256 lpTokensBurnt = pool.balanceOf(user);

        uint256 userBaseTokens = base.balanceOf(user);

        _clearBatch(batch.length);
        _afterMaturity();

        vm.prank(user);
        pool.approve(address(ladle), lpTokensBurnt);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(pool), address(pool), lpTokensBurnt));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.burn.selector, user, address(fyToken), 0, type(uint256).max)
            )
        );
        batch.push(abi.encodeWithSelector(ladle.redeem.selector, seriesId, user, 0));

        vm.prank(user);
        ladle.batch(batch);

        assertApproxEqAbs(base.balanceOf(user), userBaseTokens + baseUnit, 10e16);
        assertEq(pool.balanceOf(user), 0);
    }

    function testRemoveLiquidityAndSell() public canSkip {
        bytes12 vaultId = _borrowAndPool(user, baseUnit);
        uint256 lpTokensBurnt = pool.balanceOf(user);

        uint256 userBaseTokens = base.balanceOf(user);

        _clearBatch(batch.length);

        vm.prank(user);
        pool.approve(address(ladle), lpTokensBurnt);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(pool), address(pool), lpTokensBurnt));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.burnForBase.selector, user, 0, type(uint256).max)
            )
        );

        vm.prank(user);
        ladle.batch(batch);

        assertApproxEqAbs(base.balanceOf(user), userBaseTokens + baseUnit, 10e16);
        assertEq(pool.balanceOf(user), 0);
    }

    function testRollLiquidity() public canSkip {

    }

    /*////////////////
    /// STRATEGIES ///
    ////////////////*/

    function testProvideLiquidityToStrategyByBorrowing() public canSkip {
        _borrowAndPoolStrategy(user, baseUnit);
    }

    function testProvideLiquidityToStrategyByBuying() public canSkip {
        uint256 baseWithSlippage = baseUnit * 4;
        uint256 fyTokensToBuy = baseUnit;

        cash(base, user, baseUnit * 4);
        vm.prank(user);
        base.approve(address(ladle), baseUnit * 4);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), baseWithSlippage));
        batch.push(abi.encodeWithSelector(
            ladle.route.selector,
            address(pool),
            abi.encodeWithSelector(IPool.mintWithBase.selector, address(strategy), user, fyTokensToBuy, 0, type(uint256).max)
        ));
        batch.push(abi.encodeWithSelector(
            ladle.route.selector,
            address(strategy),
            abi.encodeWithSelector(IStrategy.mint.selector, user)
        ));

        vm.prank(user);
        ladle.batch(batch);

        assertLt(base.balanceOf(user), baseUnit * 4);
        assertApproxEqAbs(strategy.balanceOf(user), baseUnit * 4, 10e16);
    }

    function testRemoveLiquidityFromStrategy() public canSkip {
        _borrowAndPoolStrategy(user, baseUnit);
        uint256 strategyTokensBurnt = strategy.balanceOf(user);

        _clearBatch(batch.length);

        vm.prank(user);
        strategy.approve(address(ladle), strategyTokensBurnt);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(strategy), address(strategy), strategyTokensBurnt));
        batch.push(abi.encodeWithSelector(
            ladle.route.selector, 
            address(strategy),
            abi.encodeWithSelector(IStrategy.burn.selector, address(pool))
        ));

        uint256 lpTokensBurnt = pool.balanceOf(user); // why is this 0?

        _clearBatch(batch.length);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(pool), address(pool), lpTokensBurnt));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.burnForBase.selector, user, 0, type(uint256).max)
            )
        );

        vm.prank(user);
        ladle.batch(batch);
    }

    // Is this one needed? (Are we still using v1 strategies?)
    function testRemoveLiquidityFromDeprecatedStrategy() public canSkip {
        _borrowAndPoolStrategy(user, baseUnit);
    }

    /*///////////
    /// ETHER ///
    ///////////*/

    function testPostEtherCollateral() public canSkip {

    }

    function testWithdrawEtherCollateral() public canSkip {

    }

    function testRedeemfyETH() public canSkip {

    }

    function testProvideEtherLiquidityByBorrowing() public canSkip {

    }

    function testProvideEtherLiquidityByBuying() public canSkip {

    }

    function testRemoveEtherLiquidity() public canSkip {

    }

    /*/////////////
    /// ERC1155 ///
    /////////////*/

    function testPostERC1155Collateral() public canSkip {

    }

    function testWithdrawERC1155Collateral() public canSkip {
        
    }
}
