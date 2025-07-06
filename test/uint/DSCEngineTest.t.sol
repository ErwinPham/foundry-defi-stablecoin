//SPDX-License-Identifer: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address weth;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;

    address public SATORI = makeAddr("satori");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 100 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    address public liquidator = makeAddr("liquidator");
    uint256 public constant COLLATERAL_TO_COVER = 20 ether;

    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount);

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(SATORI, STARTING_ERC20_BALANCE);
    }

    modifier depositedCollater() {
        vm.startPrank(SATORI);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedCollaterAndMintDsc() {
        vm.startPrank(SATORI);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                Constructor Test                                      //
    //////////////////////////////////////////////////////////////////////////////////////////

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function testRevertIfTokenLengthNotMatchPriceFeed() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                Price Test                                            //
    //////////////////////////////////////////////////////////////////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 acutalAmount = dsce.getUsdValue(weth, ethAmount);

        assert(expectedUsd == acutalAmount);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 amount = 100e18;
        uint256 expectedValue = 0.05e18;

        assertEq(expectedValue, dsce.getTokenAmountFromUsd(weth, amount));
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                              Deposit Collateral Test                                 //
    //////////////////////////////////////////////////////////////////////////////////////////

    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(SATORI);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testUnapprovalCollateral() public {
        ERC20Mock fake = new ERC20Mock("fake", "fake", SATORI, AMOUNT_COLLATERAL);
        vm.startPrank(SATORI);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(fake), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfor() public depositedCollater {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(SATORI);
        uint256 expectedCollateralValueInUsd = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(AMOUNT_COLLATERAL, expectedCollateralValueInUsd);
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                        Deposit Collateral & Mint DSC Test                            //
    //////////////////////////////////////////////////////////////////////////////////////////

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        uint256 amountCollateral = 1 ether;
        uint256 amountToMint = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
        vm.startPrank(SATORI);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        console.log(amountCollateral); //1000000000000000000 (1e18)
        console.log(amountToMint); //20.000,000000000000000000 (20000e18)
        vm.expectRevert();
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    function testCanMintWithDepositedCollateral() public depositedCollaterAndMintDsc {
        uint256 userBalance = dsc.balanceOf(SATORI);
        assertEq(userBalance, AMOUNT_TO_MINT);
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                   Mint DSC Test                                      //
    //////////////////////////////////////////////////////////////////////////////////////////

    function testRevertIfAmountMintIsZero() public depositedCollater {
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
    }

    function testCanMintDsc() public depositedCollater {
        vm.prank(SATORI);
        dsce.mintDsc(AMOUNT_TO_MINT);
        uint256 userBalance = dsc.balanceOf(SATORI);
        console.log(AMOUNT_TO_MINT);
        console.log(userBalance);
        assertEq(AMOUNT_TO_MINT, userBalance);
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                   Burn DSC Test                                      //
    //////////////////////////////////////////////////////////////////////////////////////////

    function testRevertsIfBurnAmountIsZero() public depositedCollaterAndMintDsc {
        vm.prank(SATORI);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(SATORI);
        vm.expectRevert();
        dsce.burnDsc(100);
    }

    function testCanBurnDsc() public depositedCollaterAndMintDsc {
        vm.startPrank(SATORI);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.burnDsc(AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(SATORI);
        uint256 userDebt = dsce.getDebtOfUser(SATORI);

        assertEq(userBalance, 0);
        assertEq(userDebt, 0);
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                              Redeem Collateral Test                                  //
    //////////////////////////////////////////////////////////////////////////////////////////

    function testRevertsIfRedeemAmountIsZero() public depositedCollater {
        vm.startPrank(SATORI);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollater {
        uint256 amountToRedeem = 5 ether;
        uint256 amoutToMint = 1 ether;
        vm.startPrank(SATORI);
        dsce.mintDsc(amoutToMint);
        dsce.redeemCollateral(weth, amountToRedeem);

        uint256 userCollateral = dsce.getUserCollateralAmount(SATORI, weth);
        assertEq(userCollateral, AMOUNT_COLLATERAL - amountToRedeem);
        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                       Redeem Collateral For DSC Test                                 //
    //////////////////////////////////////////////////////////////////////////////////////////

    function testMustRedeemMoreThanZero() public depositedCollaterAndMintDsc {
        vm.startPrank(SATORI);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateralForDsc(weth, 0, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public depositedCollaterAndMintDsc {
        vm.startPrank(SATORI);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(SATORI);
        uint256 userCollateral = dsce.getUserCollateralAmount(SATORI, weth);
        assertEq(userBalance, 0);
        assertEq(userCollateral, 0);
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                Health Factor Test                                    //
    //////////////////////////////////////////////////////////////////////////////////////////

    function testProperlyReportsHealthFactor() public depositedCollaterAndMintDsc {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = dsce.getHealthFactor(SATORI);
        // $100 minted with $20,000 collateral at 50% liquidation threshold
        // means that we must have $200 collatareral at all times.
        // 20,000 * 0.5 = 10,000
        // 10,000 / 100 = 100 health factor
        assertEq(healthFactor, expectedHealthFactor);
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                Liquidation Test                                      //
    //////////////////////////////////////////////////////////////////////////////////////////

    modifier liquidated() {
        vm.startPrank(SATORI);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();

        int256 ethUsdUpdatedPrice = 15e8; // 1 ETH = $15
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = dsce.getHealthFactor(SATORI);

        ERC20Mock(weth).mint(liquidator, COLLATERAL_TO_COVER);
        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_TO_COVER);
        dsce.depositCollateralAndMintDsc(weth, COLLATERAL_TO_COVER, AMOUNT_TO_MINT);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.liquidate(weth, SATORI, AMOUNT_TO_MINT); // liquidator is covering their whole debt
        vm.stopPrank();
        _;
    }

    function testCantLiquidateGoodHealthFactor() public depositedCollaterAndMintDsc {
        ERC20Mock(weth).mint(liquidator, COLLATERAL_TO_COVER);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_TO_COVER);
        dsce.depositCollateralAndMintDsc(weth, COLLATERAL_TO_COVER, AMOUNT_TO_MINT);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorIsOk.selector);
        dsce.liquidate(weth, SATORI, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 expectedRewardCollaterall = dsce.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT)
            + ((dsce.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT) * 10) / 100);

        uint256 userBalance = ERC20Mock(weth).balanceOf(liquidator);
        assertEq(userBalance, expectedRewardCollaterall);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        uint256 amountCollateralLost = dsce.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT)
            + ((dsce.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT) * 10) / 100);

        uint256 amountCollateralLostInUsd = dsce.getUsdValue(weth, amountCollateralLost);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(SATORI);

        assertEq(dsce.getUsdValue(weth, AMOUNT_COLLATERAL) - amountCollateralLostInUsd, collateralValueInUsd);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDebt,) = dsce.getAccountInformation(liquidator);
        assertEq(liquidatorDebt, AMOUNT_TO_MINT);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userDscMinted,) = dsce.getAccountInformation(SATORI);
        assertEq(userDscMinted, 0);
    }
}
