// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import "lib/forge-std/src/console.sol";

contract DSCEngineTest is Test {
    event CollateralRedeemed(
        address indexed redeemFrom,
        address indexed redeemTo,
        address token,
        uint256 amount
    );

    DeployDSC public deployer;
    DecentralizedStableCoin public dsc;
    DSCEngine public dsce;
    HelperConfig public config;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;

    address public liquidator = makeAddr("liquidator");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    uint256 _amountCollateral = 10 ether;
    uint256 _amountToMint = 100 ether;
    address public user = address(1);

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, , ) = config
            .activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
    }

    /////////////////////////////
    // Constructor Tests  ///////
    /////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength
                .selector
        );
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////////////////
    // Price Tests  /////////////
    /////////////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;

        // 15e18 * 2000/ETH = 30,000e18;

        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////////////
    // Deposit Collateral Tests //////
    //////////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock(
            "RAN",
            "RAN",
            user,
            AMOUNT_COLLATERAL
        );
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo()
        public
        depositedCollateral
    {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce
            .getAccountInformation(user);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(
            weth,
            collateralValueInUsd
        );
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testCanDepositCollateralWithoutMinting()
        public
        depositedCollateral
    {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    // // this test needs it's own setup
    // function testRevertsIfTransferFromFails() public {
    //     // Arrange - Setup
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
    //     tokenAddresses = [address(mockDsc)];
    //     feedAddresses = [ethUsdPriceFeed];
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(
    //         tokenAddresses,
    //         feedAddresses,
    //         address(mockDsc)
    //     );
    //     mockDsc.mint(user, _amountCollateral);

    //     vm.prank(owner);
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(address(mockDsc)).approve(
    //         address(mockDsce),
    //         _amountCollateral
    //     );
    //     // Act / Assert
    //     vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
    //     mockDsce.depositCollateral(address(mockDsc), _amountCollateral);
    //     vm.stopPrank();
    // }

    //////////////////////////////////
    // Self Directed Tests ///////////
    //////////////////////////////////

    function testDeployment() public view {
        // Ensure collateral tokens and price feeds are correctly initialized
        assertEq(dsce.getCollateralTokens().length, 2);
        assertEq(dsce.getPriceFeed(weth), ethUsdPriceFeed);
    }

    function testRevertsIfDepositMoreThanBalance() public {
        vm.startPrank(user);

        // Approve more than balance (which is 10 ether)
        uint256 excessiveAmount = 20 ether;
        ERC20Mock(weth).approve(address(dsce), excessiveAmount);

        // Expect revert due to insufficient balance
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        dsce.depositCollateral(weth, excessiveAmount);

        vm.stopPrank();
    }

    // Full PC Tests Below //

    ////////////////////////////////////////
    // depositCollateralAndMintDsc Tests ///
    ////////////////////////////////////////

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price, , , ) = MockV3Aggregator(ethUsdPriceFeed)
            .latestRoundData();
        _amountToMint =
            (_amountCollateral *
                (uint256(price) * dsce.getAdditionalFeedPrecision())) /
            dsce.getPrecision();
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), _amountCollateral);

        uint256 expectedHealthFactor = dsce.calculateHealthFactor(
            _amountToMint,
            dsce.getUsdValue(weth, _amountCollateral)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                expectedHealthFactor
            )
        );
        dsce.depositCollateralAndMintDsc(
            weth,
            _amountCollateral,
            _amountToMint
        );
        vm.stopPrank();
    }
    // this test didn't work - why?
    modifier depositCollateralAndMintDsc() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), _amountCollateral);
        dsce.depositCollateralAndMintDsc(
            weth,
            _amountCollateral,
            _amountToMint
        );
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral()
        public
        depositCollateralAndMintDsc
    {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, _amountToMint);
    }

    ///////////////////////////////////
    // mintDsc Tests //////////////////
    ///////////////////////////////////

    // This test needs it's own custom setup
    // function testRevertsIfMintFails() public {
    //     // Arrange - Setup
    //     MockFailedMintDSC mockDsc = new MockFailedMintDSC();
    //     tokenAddresses = [weth];
    //     feedAddresses = [ethUsdPriceFeed];
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(
    //         tokenAddresses,
    //         feedAddresses,
    //         address(mockDsc)
    //     );
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(mockDsce), amountCollateral);

    //     vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
    //     mockDsce.depositCollateralAndMintDsc(
    //         weth,
    //         amountCollateral,
    //         _amountToMint
    //     );
    //     vm.stopPrank();
    // }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), _amountCollateral);
        dsce.depositCollateralAndMintDsc(
            weth,
            _amountCollateral,
            _amountToMint
        );
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor()
        public
        depositedCollateral
    {
        // 0xe580cc6100000000000000000000000000000000000000000000000006f05b59d3b20000
        // 0xe580cc6100000000000000000000000000000000000000000000003635c9adc5dea00000
        (, int256 price, , , ) = MockV3Aggregator(ethUsdPriceFeed)
            .latestRoundData();
        _amountToMint =
            (_amountCollateral *
                (uint256(price) * dsce.getAdditionalFeedPrecision())) /
            dsce.getPrecision();

        vm.startPrank(user);
        uint256 expectedHealthFactor = dsce.calculateHealthFactor(
            _amountToMint,
            dsce.getUsdValue(weth, _amountCollateral)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                expectedHealthFactor
            )
        );
        dsce.mintDsc(_amountToMint);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositedCollateral {
        vm.prank(user);
        dsce.mintDsc(_amountToMint);

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, _amountToMint);
    }

    ///////////////////////////////////
    // burnDsc Tests //////////////////
    ///////////////////////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), _amountCollateral);
        dsce.depositCollateralAndMintDsc(
            weth,
            _amountCollateral,
            _amountToMint
        );
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        dsce.burnDsc(1);
    }

    // This test fails!
    function testCanBurnDsc() public depositCollateralAndMintDsc {
        vm.startPrank(user);
        dsc.approve(address(dsce), _amountToMint);
        dsce.burnDsc(_amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    // redeemCollateral Tests /////////
    ///////////////////////////////////

    // this test needs it's own setup
    // function testRevertsIfTransferFails() public {
    //     // Arrange - Setup
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     MockFailedTransfer mockDsc = new MockFailedTransfer();
    //     tokenAddresses = [address(mockDsc)];
    //     feedAddresses = [ethUsdPriceFeed];
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
    //     mockDsc.mint(user, _amountCollateral);

    //     vm.prank(owner);
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(address(mockDsc)).approve(address(mockDsce), _amountCollateral);
    //     // Act / Assert
    //     mockDsce.depositCollateral(address(mockDsc), _amountCollateral);
    //     vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
    //     mockDsce.redeemCollateral(address(mockDsc), _amountCollateral);
    //     vm.stopPrank();
    // }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), _amountCollateral);
        dsce.depositCollateralAndMintDsc(
            weth,
            _amountCollateral,
            _amountToMint
        );
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        dsce.redeemCollateral(weth, _amountCollateral);
        uint256 userBalance = ERC20Mock(weth).balanceOf(user);
        assertEq(userBalance, _amountCollateral);
        vm.stopPrank();
    }

    // // This function test failed...log != expected log...COME BACK TO THIS...at the end of the project?
    // function testEmitCollateralRedeemedWithCorrectArgs()
    //     public
    //     depositedCollateral
    // {
    //     vm.expectEmit(true, true, true, true, address(dsce));
    //     emit CollateralRedeemed(user, user, weth, _amountCollateral);
    //     vm.startPrank(user);
    //     dsce.redeemCollateral(weth, _amountCollateral);
    //     vm.stopPrank();
    // }

    ///////////////////////////////////
    // redeemCollateralForDsc Tests //
    //////////////////////////////////

    function testMustRedeemMoreThanZero() public depositCollateralAndMintDsc {
        vm.startPrank(user);
        dsc.approve(address(dsce), _amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateralForDsc(weth, 0, _amountToMint);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), _amountCollateral);
        dsce.depositCollateralAndMintDsc(
            weth,
            _amountCollateral,
            _amountToMint
        );
        dsc.approve(address(dsce), _amountToMint);
        dsce.redeemCollateralForDsc(weth, _amountCollateral, _amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ////////////////////////
    // healthFactor Tests //
    ////////////////////////

    function testProperlyReportsHealthFactor()
        public
        depositCollateralAndMintDsc
    {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = dsce.getHealthFactor(user);
        // $100 minted with $20,000 collateral at 50% liquidation threshold
        // means that we must have $200 collatareral at all times.
        // 20,000 * 0.5 = 10,000
        // 10,000 / 100 = 100 health factor
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne()
        public
        depositCollateralAndMintDsc
    {
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        // Rememeber, we need $200 at all times if we have $100 of debt

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = dsce.getHealthFactor(user);
        // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
        // 0.9
        assert(userHealthFactor == 0.9 ether);
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    // // This test needs it's own setup
    // function testMustImproveHealthFactorOnLiquidation() public {
    //     // Arrange - Setup
    //     MockMoreDebtDSC mockDsc = new MockMoreDebtDSC(ethUsdPriceFeed);
    //     tokenAddresses = [weth];
    //     feedAddresses = [ethUsdPriceFeed];
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(mockDsce), _amountCollateral);
    //     mockDsce.depositCollateralAndMintDsc(weth, _amountCollateral, _amountToMint);
    //     vm.stopPrank();

    //     // Arrange - Liquidator
    //     collateralToCover = 1 ether;
    //     ERC20Mock(weth).mint(liquidator, collateralToCover);

    //     vm.startPrank(liquidator);
    //     ERC20Mock(weth).approve(address(mockDsce), collateralToCover);
    //     uint256 debtToCover = 10 ether;
    //     mockDsce.depositCollateralAndMintDsc(weth, collateralToCover, _amountToMint);
    //     mockDsc.approve(address(mockDsce), debtToCover);
    //     // Act
    //     int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
    //     // Act/Assert
    //     vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
    //     mockDsce.liquidate(weth, user, debtToCover);
    //     vm.stopPrank();
    // }

    // function testCantLiquidateGoodHealthFactor()
    //     public
    //     depositCollateralAndMintDsc
    // {
    //     ERC20Mock(weth).mint(liquidator, collateralToCover);

    //     vm.startPrank(liquidator);
    //     ERC20Mock(weth).approve(address(dsce), collateralToCover);
    //     dsce.depositCollateralAndMintDsc(
    //         weth,
    //         collateralToCover,
    //         _amountToMint
    //     );
    //     dsc.approve(address(dsce), _amountToMint);

    //     vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
    //     dsce.liquidate(weth, user, _amountToMint);
    //     vm.stopPrank();
    // }

    // modifier liquidated() {
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(dsce), _amountCollateral);
    //     dsce.depositCollateralAndMintDsc(
    //         weth,
    //         _amountCollateral,
    //         _amountToMint
    //     );
    //     vm.stopPrank();
    //     int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
    //     uint256 userHealthFactor = dsce.getHealthFactor(user);

    //     ERC20Mock(weth).mint(liquidator, collateralToCover);

    //     vm.startPrank(liquidator);
    //     ERC20Mock(weth).approve(address(dsce), collateralToCover);
    //     dsce.depositCollateralAndMintDsc(
    //         weth,
    //         collateralToCover,
    //         _amountToMint
    //     );
    //     dsc.approve(address(dsce), _amountToMint);
    //     dsce.liquidate(weth, user, _amountToMint); // We are covering their whole debt
    //     vm.stopPrank();
    //     _;
    // }

    // function testLiquidationPayoutIsCorrect() public liquidated {
    //     uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidated);
    //     uint256 expectedWeth = dsce.getTokenAmountFromUsd(
    //         weth,
    //         _amountToMint
    //     ) +
    //         (dsce.getTokenAmountFromUsd(weth, _amountToMint) /
    //             dsce.getLiquidationBonus());
    //     uint256 hardCodedExpected = 6_111_111_111_111_111_110;
    //     assertEq(liquidatorWethBalance, hardCodedExpected);
    //     assertEq(liquidatorWethBalance, expectedWeth);
    // }

    // function testUserStillHasSomeEthAfterLiquidation() public liquidated {
    //     // Get how much WETH the user lost
    //     uint256 amountLiquidated = dsce.getTokenAmountFromUsd(
    //         weth,
    //         _amountToMint
    //     ) +
    //         (dsce.getTokenAmountFromUsd(weth, _amountToMint) /
    //             dsce.getLiquidationBonus());

    //     uint256 usdAmountLiquidated = dsce.getUsdValue(
    //         weth,
    //         amountLiquidated
    //     );
    //     uint256 expectedUserCollateralValueInUsd = dsce.getUsdValue(
    //         weth,
    //         _amountCollateral
    //     ) - (usdAmountLiquidated);

    //     (, uint256 userCollateralValueInUsd) = dsce.getAccountInformation(
    //         user
    //     );
    //     uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
    //     assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
    //     assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    // }

    // function testLiquidatorTakesOnUsersDebt() public liquidated {
    //     (uint256 liquidatorDscMinted, ) = dsce.getAccountInformation(
    //         liquidated
    //     );
    //     assertEq(liquidatorDscMinted, amountToMint);
    // }

    // function testUserHasNoMoreDebt() public liquidated {
    //     (uint256 userDscMinted, ) = dsce.getAccountInformation(user);
    //     assertEq(userDscMinted, 0);
    // }
}
