// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/console2.sol";

import {Cast}                   from "lib/yield-utils-v2/src/utils/Cast.sol";

import {DataTypes}              from "lib/vault-v2/src/interfaces/DataTypes.sol";

import {IERC20}                 from "lib/yield-utils-v2/src/token/IERC20.sol";
import {IERC20Metadata}         from "lib/yield-utils-v2/src/token/IERC20Metadata.sol";
import {IERC2612}               from "lib/yield-utils-v2/src/token/IERC2612.sol";
import {ERC20Permit}            from "lib/yield-utils-v2/src/token/ERC20Permit.sol";

import {IOracle}                from "lib/vault-v2/src/interfaces/IOracle.sol";
import {ICauldron}              from "lib/vault-v2/src/interfaces/ICauldron.sol";
import {IFYToken}               from "lib/vault-v2/src/interfaces/IFYToken.sol";
import {IJoin}                  from "lib/vault-v2/src/interfaces/IJoin.sol";
import {ILadle}                 from "lib/vault-v2/src/interfaces/ILadle.sol";
import {RepayFromLadleModule}   from "lib/vault-v2/src/modules/RepayFromLadleModule.sol";
import {WrapEtherModule}        from "lib/vault-v2/src/modules/WrapEtherModule.sol";
import {Transfer1155Module}     from "lib/vault-v2/src/other/notional/Transfer1155Module.sol";
import {ERC1155}                from "lib/vault-v2/src/other/notional/ERC1155.sol";

import {IPool}                  from "lib/yieldspace-tv/src/interfaces/IPool.sol";
import {Pool}                   from "lib/yieldspace-tv/src/Pool/Pool.sol";
import {IStrategy}              from "lib/strategy-v2/src/interfaces/IStrategy.sol";
import {Strategy}               from "lib/strategy-v2/src/Strategy.sol";

import {HarnessStorage}         from "./HarnessStorage.sol";

using Cast for uint256;
using Cast for uint128;
using Cast for bytes32;

/// @dev This test harness tests that basic functions on the Ladle are functional.

abstract contract ZeroState is HarnessStorage {


    function setUp() public virtual {
        string memory rpc = vm.envOr(RPC, HARNESS);
        vm.createSelectFork(rpc);

        string memory network = vm.envOr(NETWORK, MAINNET);

        cauldron = ICauldron(addresses[network][CAULDRON]);
        ladle = ILadle(addresses[network][LADLE]);

        seriesId = vm.envOr(SERIES_ID, bytes32(0)).b6();
        baseId = cauldron.series(seriesId).baseId;

        pool = IPool(ladle.pools(seriesId));
        fyToken = IFYToken(address(pool.fyToken()));
        base = IERC20(address(pool.baseToken()));
        shares = IERC20(address(pool.sharesToken()));

        _labels();

        fyTokenUnit = 10 ** IERC20Metadata(address(fyToken)).decimals();
        baseUnit = 10 ** IERC20Metadata(address(base)).decimals();
        sharesUnit = 10 ** IERC20Metadata(address(shares)).decimals();
        poolUnit = 10 ** IERC20Metadata(address(pool)).decimals();
    }

    /*//////////////////////
    /// HELPER FUNCTIONS ///
    //////////////////////*/

    function _labels() internal {
        vm.label(address(cauldron), "cauldron");
        vm.label(address(ladle), "ladle");
        vm.label(address(fyToken), "fyToken");
        vm.label(address(base), "base");
        vm.label(address(pool), "pool");
    }

    function _convert(bytes6 baseId, bytes6 quoteId, uint256 amountBase) internal view returns (uint256 amountQuote) {
        IOracle oracle = cauldron.spotOracles(baseId, quoteId).oracle;

        // The cauldron won't necessarily have a pair and its reverse, but the underlying oracle should.
        if (oracle == IOracle(address(0))) oracle = cauldron.spotOracles(quoteId, baseId).oracle;
        (amountQuote,) = oracle.peek(baseId, quoteId, amountBase);
    }

    function _addLiquidity(bytes6 denomination, uint256 amount) internal {
        uint256 baseIn = _convert(denomination, baseId, amount);

        // We get the reserves, assuming they don't differ much from the cache.
        // We can work in base, since it will be converted internally.
        uint256 baseReserves = pool.getBaseBalance();
        uint256 fyTokenReserves = pool.getFYTokenBalance() - pool.totalSupply();

        // We calculate the expected amount of fyToken needed
        uint256 fyTokenIn = fyTokenReserves * baseIn / baseReserves;

        // Transfer the base and fyToken to the pool. Transfer a 10% more base than needed, to avoid rounding issues.
        cash(base, address(pool), baseIn * 11 / 10);
        cash(fyToken, address(pool), fyTokenIn);

        // We add liquidity
        pool.mint(user, user, 0, type(uint256).max);
    }

    function _sellFYToken(bytes6 denomination, uint256 amount) internal {
        uint256 fyTokenIn = _convert(denomination, baseId, amount); // We are approximating the fyToken price to 1:1

        // We sell fyToken
        cash(fyToken, address(pool), fyTokenIn);
        pool.sellFYToken(user, 0);
    }

    function _sellBase(bytes6 denomination, uint256 amount) internal {
        uint256 baseIn = _convert(denomination, baseId, amount);

        // We sell base
        cash(base, address(pool), baseIn);
        pool.sellBase(user, 0);
    }
}

