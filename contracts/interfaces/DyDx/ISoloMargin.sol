// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../libraries/DyDx/DataStructures.sol";


interface ISoloMargin {
  /// @notice Flashloan operate from dYdX
  function operate(
    Account.Info[] memory accounts, Actions.ActionArgs[] memory actions
  ) external;
}
