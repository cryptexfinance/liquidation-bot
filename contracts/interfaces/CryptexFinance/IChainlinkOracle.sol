pragma solidity ^0.8.13;

interface IChainlinkOracle {
    function getLatestAnswer() external view returns (uint256);
}
