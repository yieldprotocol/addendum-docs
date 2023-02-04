// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "lib/forge-std/src/Test.sol";

import {IERC20}                 from "lib/yield-utils-v2/contracts/token/IERC20.sol";

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

contract HarnessStorage is Test, TestConstants, TestExtensions {
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
}
