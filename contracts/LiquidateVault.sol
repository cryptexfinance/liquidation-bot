// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./libraries/DyDx/DataStructures.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/DyDx/ISoloMargin.sol";
import "./interfaces/SushiSwap/ISushiSwapRouter.sol";
import "./interfaces/CryptexFinance/ITCAPVault.sol";


/// @title Liquidate Tcap Vaults
/// @author Cryptex.Finance
/// @notice Liquidates TCAP vaults whose vault ratio is below minimum.
contract LiquidateVault {
  IWETH public immutable WETH;
  IERC20 public immutable TCAP;
  ISoloMargin public immutable SOLO_MARGIN;
  ISushiSwapRouter public immutable sushiSwapRouter;
  address immutable WETHAddress;
  address immutable TCAPAddress;
  constructor (address _WETHAdress, address _TCAPAdress) {
    WETHAddress = _WETHAdress;
    TCAPAddress = _TCAPAdress;
    WETH = IWETH(WETHAddress);
    TCAP = IERC20(TCAPAddress);
    SOLO_MARGIN = ISoloMargin(0x4EC3570cADaAEE08Ae384779B0f3A45EF85289DE);
    WETH.approve(address(SOLO_MARGIN), type(uint256).max);
    sushiSwapRouter = ISushiSwapRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    WETH.approve(address(sushiSwapRouter), type(uint256).max);
  }

  function isLiquidationProfitable(
      address vault, uint256 vaultId, address[] memory path
  ) public view returns(bool isProfitable) {
    ITCAPVault tcapVault = ITCAPVault(vault);
    uint256 requiredTCAP = tcapVault.requiredLiquidationTCAP(vaultId);
    uint256 liquidationFee = tcapVault.getFee(requiredTCAP);
    uint256 reward = tcapVault.liquidationReward(vaultId);
    uint256 loanAmount = sushiSwapRouter.getAmountsIn(requiredTCAP, path)[0];
    isProfitable = reward >= (loanAmount + liquidationFee + 2 wei);
  }

  function initiateFlashLoan(address vault, uint256 vaultId) external {
    ITCAPVault tcapVault = ITCAPVault(vault);
    uint256 vaultRatio = tcapVault.getVaultRatio(vaultId);
    if (vaultRatio > tcapVault.ratio()) revert("Vault Cannot be liquidated");
    address[] memory path = new address[](2);
    path[0] = WETHAddress;
    path[1] = TCAPAddress;
    if(!isLiquidationProfitable(vault, vaultId, path)) revert("Liquidation won't be profitable");
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
      data: abi.encode(requiredTCAP, liquidationFee, vault, vaultId)
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

  function callFunction(
    address,
    Account.Info memory,
    bytes memory data
  ) external {
    (
        uint256 requiredTCAP,
        uint256 liquidationFee,
        address vault,
        uint256 vaultID
    ) = abi.decode(data, (uint256, uint256, address, uint256));
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
    tcapVault.liquidateVault{value: liquidationFee}(vaultID, requiredTCAP);
  }

  receive() external payable {}

  fallback() external payable {}
}
