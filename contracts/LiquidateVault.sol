// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

import "./libraries/DyDx/DataStructures.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/DyDx/ISoloMargin.sol";
import "./interfaces/SushiSwap/ISushiSwapRouter.sol";
import "./interfaces/CryptexFinance/ITCAPVault.sol";


/// @title Liquidate Tcap Vaults
/// @author Cryptex.Finance
/// @notice Liquidates TCAP vaults whose vault ratio is below minimum.
contract LiquidateVault is Ownable {
  IWETH public immutable WETH;
  IERC20 public immutable TCAP;
  ISoloMargin public immutable SOLO_MARGIN;
  ISushiSwapRouter public immutable sushiSwapRouter;
  address immutable WETHAddress;
  address immutable TCAPAddress;

  constructor (
    address _WETHAdress,
    address _TCAPAdress,
    address _SoloMarginAddress,
    address _SushiSwapRouterAddress
  ) {
    WETHAddress = _WETHAdress;
    TCAPAddress = _TCAPAdress;
    WETH = IWETH(WETHAddress);
    TCAP = IERC20(TCAPAddress);
    SOLO_MARGIN = ISoloMargin(_SoloMarginAddress);
    WETH.approve(_SoloMarginAddress, type(uint256).max);
    sushiSwapRouter = ISushiSwapRouter(_SushiSwapRouterAddress);
    WETH.approve(_SushiSwapRouterAddress, type(uint256).max);
  }

  function isLiquidationProfitable(
      address vault,
      uint256 vaultId,
      address[] memory path,
      address[] memory swapPath
  ) public view returns(bool isProfitable) {
    ITCAPVault tcapVault = ITCAPVault(vault);
    uint256 vaultRatio = tcapVault.getVaultRatio(vaultId);
    if (vaultRatio >= tcapVault.ratio()) return false;
    uint256 requiredTCAP = tcapVault.requiredLiquidationTCAP(vaultId);
    uint256 liquidationFee = tcapVault.getFee(requiredTCAP);
    uint256 reward = tcapVault.liquidationReward(vaultId);
    uint256 loanAmount = sushiSwapRouter.getAmountsIn(requiredTCAP, path)[0];
    if (swapPath.length >= 2) {
       reward = sushiSwapRouter.getAmountsOut(
         reward, swapPath
       )[swapPath.length - 1];
    }
    isProfitable = reward >= (loanAmount + liquidationFee + 2 wei);
  }

  /// @notice gets a flashloan from dydx to liquidate the vault
  function initiateFlashLoan(
    address vault,
    uint256 vaultId,
    address[] memory swapPath
  ) external onlyOwner {
    ITCAPVault tcapVault = ITCAPVault(vault);
    address[] memory path = new address[](2);
    path[0] = WETHAddress;
    path[1] = TCAPAddress;
    if(!isLiquidationProfitable(vault, vaultId, path, swapPath)) revert("Liquidation won't be profitable");
    uint256 requiredTCAP = tcapVault.requiredLiquidationTCAP(vaultId);
    uint256 liquidationFee = tcapVault.getFee(requiredTCAP);
    uint[] memory amounts = sushiSwapRouter.getAmountsIn(requiredTCAP, path);
    Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);
    operations[0] = Actions.ActionArgs({
      // Withdraw wETH from dYdX
      actionType: Actions.ActionType.Withdraw,
      accountId: 0,
      amount: Types.AssetAmount({
        sign: false,
        denomination: Types.AssetDenomination.Wei,
        ref: Types.AssetReference.Delta,
        // Of purchase debit amount
        value: amounts[0] + liquidationFee
      }),
      // Wrapped Ether
      primaryMarketId: 0,
      secondaryMarketId: 0,
      otherAddress: address(this),
      otherAccountId: 0,
      data: ""
    });
    operations[1] = Actions.ActionArgs({
      // Execute call function
      actionType: Actions.ActionType.Call,
      accountId: 0,
      amount: Types.AssetAmount({
        sign: false,
        denomination: Types.AssetDenomination.Wei,
        ref: Types.AssetReference.Delta,
        value: 0
      }),
      primaryMarketId: 0,
      secondaryMarketId: 0,
      otherAddress: address(this),
      otherAccountId: 0,
      // Purchase order
      data: abi.encode(requiredTCAP, liquidationFee, vault, vaultId, swapPath)
    });
    operations[2] = Actions.ActionArgs({
      // Deposit Wrapped Ether back to dYdX
      actionType: Actions.ActionType.Deposit,
      accountId: 0,
      amount: Types.AssetAmount({
        sign: true,
        denomination: Types.AssetDenomination.Wei,
        ref: Types.AssetReference.Delta,
        // Loan amount + 2 wei fee
        value: amounts[0] + liquidationFee + 2 wei
      }),
      // Wrapped Ether
      primaryMarketId: 0,
      secondaryMarketId: 0,
      otherAddress: address(this),
      otherAccountId: 0,
      data: ""
    });
    Account.Info[] memory accountInfos = new Account.Info[](1);
    accountInfos[0] = Account.Info({owner: address(this), number: 1});

    // Execute flash loan
    SOLO_MARGIN.operate(accountInfos, operations);
  }

  /// @notice callback called by dydx ISoloMargin
  function callFunction(
    address sender,
    Account.Info memory,
    bytes memory data
  ) external {

    require(
      msg.sender == address(SOLO_MARGIN) && sender == address(this),
      "callFunction: Unauthorized call"
    );

    (
        uint256 requiredTCAP,
        uint256 liquidationFee,
        address vault,
        uint256 vaultId,
        address[] memory swapPath
    ) = abi.decode(data, (uint256, uint256, address, uint256, address[]));

    ITCAPVault tcapVault = ITCAPVault(vault);
    address[] memory path = new address[](2);
    path[0] = WETHAddress;
    path[1] = TCAPAddress;
    sushiSwapRouter.swapTokensForExactTokens(
        requiredTCAP,
        requiredTCAP,
        path,
        address(this),
        block.timestamp
    );
    if(liquidationFee > 0) WETH.withdraw(liquidationFee);
    uint256 reward = tcapVault.liquidationReward(vaultId);
    tcapVault.liquidateVault{value: liquidationFee}(vaultId, requiredTCAP);

    // swap reward for WETH
    if (swapPath.length >= 2) {
      sushiSwapRouter.swapExactTokensForTokens(
        reward,
        0,
        swapPath,
        address(this),
        block.timestamp
      );
    }
  }

  function approve_sushiswap_router(address token) external onlyOwner {
    IERC20(token).approve(address(sushiSwapRouter), type(uint256).max);
  }

  function recoverERC20(address _tokenAddress, uint256 _tokenAmount)
  external
  onlyOwner {
    bool success = IERC20(_tokenAddress).transfer(owner(), _tokenAmount);
	require(success, "recoverERC20: transfer failed");
  }

  function safeTransferETH(uint256 _value) external onlyOwner {
    address _owner = owner();
    (bool success,) = _owner.call{value : _value}(new bytes(0));
    require(success, "safeTransferETH: ETH transfer failed");
  }

  receive() external payable {}
}
