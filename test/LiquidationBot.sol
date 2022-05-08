// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "../contracts/LiquidateVault.sol";
import "../contracts/interfaces/CryptexFinance/IChainlinkOracle.sol";
import "../contracts/interfaces/SushiSwap/ISushiSwapFactory.sol";
import "../contracts/interfaces/SushiSwap/ISushiSwapRouter.sol";
import "../contracts/interfaces/SushiSwap/ISushiSwapPair.sol";

contract LiquidationBotTest is Test {
    /// @notice WETH oracle address on kovan
    address constant wethOracleAddress = 0x0bEcDdb66CF39A275500fDFaeFeE1d222835409b;
    /// @notice TCAP oracle address on kovan
    address constant tcapOracleAddress = 0x56F8be0f4cc9AA0775f4bA11AFcA0fcD84733800;
    /// @notice TCAP oracle address on kovan
    address constant daiOracleAddress = 0x5aFA13275d27007dBB65471F8d717cA9C36b92e5;
    /// @notice WETH TCAP vault address on kovan
    address constant wethTCAPVaultAddress = 0x5543c16e5105ED1Da34e68b07C5888262e3AAbf8;
    /// @notice DAI TCAP vault address on kovan
    address constant daiTCAPVaultAddress = 0xcF33394e2E6598BfB4e832077a4A79638E396F17;
    /// @notice TCAP address on kovan
    address constant TCAPAddress = 0xFEB4D2ffA65FF94C4E532d0e59a06Db132432b81;
    /// @notice SushiSwap factory address on kovan
    address constant sushiSwapFactoryAddress = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
    /// @notice SushiSwap router address on kovan
    address constant sushiSwapRouterAddress = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    /// @notice DyDx ISoloMargin address on kovan
    address constant SoloMarginAddress = 0x4EC3570cADaAEE08Ae384779B0f3A45EF85289DE;
    /// @notice WETH9 address on kovan
    address constant wethAddress = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    /// @notice DAI address on kovan deployed by cryptex.finance
    address constant daiAddress = 0x9f8abf6e69C465bB432CA36F99C198c896a703BD;

    uint256 constant tcapDivisor = 10000000000;

    address constant user = address (0x01);

    Vm public VM;
    IChainlinkOracle wethOracle;
    IChainlinkOracle tcapOracle;
    IChainlinkOracle daiOracle;
    ITCAPVault wethTCAPVault;
    ITCAPVault daiTCAPVault;
    IERC20 TCAP;
    IERC20 WETH;
    IERC20 DAI;
    ISushiSwapFactory sushiSwapFactory;
    ISushiSwapRouter sushiSwapRouter;

    function setUp() public {
        VM = Vm(HEVM_ADDRESS);
        wethOracle = IChainlinkOracle(wethOracleAddress);
        tcapOracle = IChainlinkOracle(tcapOracleAddress);
        daiOracle = IChainlinkOracle(daiOracleAddress);
        wethTCAPVault = ITCAPVault(wethTCAPVaultAddress);
        daiTCAPVault = ITCAPVault(daiTCAPVaultAddress);
        TCAP = IERC20(TCAPAddress);
        WETH = IERC20(wethAddress);
        DAI = IERC20(daiAddress);
        sushiSwapFactory = ISushiSwapFactory(sushiSwapFactoryAddress);
        sushiSwapRouter = ISushiSwapRouter(sushiSwapRouterAddress);
    }

    function liquidationSetupForETHVault() internal {
        vm.deal(address(this), 3000 ether);
        uint ethUSD = wethOracle.getLatestAnswer();
        uint tcapUSD = tcapOracle.getLatestAnswer() / tcapDivisor;
        uint256 tcapTOMint = 2000 ether;
//        mint TCAP
        wethTCAPVault.createVault();
		wethTCAPVault.addCollateralETH{value : wethTCAPVault.requiredCollateral(tcapTOMint) + 1 wei}();
		wethTCAPVault.mint(tcapTOMint);
//      85 % drop from previous price
        uint256 newETHPrice = (85 * ethUSD)/100 ;
//      Mock Oracle price.
        vm.mockCall(
            wethOracleAddress,
            abi.encodeWithSelector(wethOracle.getLatestAnswer.selector),
            abi.encode(newETHPrice)
        );
//        Add Liquidity on SushiSwap at new price
        address pair = sushiSwapFactory.createPair(TCAPAddress, wethAddress);
        uint ethAmount = (tcapTOMint * tcapUSD) / newETHPrice;
        TCAP.approve(pair, type(uint256).max);
        TCAP.transfer(pair, tcapTOMint);
        WETH.deposit{value: 1000 ether}();
        WETH.approve(pair, type(uint256).max);
        WETH.approve(address(sushiSwapRouter), type(uint256).max);
        WETH.transfer(pair,  ethAmount);
        ISushiSwapPair sushiSwapPair = ISushiSwapPair(pair);
        sushiSwapPair.mint(address(this));
    }

    function createETHVaultForLiquidation() internal {
        vm.startPrank(user);
        vm.deal(user, 1000 ether);
        wethTCAPVault.createVault();
        uint256 tcapTOMint = 30 ether;
		wethTCAPVault.addCollateralETH{value : wethTCAPVault.requiredCollateral(tcapTOMint) + 1 wei}();
		wethTCAPVault.mint(tcapTOMint);
        vm.stopPrank();
    }

    function testTHVaultLiquidationProfitable() public {
        // setup
        createETHVaultForLiquidation();
        liquidationSetupForETHVault();
        LiquidateVault bot = new LiquidateVault(
            wethAddress,
            TCAPAddress,
            SoloMarginAddress,
            sushiSwapRouterAddress
        );
        // begin test
        assertEq(WETH.balanceOf(address(bot)), 0);
        bot.initiateFlashLoan(wethTCAPVaultAddress, 1, new address[](0));
        assertTrue(WETH.balanceOf(address(bot)) > 0);
    }

    function liquidationSetupForDAIVault() internal {
        vm.deal(address(this), 300000 ether);
        uint daiUSD = daiOracle.getLatestAnswer();
        uint tcapUSD = tcapOracle.getLatestAnswer() / tcapDivisor;
        uint256 tcapTOMint = 2000 ether;
        uint256 daiAmount = (10 * tcapUSD * tcapTOMint) / daiUSD;
        DAI.mint(address(this), daiAmount);
        DAI.approve(daiTCAPVaultAddress, type(uint256).max);
//        mint TCAP
        daiTCAPVault.createVault();
		daiTCAPVault.addCollateral(
            daiTCAPVault.requiredCollateral(tcapTOMint) + 1 wei
        );
		daiTCAPVault.mint(tcapTOMint);
//      15 % increase from previous price
        uint256 newTCAPPrice = (115 * tcapOracle.getLatestAnswer())/100 ;
//      Mock Oracle price.
        vm.mockCall(
            tcapOracleAddress,
            abi.encodeWithSelector(tcapOracle.getLatestAnswer.selector),
            abi.encode(newTCAPPrice)
        );
//        Add TCAP/WETH Liquidity on SushiSwap
        address pair = sushiSwapFactory.createPair(TCAPAddress, wethAddress);
        uint ethUSD = wethOracle.getLatestAnswer();
        uint ethAmount = (tcapTOMint * tcapUSD) / ethUSD;
        TCAP.approve(pair, type(uint256).max);
        TCAP.transfer(pair, tcapTOMint);
        WETH.deposit{value: 1000 ether}();
        WETH.approve(pair, type(uint256).max);
        WETH.approve(address(sushiSwapRouter), type(uint256).max);
        WETH.transfer(pair,  ethAmount);
        ISushiSwapPair(pair).mint(address(this));

//      Add WETH/DAI liquidity on Sushiswap
        pair = sushiSwapFactory.createPair(daiAddress, wethAddress);
        daiAmount = 1000000 ether;
        DAI.mint(address(this), daiAmount);
        ethAmount = (daiAmount * daiUSD) / ethUSD;
        DAI.approve(pair, type(uint256).max);
        DAI.transfer(pair, daiAmount);
        WETH.deposit{value: ethAmount}();
        WETH.approve(pair, type(uint256).max);
        WETH.approve(address(sushiSwapRouter), type(uint256).max);
        WETH.transfer(pair,  ethAmount);
        ISushiSwapPair(pair).mint(address(this));
    }

    function createDAIVaultForLiquidation() internal {
        vm.startPrank(user);
        daiTCAPVault.createVault();
        uint256 tcapTOMint = 30 ether;
        uint collateralRequired = daiTCAPVault.requiredCollateral(tcapTOMint) + 1 wei;
        DAI.mint(user, collateralRequired);
        DAI.approve(daiTCAPVaultAddress, type(uint256).max);
		daiTCAPVault.addCollateral(collateralRequired);
		daiTCAPVault.mint(tcapTOMint);
        vm.stopPrank();
    }

    function testDAILiquidationProfitable() public {
        createDAIVaultForLiquidation();
        liquidationSetupForDAIVault();
        LiquidateVault bot = new LiquidateVault(
            wethAddress,
            TCAPAddress,
            SoloMarginAddress,
            sushiSwapRouterAddress
        );
        // begin test
        assertEq(WETH.balanceOf(address(bot)), 0);
        address[] memory path = new address[](2);
        path[0] = daiAddress;
        path[1] = wethAddress;
        bot.initiateFlashLoan(daiTCAPVaultAddress, 1, path);
        assertTrue(WETH.balanceOf(address(bot)) > 0);
    }
}
