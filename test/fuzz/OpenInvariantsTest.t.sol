// // SPDX-License-Identifier: MIT

// // Have our invariant aka properties

// // What are our invariants?

// // 1. The total supply of DSC should be less than the total value of the collateral
// // 2. Getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.18;

// import {Test, console} from "lib/forge-std/src/Test.sol";
// import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import "lib/forge-std/src/console.sol";

// contract OpenInvariantsTest is StdInvariant, Test {
//     DeployDSC _deployer;
//     DSCEngine _dsce;
//     DecentralizedStableCoin _dsc;
//     HelperConfig _config;
//     address _weth;
//     address _wbtc;

//     function setUp() external {
//         _deployer = new DeployDSC();
//         (_dsc, _dsce, _config) = _deployer.run();
//         (, , _weth, _wbtc, ) = _config.activeNetworkConfig();
//         targetContract(address(_dsce));
//     }

//     function invariantProtocolMustHaveMoreValueThanTotalSupply() public view {
//         // get the value of all the collateral in the protocol
//         // compare it to all of the debt (dsc)
//         uint256 totalSupply = _dsc.totalSupply();
//         uint256 totalWethDeposited = IERC20(_weth).balanceOf(address(_dsce));
//         uint256 totalBtcDeposited = IERC20(_wbtc).balanceOf(address(_dsce));

//         uint256 wethValue = _dsce.getUsdValue(_weth, totalWethDeposited);
//         uint256 wbtcValue = _dsce.getUsdValue(_wbtc, totalBtcDeposited);

//         console.log("weth value: ", wethValue);
//         console.log("wbtc value: ", wbtcValue);
//         console.log("total supply: ", totalSupply);

//         assert(wethValue + wbtcValue >= totalSupply);
//     }
// }
