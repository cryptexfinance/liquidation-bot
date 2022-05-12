// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface AggregatorInterfaceTCAP {

  function latestAnswer() external view  returns (int256);

  function latestRoundData()
    external
    view
    returns (
      uint80,
      int256,
      uint256,
      uint256,
      uint80
    );

  function setLatestAnswer(int256 _tcap) external;
}
