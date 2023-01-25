// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console2.sol";
import "lib/vault-v2/packages/foundry/contracts/interfaces/DataTypes.sol";
// import { IERC20 } from "lib/yield-utils-v2/contracts/token/IERC20.sol";
import {IERC2612} from "lib/yield-utils-v2/contracts/token/IERC2612.sol";
import {ERC20Permit} from "lib/yield-utils-v2/contracts/token/ERC20Permit.sol";
import {IERC20Metadata} from "lib/yield-utils-v2/contracts/token/IERC20Metadata.sol";
import {ICauldron} from "lib/vault-v2/packages/foundry/contracts/interfaces/ICauldron.sol";
import {ILadle} from "lib/vault-v2/packages/foundry/contracts/interfaces/ILadle.sol";
import {IFYToken} from "lib/vault-v2/packages/foundry/contracts/interfaces/IFYToken.sol";
import {IPool} from "lib/yieldspace-tv/src/interfaces/IPool.sol";
import {IStrategy} from "lib/strategy-v2/contracts/interfaces/IStrategy.sol";
import {CastBytes32Bytes6} from "lib/yield-utils-v2/contracts/cast/CastBytes32Bytes6.sol";
import {CastU256I128} from "lib/yield-utils-v2/contracts/cast/CastU256I128.sol";
import {TestConstants} from "./TestConstants.sol";
import {TestExtensions} from "./TestExtensions.sol";

import {Strategy} from "lib/strategy-v2/contracts/Strategy.sol";

/// @dev This test harness tests that basic functions on the Ladle are functional.

abstract contract ZeroState is Test, TestConstants, TestExtensions {
    using stdStorage for StdStorage;
    using CastBytes32Bytes6 for bytes32;

    ICauldron cauldron;
    ILadle ladle;

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
        ladle = ILadle(addresses[network][LADLE]);
        vm.label(address(ladle), "ladle");

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
            vm.label(address(ilkJoin), "ilkJoin");
            baseJoin = IJoin(ladle.joins(baseId));
            vm.label(address(baseJoin), "baseJoin");
            pool = IPool(ladle.pools(seriesId));

            fyTokenUnit = 10 ** IERC20Metadata(address(fyToken)).decimals();
            ilkUnit = 10 ** IERC20Metadata(address(ilk)).decimals();
            baseUnit = 10 ** IERC20Metadata(address(base)).decimals();
            poolUnit = 10 ** IERC20Metadata(address(pool)).decimals();

            matchStrategy = (address(strategy.fyToken()) == address(fyToken));
        }
    }
}

contract ZeroStateTest is ZeroState {
    using CastU256I128 for uint256;

    /*//////////////////////////////////////////////////////////////
    /// VAULT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    // Build a vault
    function testBuildVault() public canSkip {
        vm.prank(user);
        (bytes12 vaultId,) = ladle.build(seriesId, ilkId, 0);
        assertEq(cauldron.vaults(vaultId).owner, user);
    }

    // Destroy a vault
    function testDestoryVault() public canSkip {
        vm.startPrank(user);
        (bytes12 vaultId,) = ladle.build(seriesId, ilkId, 0);
        assertEq(cauldron.vaults(vaultId).owner, user);
        ladle.destroy(vaultId);
        assertEq(cauldron.vaults(vaultId).owner, address(0));
        vm.stopPrank();
    }

    // Merge two vaults into one
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
        vm.startPrank(user);
        (bytes12 vaultId1,) = ladle.build(seriesId, ilkId, 0);
        ladle.pour(vaultId1, user, posted.i128(), borrowed.i128());
        vm.stopPrank();

        // Build second vault
        vm.startPrank(user);
        (bytes12 vaultId2,) = ladle.build(seriesId, ilkId, 0);
        ladle.pour(vaultId2, other, posted.i128(), borrowed.i128());
        vm.stopPrank();

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

    // Split a vault into two
    function testSplitVaults() public canSkip {
        // Get borrowed amount
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec);
        borrowed = borrowed == 0 ? baseUnit : borrowed;

        // Get posted amount
        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = (2 * borrowValue * spot.ratio) / 1e6;

        // Approve amounts for users
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ilkJoin), posted);

        // Build vault
        vm.startPrank(user);
        (bytes12 vaultId,) = ladle.build(seriesId, ilkId, 0);
        ladle.pour(vaultId, user, posted.i128(), borrowed.i128());
        vm.stopPrank();

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

    /*//////////////////////////////////////////////////////////////
    /// COLLATERAL AND BORROWING
    //////////////////////////////////////////////////////////////*/

    // Post ERC20 collateral ????
    function testBuildPour() public canSkip {
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

    // Post ERC20 collateral and borrow underlyiung ????
    function testBuildServe() public canSkip {
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

    /*//////////////////////////////////////////////////////////////
    /// DEBT REPAYMENT
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
    /// LENDING
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
    /// LIQUIDITY PROVIDING
    //////////////////////////////////////////////////////////////*/

    // Provide liquidity by borrowing
    function testProvideLiquidityByBorrowing() public canSkip {

    }

    // Provide liquidity by borrowing, using only underlying
    function testProvideLiquidityWithUnderlying() public canSkip {}

    // Provide liquidity by buying
    function testProvideLiquidityByBuying() public canSkip {}

    // Remove liquidity and repay
    function testRemoveLiquidityAndRepay() public canSkip {}

    // Remove liquidity, repay and sell
    function testRemoveLiquidityRepaySell() public canSkip {}

    // Remove liquidity and redeem
    function testRemoveLiquidityAndRedeem() public canSkip {}

    // Remove liquidity and sell
    function testRemoveLiquidityAndSell() public canSkip {}

    // Roll liquidity before maturity
    function testRollLiquidity() public canSkip {}

    /*//////////////////////////////////////////////////////////////
    /// STRATEGIES
    //////////////////////////////////////////////////////////////*/

    // Provide liquidity to strategy by borrowing
    function testProvideLiquidityToStrategyByBorrowing() public canSkip {
        borrowAndPool(user, baseUnit);
    }

    function borrowAndPool(address guy, uint256 totalBase) public {
        // ladle.batch([
        //   ladle.transfer(base, baseJoin, baseToFYToken),
        //   ladle.transfer(base, pool, baseToPool),
        //   ladle.pour(0, pool, baseToFYToken, baseToFYToken),
        //   ladle.route(pool, ['mint', [strategy, receiver, minRatio, maxRatio]),
        //   ladle.route(strategy, ['mint', [receiver]),
        // ])

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

    // Provide liquidity to strategy by buying
    function testProvideLiquidityToStrategyByBuying() public canSkip {}

    // Remove liquidity from strategy
    function testRemoveLiquidityFromStrategy() public canSkip {}

    // Remove liquidity from deprecated strategy
    function testRemoveLiquidityFromDeprecatedStrategy() public canSkip {}

    /*//////////////////////////////////////////////////////////////
    /// ETHER
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
    /// ERC1155
    //////////////////////////////////////////////////////////////*/
}

abstract contract WithStrategyTokens is ZeroState {
    function setUp() public override {}
}
