// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ISushiSwapRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB)
        external
        pure
        returns
        (uint amountB);

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        external
        pure
        returns (uint amountOut);

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        external
        pure
        returns (uint amountIn);

    function getAmountsOut(uint amountIn, address[] memory path)
        external
        view
        returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, address[] memory path)
        external
        view
        returns (uint[] memory amounts);

}
