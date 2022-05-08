// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20 {
  /// @notice Deposit ETH to WETH
  function deposit() external payable;
  /// @notice WETH balance
  function balanceOf(address holder) external returns (uint256);
  /// @notice ERC20 Spend approval
  function approve(address spender, uint256 amount) external returns (bool);
  function mint(address _account, uint256 _amount) external;
  /// @notice ERC20 transferFrom
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
  function transfer(address to, uint256 amount) external returns (bool);
  function totalSupply() external view returns (uint256);
}