contract ZeroStateTest is ZeroState {

    // Test that the pool is not mature
    function testPoolIsNotMature() public {
        assertTrue(pool.maturity() > block.timestamp);
    }

    // Test that the pool has been initialized
    function testPoolIsInitialized() public {
        assertTrue(pool.totalSupply() > 0);
    }

    // Test that the pool has base
    function testPoolHasBase() public {
        assertTrue(pool.getBaseBalance() > 0);
    }

    // Test that the pool has shares
    function testPoolHasShares() public {
        assertTrue(pool.getSharesBalance() > 0);
    }

    // Test that the pool has fyToken
    function testPoolHasFYToken() public {
        assertTrue(pool.getFYTokenBalance() - pool.totalSupply() > 0);
    }

    // Log out the max base in
    function testMaxBaseIn() public {
        uint256 maxBaseIn = pool.maxBaseIn(); // If this fails, selling a tiny amount of fyToken to the pool should fix it
        console2.log("maxBaseIn: ", maxBaseIn);
    }

    // Log out the max fyToken out
    function testMaxFYTokenOut() public {
        uint256 maxFYTokenOut = pool.maxFYTokenOut(); // If this fails, selling a tiny amount of fyToken to the pool should fix it
        console2.log("maxFYTokenOut: ", maxFYTokenOut);
    }
    
    // Test that we can add liquidity
    function testAddLiquidity() public {

        // We will test adding the equivalent of 1 ETH in liquidity
        uint256 baseIn = _convert(ETH, baseId, 1e18);

        // We get the reserves, assuming they don't differ much from the cache.
        // We can work in base, since it will be converted internally.
        uint256 baseReserves = pool.getBaseBalance();
        uint256 fyTokenReserves = pool.getFYTokenBalance() - pool.totalSupply();

        // We calculate the expected amount of shares to receive
        uint256 expectedShares = pool.totalSupply() * baseIn / baseReserves;

        // We calculate the expected amount of fyToken needed
        uint256 fyTokenIn = fyTokenReserves * baseIn / baseReserves;

        // Transfer the base and fyToken to the pool. Transfer a 10% more base than needed, to avoid rounding issues.
        cash(base, address(pool), baseIn * 11 / 10);
        cash(fyToken, address(pool), fyTokenIn);

        // We add liquidity
        pool.mint(user, user, 0, type(uint256).max);

        // We check that the user received the expected amount of shares, which is baseIn + fyTokenIn ± 10%
        assertApproxEqRel(pool.balanceOf(user), expectedShares, 1e17);
    }

    // Test that we can remove liquidity
    function testRemoveLiquidity() public {
        uint256 userBase = base.balanceOf(user);
        uint256 userFYToken = fyToken.balanceOf(user);
        uint256 sharesIn = pool.totalSupply() / 2;
        cash(IERC20(address(pool)), address(pool), sharesIn);

        // We remove liquidity
        pool.burn(user, user, 0, type(uint256).max);

        // We check that the user received the expected amount of base and fyToken, which is sharesIn ± 10%
        assertApproxEqRel(base.balanceOf(user) + fyToken.balanceOf(user) - userBase - userFYToken, sharesIn, 1e17);
    }

    // Test that we can sell $5K of fyToken
    function testSell5KFYToken() public {

        // We will test selling the equivalent of 5K DAI in fyToken
        uint256 fyTokenIn = _convert(DAI, baseId, 5e21); // We are approximating the fyToken price to 1:1

        // We sell fyToken
        cash(fyToken, address(pool), fyTokenIn);
        pool.sellFYToken(user, 0);

        // We check that the user received the expected amount of base, which is fyTokenIn ± 10%
        assertApproxEqRel(base.balanceOf(user), fyTokenIn, 1e17);
    }

    // Test that we can buy $5K of fyToken
    function testBuy5KFYToken() public {

        // We will test buying the equivalent of 5K DAI in fyToken
        uint128 baseIn = _convert(DAI, baseId, 5e21).u128();
        uint128 fyTokenOut = baseIn; // fyToken are worth equal or less than underlying, so we should have enough

        // We buy fyToken
        cash(base, address(pool), baseIn);
        pool.buyFYToken(user, fyTokenOut, type(uint128).max);

        // We check that the user received the expected amount of fyToken, which is fyTokenOut ± 10%
        assertApproxEqRel(fyToken.balanceOf(user), fyTokenOut, 1e17);
    }
}

