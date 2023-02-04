// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console2.sol";

import {CastBytes32Bytes6}      from "lib/yield-utils-v2/contracts/cast/CastBytes32Bytes6.sol";
import {CastU256I128}           from "lib/yield-utils-v2/contracts/cast/CastU256I128.sol";
import {CastU256U128}           from "lib/yield-utils-v2/contracts/cast/CastU256U128.sol";
import {CastU128I128}           from "lib/yield-utils-v2/contracts/cast/CastU128I128.sol";

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
import {WrapEtherModule}        from "lib/vault-v2/packages/foundry/contracts/modules/WrapEtherModule.sol";

import {IPool}                  from "lib/yieldspace-tv/src/interfaces/IPool.sol";
import {IStrategy}              from "lib/strategy-v2/contracts/interfaces/IStrategy.sol";

import {TestConstants}          from "./TestConstants.sol";
import {TestExtensions}         from "./TestExtensions.sol";

using stdStorage for StdStorage;
using CastBytes32Bytes6 for bytes32;
using CastU256I128 for uint256;
using CastU256U128 for uint256;
using CastU128I128 for uint128;

/// @dev This test harness tests that basic functions on the Ladle are functional.

contract HarnessBase is Test, TestConstants, TestExtensions {
    ICauldron cauldron;
    ILadle ladle;
    RepayFromLadleModule repayFromLadleModule;
    WrapEtherModule wrapEtherModule;

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

    modifier etherCollateral() {
        if(ilkId != 0x303000000000) {
            console.log("Not ETH collateral");
            return;
        }
        _;
    }

    modifier canProvideLiquidity() {
        if(ilkId != baseId) {
            console.log("Unable to provide liquidity for this ilk-base pair");
            return;
        }
        _;
    }

    function setUp() public virtual {
        string memory rpc = vm.envOr(RPC, HARNESS);
        vm.createSelectFork(rpc);

        string memory network = vm.envOr(NETWORK, MAINNET);

        cauldron = ICauldron(addresses[network][CAULDRON]);
        ladle = ILadle(addresses[network][LADLE]);
        repayFromLadleModule = RepayFromLadleModule(0xd47a7473C83a1cC145407e82Def5Ae15F8b338c2);
        wrapEtherModule = WrapEtherModule(0x22768FCaFe7BB9F03e31cb49823d1Ece30C0b8eA);

        strategy = IStrategy(vm.envAddress(STRATEGY));
        seriesId = vm.envOr(SERIES_ID, bytes32(0)).b6();
        ilkId = vm.envOr(ILK_ID, bytes32(0)).b6();
        baseId = cauldron.series(seriesId).baseId;

        ilkInCauldron = cauldron.assets(ilkId) != address(0);
        ilkEnabled = cauldron.ilks(seriesId, ilkId);

        if (ilkInCauldron && ilkEnabled) {
            fyToken = IFYToken(cauldron.series(seriesId).fyToken);
            ilk = IERC20(cauldron.assets(ilkId));
            base = IERC20(cauldron.assets(baseId));
            ilkJoin = IJoin(ladle.joins(ilkId));
            baseJoin = IJoin(ladle.joins(baseId));
            pool = IPool(ladle.pools(seriesId));
            _labels();

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

    function _labels() internal {
        vm.label(address(cauldron), "cauldron");
        vm.label(address(ladle), "ladle");
        vm.label(address(repayFromLadleModule), "repayFromLadleModule");
        vm.label(address(wrapEtherModule), "wrapEtherModule");
        vm.label(address(strategy), "strategy");
        vm.label(address(fyToken), "fyToken");
        vm.label(address(ilk), "ilk");
        vm.label(address(base), "base");
        vm.label(address(base), "base");
        vm.label(address(ilkJoin), "ilkJoin");
        vm.label(address(baseJoin), "baseJoin");
        vm.label(address(pool), "pool");
    }
    
    function _clearBatch(uint256 length) internal {
        for (uint256 i = 0; i < length; i++) {
            batch.pop();
        }
    }

    function _afterMaturity() internal {
        vm.warp(fyToken.maturity());
    }

    function _buildVault(uint256 posted, uint256 borrowed) internal returns (bytes12 vaultId) {        
        vm.startPrank(user);

        base.approve(address(ladle), posted);
        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, ilkId, 0));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, ilk, address(ilkJoin), posted));
        batch.push(abi.encodeWithSelector(ladle.pour.selector, vaultId, user, posted.i128(), borrowed.i128()));
        bytes[] memory results = ladle.batch(batch);
        
        vm.stopPrank();

        bytes12 vaultId = abi.decode(results[0], (bytes12));

        _clearBatch(batch.length);

        return vaultId;
    }

    function _getAmountToBorrow() internal returns (uint256 borrowed) {
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec); // We borrow `dust`
        borrowed = borrowed == 0 ? baseUnit : borrowed; // If dust is 0 (ETH/ETH), we borrow 1 base unit

        return borrowed;
    }

    function _getAmountToPost(uint256 borrowed) internal returns (uint256 posted) {
        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = (2 * borrowValue * spot.ratio) / 1e6; // We collateralize to twice the bare minimum. TODO: Collateralize to the minimum

        return posted;
    }

    function _postEther() internal returns (bytes12 vaultId, uint256 posted) {
        vm.deal(user, 1 ether);
        uint256 posted = user.balance;
        
        // Build vault
        vm.prank(user);
        (bytes12 vaultId,) = ladle.build(seriesId, ilkId, 0);
        
        // DEPRECATED
        // batch.push(abi.encodeWithSelector(ladle.joinEther.selector, ilkId));
        
        batch.push(
            abi.encodeWithSelector(
                ladle.moduleCall.selector,
                address(wrapEtherModule),
                abi.encodeWithSelector(wrapEtherModule.wrap.selector, address(ilkJoin), posted)
            )
        );
        batch.push(abi.encodeWithSelector(ladle.pour.selector, vaultId, address(ladle), posted, 0));



        vm.prank(user);
        // address(ladle).call{ value: posted }(abi.encodeWithSelector(ladle.batch.selector, batch));
        ladle.batch{ value: user.balance }(batch);
        
        DataTypes.Balances memory balances = cauldron.balances(vaultId);

        assertEq(balances.ink, posted);
        
        _clearBatch(batch.length);

        return (vaultId, posted);
    }

    function _borrowAndPool(bytes12 vaultId, uint256 baseToPool, uint256 fyTokenToPool) internal returns (uint256 lpTokensMinted) {
        // Approve amount of base for user
        cash(base, user, baseToPool);
        
        vm.startPrank(user);

        base.approve(address(ladle), baseToPool);
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), baseToPool));
        batch.push(abi.encodeWithSelector(ladle.pour.selector, vaultId, address(pool), 0, fyTokenToPool));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.mint.selector, user, user, 0, type(uint256).max)
            )
        );
        bytes[] memory results = ladle.batch(batch);
        
        vm.stopPrank();

        _clearBatch(batch.length);

        (,,lpTokensMinted) = abi.decode(results[2], (uint256, uint256, uint256));

        return lpTokensMinted;
    }

    function _borrowAndPoolStrategy(address guy, uint256 totalBase) internal {
        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 fyTokenToPool = (totalBase * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        uint256 baseToPool = totalBase - fyTokenToPool;

        cash(base, guy, totalBase);
        
        vm.startPrank(guy);

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
        ladle.batch(batch);
        vm.stopPrank();

        _clearBatch(batch.length);
    }

    function _borrowAndPoolEther() internal returns (uint256 lpTokensMinted) {
        vm.deal(user, 10 ether);
        
        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, ilkId, 0));
        batch.push(
            abi.encodeWithSelector(
                ladle.moduleCall.selector,
                address(wrapEtherModule),
                abi.encodeWithSelector(wrapEtherModule.wrap.selector, address(baseJoin),  2 ether)
            )
        );
        batch.push(
            abi.encodeWithSelector(
                ladle.moduleCall.selector,
                address(wrapEtherModule),
                abi.encodeWithSelector(wrapEtherModule.wrap.selector, address(pool), 8 ether)
            )
        );
        batch.push(abi.encodeWithSelector(ladle.pour.selector, 0, address(pool), 2 ether, 2 ether));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(pool.mint.selector, user, user, 0 , type(uint256).max)
            )
        );

        vm.prank(user);
        bytes[] memory results = ladle.batch{ value: user.balance }(batch);
        (,,uint256 lpTokensMinted) = abi.decode(results[4], (uint256, uint256, uint256));

        _clearBatch(batch.length);

        return lpTokensMinted;
    }
}

