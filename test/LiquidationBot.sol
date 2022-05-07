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
    Vm public VM;
    IChainlinkOracle wethOracle;
    IChainlinkOracle tcapOracle;
    ITCAPVault wethTCAPVault;
    IERC20 TCAP;
    IERC20 WETH;
    ISushiSwapFactory sushiSwapFactory;
    ISushiSwapRouter sushiSwapRouter;
    /// @notice WETH oracle address on kovan
    address constant wethOracleAddress = 0x19BD8B7CFC53f904E78e4bbEb51Fa8230452C20e;
    /// @notice TCAP oracle address on kovan
    address constant tcapOracleAddress = 0x15A149958B48dC899FB005e38ef9C1445A1CB6E3;
    /// @notice WETH TCAP vault address on kovan
    address constant wethTCAPVaultAddress = 0x8c1ddF1522cb5C7b5851Cc1C7E01b572ca123390;
    /// @notice TCAP address on kovan
    address constant TCAPAddress = 0x044d9B591Ef70DbF2260b46a036044705D4f6705;
    /// @notice SushiSwap factory address on kovan
    address constant sushiSwapFactoryAddress = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
    /// @notice SushiSwap router address on kovan
    address constant sushiSwapRouterAddress = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    /// @notice DyDx ISoloMargin address on kovan
    address constant SoloMarginAddress = 0x4EC3570cADaAEE08Ae384779B0f3A45EF85289DE;

    address constant wethAddress = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;

    uint256 constant tcapDivisor = 10000000000;

    address constant user = address (0x01);

    function setUp() public {
        VM = Vm(HEVM_ADDRESS);
        wethOracle = IChainlinkOracle(wethOracleAddress);
        tcapOracle = IChainlinkOracle(tcapOracleAddress);
        wethTCAPVault = ITCAPVault(wethTCAPVaultAddress);
        TCAP = IERC20(TCAPAddress);
        WETH = IERC20(wethAddress);
        sushiSwapFactory = ISushiSwapFactory(sushiSwapFactoryAddress);
        sushiSwapRouter = ISushiSwapRouter(sushiSwapRouterAddress);
    }

    function liquidationSetup() internal {
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

    function createVaultForLiquidation() internal {
        vm.startPrank(user);
        vm.deal(user, 1000 ether);
        wethTCAPVault.createVault();
        uint256 tcapTOMint = 30 ether;
		wethTCAPVault.addCollateralETH{value : wethTCAPVault.requiredCollateral(tcapTOMint) + 1 wei}();
		wethTCAPVault.mint(tcapTOMint);
        vm.stopPrank();
    }

    function testFlashLoan() public {
        LiquidateVault bot = new LiquidateVault(
            wethAddress,
            TCAPAddress,
            SoloMarginAddress,
            sushiSwapRouterAddress
        );
        createVaultForLiquidation();
        liquidationSetup();
        assertEq(WETH.balanceOf(address(bot)), 0);
        bot.initiateFlashLoan(wethTCAPVaultAddress, 1);
        assertTrue(WETH.balanceOf(address(bot)) > 0);
    }
}