// Increase liquidity to $1M
abstract contract WithLiquidity is ZeroState {
    function setUp() public virtual override {
        super.setUp();
        
        _addLiquidity(DAI, 1e24);
    }
}

contract WithLiquidityTest is WithLiquidity {

    // Test that we can sell $5K of fyToken
    function testSell5KFYTokenWithLiquidity() public {
        uint userBaseToken = base.balanceOf(user);

        // We will test selling the equivalent of 5K DAI in fyToken
        uint256 fyTokenIn = _convert(DAI, baseId, 5e21); // We are approximating the fyToken price to 1:1

        // We sell fyToken
        cash(fyToken, address(pool), fyTokenIn);
        pool.sellFYToken(user, 0);

        // We check that the user received the expected amount of base, which is fyTokenIn ± 10%
        assertApproxEqRel(base.balanceOf(user) - userBaseToken, fyTokenIn, 1e17);
    }

    // Test that we can buy $5K of fyToken
    function testBuy5KFYTokenWithLiquidity() public {
        uint userFYToken = fyToken.balanceOf(user);

        // We will test buying the equivalent of 5K DAI in fyToken
        uint128 baseIn = _convert(DAI, baseId, 5e21).u128();
        uint128 fyTokenOut = baseIn; // fyToken are worth equal or less than underlying, so we should have enough

        // We buy fyToken
        cash(base, address(pool), baseIn);
        pool.buyFYToken(user, fyTokenOut, type(uint128).max);

        // We check that the user received the expected amount of fyToken, which is fyTokenOut ± 10%
        assertApproxEqRel(fyToken.balanceOf(user) - userFYToken, fyTokenOut, 1e17);
    }
}

// Increase interest rate to 5%
abstract contract AtFivePercent is WithLiquidity {
    function setUp() public virtual override {
        super.setUp();
        
        // We will sell to the pool a 5% of its base reserves in fyToken
        uint256 fyTokenIn = pool.getBaseBalance() / 20;

        // Transfer the fyToken to the pool.
        cash(fyToken, address(pool), fyTokenIn);

        // Sell
        pool.sellFYToken(user, 0);
    }
}

contract AtFivePercentTest is AtFivePercent {

    // Test that we can sell $5K of fyToken
    function testSell5KFYTokenAtFivePercent() public {
        uint userBaseToken = base.balanceOf(user);

        // We will test selling the equivalent of 5K DAI in fyToken
        uint256 fyTokenIn = _convert(DAI, baseId, 5e21); // We are approximating the fyToken price to 1:1

        // We sell fyToken
        cash(fyToken, address(pool), fyTokenIn);
        pool.sellFYToken(user, 0);

        // We check that the user received the expected amount of base, which is fyTokenIn ± 10%
        assertApproxEqRel(base.balanceOf(user) - userBaseToken, fyTokenIn, 1e17);
    }

    // Test that we can buy $5K of fyToken
    function testBuy5KFYTokenAtFivePercent() public {
        uint userFYToken = fyToken.balanceOf(user);

        // We will test buying the equivalent of 5K DAI in fyToken
        uint128 baseIn = _convert(DAI, baseId, 5e21).u128();
        uint128 fyTokenOut = baseIn; // fyToken are worth equal or less than underlying, so we should have enough

        // We buy fyToken
        cash(base, address(pool), baseIn);
        pool.buyFYToken(user, fyTokenOut, type(uint128).max);

        // We check that the user received the expected amount of fyToken, which is fyTokenOut ± 10%
        assertApproxEqRel(fyToken.balanceOf(user) - userFYToken, fyTokenOut, 1e17);
    }
}