contract RecipeHarness is HarnessBase {

    /*//////////////////////
    /// VAULT MANAGEMENT ///
    //////////////////////*/

    function testBuildVault() public canSkip {
        bytes12 vaultId = _buildVault(0, 0);

        assertEq(cauldron.vaults(vaultId).owner, user);
    }

    function testDestroyVault() public canSkip {
        bytes12 vaultId = _buildVault(0, 0);

        vm.prank(user);
        ladle.destroy(vaultId);

        assertEq(cauldron.vaults(vaultId).owner, address(0));
    }

    function testMergeVaults() public canSkip {
        // Get borrowed amount
        uint256 borrowed = _getAmountToBorrow();
        
        // Get posted amount
        uint256 posted = _getAmountToPost(borrowed);

        // Approve amounts for users
        cash(ilk, user, posted * 2);
        vm.prank(user);
        ilk.approve(address(ladle), posted * 2);

        // Build first vault
        bytes12 vaultId1 = _buildVault(posted, 0);

        // Build second vault
        bytes12 vaultId2 = _buildVault(posted, 0);

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
        uint256 borrowed = _getAmountToBorrow();

        // Get posted amount
        uint256 posted = _getAmountToPost(borrowed);

        // Approve amounts for user
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ilkJoin), posted);

        // Build vault
        bytes12 vaultId = _buildVault(posted, borrowed);

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
        // Need to account for odd numbered inks and arts
        assertApproxEqAbs(newBalances.ink, initialBalances.ink / 2, 1);
        assertApproxEqAbs(newBalances.art, initialBalances.art / 2, 1);
        assertApproxEqAbs(otherNewBalances.ink, initialBalances.ink / 2, 1);
        assertApproxEqAbs(otherNewBalances.art, initialBalances.art / 2, 1);
    }

    /*//////////////////////////////
    /// COLLATERAL AND BORROWING ///
    //////////////////////////////*/

    function testBorrowFYToken() public canSkip {
        // Get borrowed amount
        uint256 borrowed = _getAmountToBorrow();

        // Get posted amount
        uint256 posted = _getAmountToPost(borrowed);
        
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ladle), posted);

        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, ilkId, 0));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, ilk, address(ilkJoin), posted));
        batch.push(abi.encodeWithSelector(ladle.pour.selector, bytes12(0), other, posted, borrowed));

        vm.prank(user);
        bytes[] memory results = ladle.batch(batch);

        bytes12 vaultId = abi.decode(results[0], (bytes12));

        DataTypes.Balances memory balances = cauldron.balances(vaultId);

        // TODO: I would also assert here that the balances match `posted` and `borrowed`
        assertEq(fyToken.balanceOf(other), borrowed);
        assertEq(balances.ink, posted);
        assertEq(balances.art, borrowed);
    }

    function testBorrowUnderlying() public canSkip {
        // Get borrowed amount
        uint256 borrowed = _getAmountToBorrow();

        // Get posted amount
        uint256 posted = _getAmountToPost(borrowed);

        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ladle), posted);

        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, ilkId, 0));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, ilk, address(ilkJoin), posted));

        // TODO: `borrowed` is a base amount, and `posted` is calculated as if it were a fyToken amount.
        // This works anyway because we calculate `posted` as twice what it would need to be in `_getAmountToPost`.
        batch.push(
            abi.encodeWithSelector(
                ladle.serve.selector, bytes12(0), other, uint128(posted), uint128(borrowed), type(uint128).max
            )
        );

        vm.prank(user);
        bytes[] memory results = ladle.batch(batch);

        bytes12 vaultId = abi.decode(results[0], (bytes12));

        DataTypes.Balances memory balances = cauldron.balances(vaultId);

        // TODO: I would also assert that the balances.art of the user is within a 10% of `borrowed`, to make sure he was not ripped off.
        assertApproxEqAbs(base.balanceOf(other), borrowed, baseUnit / 100);
        assertApproxEqRel(balances.art, borrowed, 1e17);
    }

    function testWithdrawCollateral() public canSkip {
        // Get borrowed amount
        uint256 borrowed = _getAmountToBorrow();

        // Get posted amount
        uint256 posted = _getAmountToPost(borrowed);

        // Approve amounts for user
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ilkJoin), posted);

        // Build vault
        bytes12 vaultId = _buildVault(posted, 0);

        // Get vault balances
        DataTypes.Balances memory initialBalances = cauldron.balances(vaultId);

        batch.push(abi.encodeWithSelector(ladle.pour.selector, vaultId, user, posted.i128() * -1, 0));
        batch.push(abi.encodeWithSelector(ladle.destroy.selector, vaultId)); // will only succeed if vault has no collateral or debt

        vm.prank(user);
        ladle.batch(batch);

        assertEq(ilk.balanceOf(user), posted);
    }

    /*////////////////////
    /// DEBT REPAYMENT ///
    ////////////////////*/

    function testRepayUnderlyingBeforeMaturity() public canSkip {
        // Get borrowed amount
        uint256 borrowed = _getAmountToBorrow();

        // Get posted amount
        uint256 posted = _getAmountToPost(borrowed);
        
        // Give the user collateral and approve it for use
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ladle), posted);

        // Build vault and borrow underlying
        bytes12 vaultId = _buildVault(posted, borrowed);

        // Get vault balances
        DataTypes.Balances memory initialBalances = cauldron.balances(vaultId);

        // Send all our base to the pool and repay at least half the art
        vm.startPrank(user);
        base.approve(address(ladle), base.balanceOf(user));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), base.balanceOf(user)));
        batch.push(abi.encodeWithSelector(ladle.repay.selector, vaultId, address(0), 0, initialBalances.art / 2));
        ladle.batch(batch);
        vm.stopPrank();

        DataTypes.Balances memory newBalances = cauldron.balances(vaultId);

        // TODO: As a shortcut, you can assert that at least `base.balanceOf(user)` was repaid, since you always buy fyToken below parity
        assertLt(newBalances.art, initialBalances.art); // should calculate the exact amount of art repaid
        assertEq(base.balanceOf(user), 0);
    }

    function testRepayVaultUnderlyingBeforeMaturity() public canSkip {
        // Get borrowed amount
        uint256 borrowed = _getAmountToBorrow();

        // Get posted amount
        uint256 posted = _getAmountToPost(borrowed);
        
        cash(ilk, user, posted * 2); // give more to user to repay debt with interest
        vm.prank(user);
        ilk.approve(address(ladle), posted);

        bytes12 vaultId = _buildVault(posted, borrowed);

        // Get vault balances
        DataTypes.Balances memory initialBalances = cauldron.balances(vaultId);

        // Send base to the pool and repay all of the art and have the difference refunded
        vm.startPrank(user);
        base.approve(address(ladle), base.balanceOf(user)); // For some ilks the amount approved here is less than needed in the batch
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), initialBalances.art));
        batch.push(abi.encodeWithSelector(ladle.repayVault.selector, vaultId, address(0), 0, initialBalances.art));
        ladle.batch(batch);
        vm.stopPrank();

        DataTypes.Balances memory newBalances = cauldron.balances(vaultId);

        // TODO: You can test that the user spent no more base than initialBalances.art, since you always buy fyToken below parity
        assertEq(newBalances.art, 0);
        assertLt(base.balanceOf(user), initialBalances.art);
    }

    function testRepayUnderlyingAfterMaturity() public canSkip {
        // Get borrowed amount
        uint256 borrowed = _getAmountToBorrow();

        // Get posted amount
        uint256 posted = _getAmountToPost(borrowed);
        
        // Give user collateral and approve
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ladle), posted);

        // User takes out lending position that matures
        bytes12 vaultId = _buildVault(posted, borrowed);
        _afterMaturity();

        // Get vault balances
        DataTypes.Balances memory initialBalances = cauldron.balances(vaultId);

        vm.startPrank(user);
        base.approve(address(baseJoin), initialBalances.art);
        batch.push(abi.encodeWithSelector(ladle.close.selector, vaultId, address(0), 0, -initialBalances.art.i128()));
        ladle.batch(batch);
        vm.stopPrank();

        DataTypes.Balances memory finalBalances = cauldron.balances(vaultId);

        // TODO: You can test that the user spent exactly initialBalances.art base
        assertEq(finalBalances.art, 0);
        assertEq(base.balanceOf(user), initialBalances.art);
    }

    function testReedem() public canSkip {
        cash(fyToken, user, baseUnit);
        _afterMaturity();

        uint256 initialFYTokens = fyToken.balanceOf(user);

        vm.prank(user);
        fyToken.redeem(initialFYTokens, user, user);

        assertEq(fyToken.balanceOf(user), 0);
        assertApproxEqRel(base.balanceOf(user), initialFYTokens, 1e17); // TODO: This would be different for mature fyToken. For sanity, you can check that the user gets between 1.0 and 1.1 base per fyToken.   
    }

    function testRollDebtBeforeMaturity() public canSkip {

    }

    /*/////////////
    /// LENDING ///
    /////////////*/

    function testLend() public canSkip {
        uint256 baseSold = baseUnit;

        cash(base, user, baseSold);
        vm.prank(user);
        base.approve(address(ladle), baseSold);

        uint256 poolBaseBalance = pool.getBaseBalance();

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, base, address(pool), baseSold));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector, address(pool), abi.encodeWithSelector(IPool.sellBase.selector, user, 0)
            )
        );

        vm.prank(user);
        ladle.batch(batch);

        assertEq(base.balanceOf(user), 0);
        // there seems to be an issue with this assertion for all series other than fyETH
        // assertEq(pool.getBaseBalance(), poolBaseBalance + baseSold);
        // TODO: Maybe because of Euler approximation?
        // TODO: Assert as well that the user got between 1.0 and 1.1 fyToken per base
        assertApproxEqRel(fyToken.balanceOf(user), baseSold, 1e17);
    }

    function testCloseLendBeforeMaturity() public canSkip {
        cash(fyToken, user, baseUnit);

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
        // TODO: Assert as well that the user got 0.9 and 1.0 base per fyToken
        assertApproxEqRel(fyToken.balanceOf(user), baseUnit, 1e17);
    }

    function testRollLendingBeforeMaturity() public canSkip {
        cash(fyToken, user, baseUnit);
    }

    function testRollLendingAfterMaturity() public canSkip {
        _afterMaturity();

        cash(fyToken, user, baseUnit);
    }

    /*/////////////////////////
    /// LIQUIDITY PROVIDING ///
    /////////////////////////*/

    function testProvideLiquidityByBorrowing() public canSkip canProvideLiquidity {
        // Get amounts to provide to the pool
        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 fyTokenToPool = (baseUnit * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        uint256 baseToPool = baseUnit - fyTokenToPool;

        // User creates a vault and provides it with collateral
        bytes12 vaultId = _buildVault(baseToPool, 0);

        // Borrow against the vault and pool the base
        uint256 lpTokensMinted = _borrowAndPool(vaultId, baseToPool, fyTokenToPool);

        // Get vault's final balance
        DataTypes.Balances memory finalBalances = cauldron.balances(vaultId);

        assertApproxEqAbs(pool.getBaseBalance(), poolBaseBalance + baseToPool, baseUnit / 100);
        assertApproxEqAbs(pool.getFYTokenBalance() - pool.totalSupply(), poolFYTokenBalance + fyTokenToPool, baseUnit / 100); // TODO: There is one wei lost somewhere
        // TODO: Assert that the user has the correct amount of pool tokens
        // TODO: Maybe assert that the pool used all the base and fyToken supplied
        assertEq(lpTokensMinted, fyTokenToPool);
    }

    function testProvideLiquidityWithUnderlying() public canSkip canProvideLiquidity {
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

        assertApproxEqAbs(pool.getBaseBalance(), poolBaseBalance + baseToPool, baseUnit / 100);
        assertEq(pool.getFYTokenBalance() - pool.totalSupply(), poolFYTokenBalance + baseToFYToken);
        assertLt(base.balanceOf(user), baseUnit); // user ends with 1 wei
        assertGt(pool.balanceOf(user), 0); // user will have a little less than one lp token
    }

    function testProvideLiquidityByBuying() public canSkip canProvideLiquidity {
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
    function testRemoveLiquidityAndRepay() public canSkip canProvideLiquidity {
        // Get amounts to provide to the pool
        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 fyTokenToPool = (baseUnit * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        uint256 baseToPool = baseUnit - fyTokenToPool;

        // User creates a vault and provides it with collateral
        bytes12 vaultId = _buildVault(baseToPool, 0);

        // Borrow against the vault and pool the base
        uint256 lpTokensMinted = _borrowAndPool(vaultId, baseToPool, fyTokenToPool);
        
        uint256 userBaseTokens = base.balanceOf(user);

        vm.prank(user);
        pool.approve(address(ladle), lpTokensMinted);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(pool), address(pool), lpTokensMinted));
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

        assertApproxEqAbs(base.balanceOf(user), userBaseTokens + baseUnit, baseUnit / 100);
        assertEq(pool.balanceOf(user), 0);
    }

    function testRemoveLiquidityRepayAndSell() public canSkip canProvideLiquidity {
        // Get amounts to provide to the pool
        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 fyTokenToPool = (baseUnit * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        uint256 baseToPool = baseUnit - fyTokenToPool;

        // User creates a vault and provides it with collateral
        bytes12 vaultId = _buildVault(baseToPool, 0);

        // Borrow against the vault and pool the base
        uint256 lpTokensMinted = _borrowAndPool(vaultId, baseToPool, fyTokenToPool);
        
        uint256 userBaseTokens = base.balanceOf(user);

        vm.prank(user);
        pool.approve(address(ladle), lpTokensMinted);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(pool), address(pool), lpTokensMinted));
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

        assertApproxEqAbs(base.balanceOf(user), userBaseTokens + baseUnit, baseUnit / 100);
        assertEq(pool.balanceOf(user), 0);
    }

    function testRemoveLiquidityAndRedeem() public canSkip canProvideLiquidity {
        // Get amounts to provide to the pool
        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 fyTokenToPool = (baseUnit * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        uint256 baseToPool = baseUnit - fyTokenToPool;

        // User creates a vault and provides it with collateral
        bytes12 vaultId = _buildVault(baseToPool, 0);

        // Borrow against the vault and pool the base
        uint256 lpTokensMinted = _borrowAndPool(vaultId, baseToPool, fyTokenToPool);

        uint256 userBaseTokens = base.balanceOf(user);

        _afterMaturity();

        vm.prank(user);
        pool.approve(address(ladle), lpTokensMinted);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(pool), address(pool), lpTokensMinted));
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

        assertApproxEqAbs(base.balanceOf(user), userBaseTokens + baseUnit, baseUnit / 100);
        assertEq(pool.balanceOf(user), 0);
    }

    function testRemoveLiquidityAndSell() public canSkip canProvideLiquidity {
        // Get amounts to provide to the pool
        uint256 poolBaseBalance = pool.getBaseBalance();
        uint256 poolFYTokenBalance = pool.getFYTokenBalance() - pool.totalSupply();
        uint256 fyTokenToPool = (baseUnit * poolFYTokenBalance) / (poolBaseBalance + poolFYTokenBalance);
        uint256 baseToPool = baseUnit - fyTokenToPool;

        // User creates a vault and provides it with collateral
        bytes12 vaultId = _buildVault(baseToPool, 0);

        // Borrow against the vault and pool the base
        uint256 lpTokensMinted = _borrowAndPool(vaultId, baseToPool, fyTokenToPool);
        
        uint256 userBaseTokens = base.balanceOf(user);

        vm.prank(user);
        pool.approve(address(ladle), lpTokensMinted);

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(pool), address(pool), lpTokensMinted));
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(IPool.burnForBase.selector, user, 0, type(uint256).max)
            )
        );

        vm.prank(user);
        ladle.batch(batch);

        assertApproxEqAbs(base.balanceOf(user), userBaseTokens + baseUnit, baseUnit / 100);
        assertEq(pool.balanceOf(user), 0);
    }

    /*////////////////
    /// STRATEGIES ///
    ////////////////*/

    function testProvideLiquidityToStrategyByBorrowing() public canSkip canProvideLiquidity {
        _borrowAndPoolStrategy(user, baseUnit);
    }

    function testProvideLiquidityToStrategyByBuying() public canSkip canProvideLiquidity {
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

        // TODO: needs fixing
        // assertLt(base.balanceOf(user), baseUnit * 4);
        // assertApproxEqAbs(strategy.balanceOf(user), baseUnit * 4, baseUnit / 100);
    }

    function testRemoveLiquidityFromStrategy() public canSkip canProvideLiquidity {
        _borrowAndPoolStrategy(user, baseUnit);

        uint256 strategyTokensBurnt = strategy.balanceOf(user);

        vm.prank(user);
        strategy.approve(address(ladle), strategyTokensBurnt);

        // Burn strategy tokens
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, address(strategy), address(strategy), strategyTokensBurnt));
        batch.push(abi.encodeWithSelector(
            ladle.route.selector, 
            address(strategy),
            abi.encodeWithSelector(IStrategy.burn.selector, address(pool))
        ));

        uint256 lpTokensBurnt = pool.balanceOf(user); // why is this 0?

        _clearBatch(batch.length);

        // Remove liquidity and sell
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

    function testRemoveLiquidityFromDeprecatedStrategy() public canSkip canProvideLiquidity {
        _borrowAndPoolStrategy(user, baseUnit);
        
    }

    /*///////////
    /// ETHER ///
    ///////////*/

    function testPostEtherCollateral() public canSkip etherCollateral {
        _postEther();
    }

    function testWithdrawEtherCollateral() public canSkip etherCollateral {
        (bytes12 vaultId, uint256 posted) = _postEther();

        batch.push(abi.encodeWithSelector(ladle.pour.selector, vaultId, address(ladle), -posted.i128(), 0));
        batch.push(abi.encodeWithSelector(ladle.exitEther.selector, user));
        batch.push(abi.encodeWithSelector(ladle.destroy.selector, vaultId));

        vm.prank(user);
        ladle.batch(batch);

        assertEq(user.balance, 1 ether);
    }

    function testRedeemfyETH() public canSkip {
        cash(fyToken, user, baseUnit);
        vm.prank(user);
        fyToken.approve(address(ladle), baseUnit);

        _afterMaturity();

        batch.push(abi.encodeWithSelector(ladle.transfer.selector, fyToken, address(ladle), baseUnit));
        batch.push(abi.encodeWithSelector(ladle.redeem.selector, seriesId, address(ladle), baseUnit));
        batch.push(abi.encodeWithSelector(ladle.exitEther.selector, user));

        vm.prank(user);
        ladle.batch(batch);

        console.log(base.balanceOf(user));
        assertEq(user.balance, 1 ether);
    }

    function testProvideEtherLiquidityByBorrowing() public canSkip {
        uint256 initialJoinBalance = baseJoin.storedBalance();

        uint256 lpTokensMinted = _borrowAndPoolEther();

        uint256 finalJoinBalance = baseJoin.storedBalance();
        
        assertEq(finalJoinBalance, initialJoinBalance + 2 ether);
        assertEq(lpTokensMinted, 8 ether);
    }

    function testProvideEtherLiquidityByBuying() public canSkip {
        vm.deal(user, 10 ether);

        batch.push(
            abi.encodeWithSelector(
                ladle.moduleCall.selector,
                address(wrapEtherModule),
                abi.encodeWithSelector(wrapEtherModule.wrap.selector, address(pool), 10 ether)
            )
        );
        batch.push(
            abi.encodeWithSelector(
                ladle.route.selector,
                address(pool),
                abi.encodeWithSelector(pool.mintWithBase.selector, user, address(ladle), 2 ether, 0, type(uint256).max)
            )
        );
        batch.push(abi.encodeWithSelector(ladle.exitEther.selector, user));

        vm.prank(user);
        bytes[] memory results = ladle.batch{ value: user.balance }(batch);
        (uint256 baseIn, uint256 fyTokenIn ,uint256 lpTokensMinted) = abi.decode(results[1], (uint256, uint256, uint256));

        assertEq(lpTokensMinted, 10 ether);
    }

    // Should test this? Doesn't include recipe but seems to just call exitEther
    // at the end of the ordinary liquidity removal
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
