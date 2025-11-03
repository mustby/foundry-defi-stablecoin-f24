// SPDX-License-Identifier: MIT

// Have our invariant aka properties

// What are our invariants?

// 1. The total supply of DSC should be less than the total value of the collateral
// 2. Getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC _deployer;
    DSCEngine _dsce;
    DecentralizedStableCoin _dsc;
    HelperConfig _config;
    address _weth;
    address _wbtc;
    Handler _handler;

    function setUp() external {
        _deployer = new DeployDSC();
        (_dsc, _dsce, _config) = _deployer.run();
        (,, _weth, _wbtc,) = _config.activeNetworkConfig();
        // targetContract(address(_dsce));
        _handler = new Handler(_dsce, _dsc);
        targetContract(address(_handler));
        // hey, don't call redeemCollateral, unless there is collateral to redeem --> Handler!
    }

    function invariantProtocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to all of the debt (dsc)
        uint256 totalSupply = _dsc.totalSupply();
        uint256 wethDeposited = IERC20(_weth).balanceOf(address(_dsce));
        uint256 wbtcDeposited = IERC20(_wbtc).balanceOf(address(_dsce));

        uint256 wethValue = _dsce.getUsdValue(_weth, wethDeposited);
        uint256 wbtcValue = _dsce.getUsdValue(_wbtc, wbtcDeposited);

        console.log("weth value: ", wethValue);
        console.log("wbtc value: ", wbtcValue);
        console.log("total supply: ", totalSupply);
        console.log("Times mint is called: ", _handler.timesMintIsCalled());

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariantGettersShouldNotRevert() public view {
        _dsce.getLiquidationBonus();
        _dsce.getPrecision();
    } // this is a freebie test to run...absolute layup!
}
