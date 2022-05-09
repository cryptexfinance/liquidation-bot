// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/utils/Counters.sol";

interface ITCAPVault {
    function counter() external view returns (Counters.Counter calldata);
    function ratio() external view returns (uint256);
    function createVault() external;
    function addCollateral(uint256 _amount) external payable;
    function addCollateralETH() external payable;
    function removeCollateral(uint256 _amount) external;
    function mint(uint256 _amount) external payable;
    function burn(uint256 _amount) external payable;
    function liquidateVault(uint256 _vaultId, uint256 _maxTCAP) external payable;
    function liquidationReward(uint256 _vaultId) external view returns (uint256);
    function requiredCollateral(uint256 _amount) external view returns (uint256);
    function requiredLiquidationTCAP(uint256 _vaultId) external view returns (uint256);
    function getVaultRatio(uint256 _vaultId) external view returns (uint256);
    function getFee(uint256 _amount) external view returns (uint256);
}
