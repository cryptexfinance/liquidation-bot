// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../libraries/DyDx/DataStructures.sol";

import "../interfaces/IWETH.sol";

interface ICalee {

    function callFunction(
        address sender, Account.Info memory, bytes memory data
    ) external;
}

contract MockSoloMargin {

    IWETH public immutable WETH;

    constructor(address WETHAddress) {
        WETH = IWETH(WETHAddress);
    }

    function operate(
        Account.Info[] memory accounts, Actions.ActionArgs[] memory actions
    ) external {
        uint256 beforeBalance = WETH.balanceOf(address(this));
        for (uint256 i = 0; i < actions.length; i++) {
            Actions.ActionArgs memory action = actions[i];
            Actions.ActionType actionType = action.actionType;

            if (actionType == Actions.ActionType.Deposit) {
                _deposit(accounts[0], action);
            }
            else if (actionType == Actions.ActionType.Withdraw) {
                _withdraw(accounts[0], action);
            }
            else  {
                require(actionType == Actions.ActionType.Call, "Undefined Action");
                _call(accounts[0], action);
            }
        }
        uint256 afterBalance = WETH.balanceOf(address(this));
        require(afterBalance >= (beforeBalance + 2 wei), "Loan not paid");
    }

    function _deposit(Account.Info memory account, Actions.ActionArgs memory action) internal {
        WETH.transferFrom(account.owner, address(this), action.amount.value);
    }

    function _withdraw(Account.Info memory account, Actions.ActionArgs memory action) internal {
        WETH.approve(account.owner, action.amount.value);
        WETH.transfer(account.owner, action.amount.value);
    }

    function _call(Account.Info memory account, Actions.ActionArgs memory action) internal {
        ICalee(account.owner).callFunction(
            address(this),
            account,
            action.data
        );
    }

}
