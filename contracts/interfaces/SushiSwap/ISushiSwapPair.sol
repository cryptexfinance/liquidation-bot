// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../IERC20.sol";

interface ISushiSwapPair is IERC20 {
    function getReserves() external view returns
        (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function mint(address to) external returns (uint liquidity);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}
