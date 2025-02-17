//SPDX-License-Identifiers: MIT

pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {StdInvariant} from "forge-std/StdInvariant.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";

contract Handler is StdInvariant, Test {

    //These pools have 2 assests. 
    ERC20Mock poolToken;
    ERC20Mock weth;

    PoolFactory factory;
    TSwapPool pool; // pooltoken/WETH

    int256 public expectedDelta_X; //starting poolToken
    int256 public expectedDelta_Y; //starting Weth

    int256 public actualDeltaX;
    int256 public actualDeltaY;


    //Ghost Vars
    int256 public starting_X; //starting poolToken
    int256 public starting_Y; //starting Weth

    address liquidityProvider = makeAddr("lp");
    address user = makeAddr("user");


    constructor (TSwapPool _pool){
        pool = _pool;
        weth = ERC20Mock(_pool.getWeth());
        poolToken = ERC20Mock(_pool.getPoolToken());
    }

   //depost
   function deposit (uint256 wethAmountToDeposit) public {
        //lets make sure our deposit is a reasonable amount
        wethAmountToDeposit = bound(wethAmountToDeposit, pool.getMinimumWethDepositAmount(), type(uint64).max);

        starting_Y = int256(weth.balanceOf(address(pool)));
        starting_X = int256(poolToken.balanceOf(address(pool)));

        expectedDelta_Y = int256(wethAmountToDeposit);
        expectedDelta_X = int256(pool.getPoolTokensToDepositBasedOnWeth(wethAmountToDeposit));

        //LiquidityProvider is the persion adding liquidity, we are simulating a deposit here.
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmountToDeposit);
        poolToken.mint(liquidityProvider, uint256(expectedDelta_X));
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        pool.deposit(wethAmountToDeposit, 0, uint256(expectedDelta_X), uint64(block.timestamp));
        vm.stopPrank();

        //actual
        uint256 ending_Y = weth.balanceOf(address(pool));
        uint256 ending_X = poolToken.balanceOf(address(pool));

        actualDeltaY = int256(ending_Y) - int256(starting_Y);
        actualDeltaX = int256(ending_X) - int256(starting_X);

   }

    //remember outputWeth is how much Weth we're asking for.
   function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {

        if (weth.balanceOf(address(pool)) <= pool.getMinimumWethDepositAmount()) {
            return;
        }

        outputWeth = bound(outputWeth, pool.getMinimumWethDepositAmount(), weth.balanceOf(address(pool)));
        //delta X

        // If these two values are the same, we will divide by 0
        if (outputWeth == weth.balanceOf(address(pool))) {
            return;
        }

        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(outputWeth, poolToken.balanceOf(address(pool)), weth.balanceOf(address(pool)));

        if (poolTokenAmount > type(uint64).max){
            return ;
        }

        starting_Y = int256(weth.balanceOf(address(pool)));
        starting_X = int256(poolToken.balanceOf(address(pool)));

        expectedDelta_Y = int256(-1) * int256(outputWeth);
        expectedDelta_X = int256(poolTokenAmount);

        //swap

        if (poolToken.balanceOf(user) < poolTokenAmount) {
            poolToken.mint(
                user,
                poolTokenAmount - poolToken.balanceOf(user) + 1
            );
        }

        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank();

        uint256 ending_Y = weth.balanceOf(address(pool));
        uint256 ending_X = poolToken.balanceOf(address(pool));

        actualDeltaY = int256(ending_Y) - int256(starting_Y);
        actualDeltaX = int256(ending_X) - int256(starting_X);

   }

   
}