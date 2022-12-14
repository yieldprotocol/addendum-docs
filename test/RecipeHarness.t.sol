// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import { IERC20 } from "@yield-protocol/utils-v2/contracts/token/IERC20.sol";
import { IERC2612 } from "@yield-protocol/utils-v2/contracts/token/IERC2612.sol";
import { ERC20Permit } from "@yield-protocol/utils-v2/contracts/token/ERC20Permit.sol";
import { IERC20Metadata } from "@yield-protocol/utils-v2/contracts/token/IERC20Metadata.sol";
import "@yield-protocol/vault-v2/contracts/interfaces/DataTypes.sol";
import { ICauldron } from "@yield-protocol/vault-v2/contracts/interfaces/ICauldron.sol";
import { ILadle } from "@yield-protocol/vault-v2/contracts/interfaces/ILadle.sol";
import { IFYToken } from "@yield-protocol/vault-v2/contracts/interfaces/IFYToken.sol";
import { CastBytes32Bytes6 } from "@yield-protocol/utils-v2/contracts/cast/CastBytes32Bytes6.sol";
import { TestConstants } from "./TestConstants.sol";
import { TestExtensions } from "./TestExtensions.sol";

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

    uint256 fyTokenUnit;
    uint256 ilkUnit;
    uint256 baseUnit;

    bytes[] batch;

    bool ilkEnabled; // Skip tests if the ilk is not enabled for the series
    bool ilkInCauldron; // Skip tests if the ilk is not in the cauldron

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

        seriesId = vm.envOr(SERIES_ID, bytes32(0)).b6();
        ilkId = vm.envOr(ILK_ID, bytes32(0)).b6();
        baseId = cauldron.series(seriesId).baseId;

        ilkInCauldron = cauldron.assets(ilkId) != address(0);
        ilkEnabled = cauldron.ilks(seriesId, ilkId);

        if (ilkInCauldron && ilkEnabled) {
            fyToken = IFYToken(cauldron.series(seriesId).fyToken);
            ilk = IERC20(cauldron.assets(ilkId));
            base = IERC20(cauldron.assets(baseId));

            fyTokenUnit = 10 ** IERC20Metadata(address(fyToken)).decimals();
            ilkUnit = 10 ** IERC20Metadata(address(ilk)).decimals();
            baseUnit = 10 ** IERC20Metadata(address(base)).decimals();
        }
    }
}

contract ZeroStateTest is ZeroState {
    function testBuildVault() public canSkip {
        vm.prank(user);
        (bytes12 vaultId,) = ladle.build(seriesId, ilkId, 0);
        assertEq(cauldron.vaults(vaultId).owner, user);
    }

    function testBuildPour() public canSkip {
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec); // We borrow `dust`
        borrowed = borrowed == 0 ? baseUnit : borrowed; // If dust is 0 (ETH/ETH), we borrow 1 base unit

        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = 2 * borrowValue * spot.ratio / 1e6; // We collateralize to twice the bare minimum. TODO: Collateralize to the minimum
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ladle), posted);


        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, ilkId, 0));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, ilk, address(ladle.joins(ilkId)), posted));
        batch.push(abi.encodeWithSelector(ladle.pour.selector, bytes12(0), address(0), posted, borrowed));
        
        vm.prank(user);
        ladle.batch(batch);
    }


    function testBuildServe() public canSkip {
        DataTypes.Debt memory debt = cauldron.debt(baseId, ilkId);
        uint256 borrowed = debt.min * (10 ** debt.dec); // We borrow `dust` but in base, which always will be a bit more than `dust`
        borrowed = borrowed == 0 ? baseUnit : borrowed; // If dust is 0 (ETH/ETH), we borrow 1 base unit

        DataTypes.SpotOracle memory spot = cauldron.spotOracles(baseId, ilkId);
        (uint256 borrowValue,) = spot.oracle.peek(baseId, ilkId, borrowed);
        uint256 posted = 2 * borrowValue * spot.ratio / 1e6; // We collateralize to twice the bare minimum. TODO: Collateralize to the minimum
        cash(ilk, user, posted);
        vm.prank(user);
        ilk.approve(address(ladle), posted);

        batch.push(abi.encodeWithSelector(ladle.build.selector, seriesId, ilkId, 0));
        batch.push(abi.encodeWithSelector(ladle.transfer.selector, ilk, address(ladle.joins(ilkId)), posted));
        batch.push(abi.encodeWithSelector(ladle.serve.selector, bytes12(0), address(0), uint128(posted), uint128(borrowed), type(uint128).max));
        
        vm.prank(user);
        ladle.batch(batch);
    }
}
