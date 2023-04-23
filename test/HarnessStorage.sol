// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "./HarnessImports.sol";

contract HarnessStorage is Test, TestConstants, TestExtensions {
    ICauldron cauldron;
    ILadle ladle;
    RepayFromLadleModule repayFromLadleModule;
    WrapEtherModule wrapEtherModule;
    Transfer1155Module transfer1155Module;

    uint256 userPrivateKey = 0xBABE;
    address user = vm.addr(userPrivateKey);
    uint256 otherPrivateKey = 0xBEEF;
    address other = vm.addr(otherPrivateKey);

    bytes6 seriesId;
    bytes6 rollSeriesId;
    bytes6 ilkId;
    bytes6 baseId;

    IFYToken fyToken;
    IERC20 ilk;
    IERC20 base;
    IJoin ilkJoin;
    IJoin baseJoin;
    IPool pool;
    IPool oppositePool;
    IStrategy strategy;
    Strategy newStrategy;

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
