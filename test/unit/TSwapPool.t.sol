// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        weth.mint(liquidityProvider, 200e18);
        poolToken.mint(liquidityProvider, 200e18);

        weth.mint(user, 10e18);
        poolToken.mint(user, 10e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(weth.balanceOf(liquidityProvider) + poolToken.balanceOf(liquidityProvider) > 400e18);
    }

    function test_FundsLockedAfterZeroPoolTokensDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);

        //provide initial liquidity of 100weth and 0 pool tokens.
        pool.deposit(100e18, 100e18, 0, uint64(block.timestamp));


        //assert funds left liquidity provider
        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);

        //assert funds in pool
        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 0);

        pool.approve(address(pool), 100e18);
        
        //Below reverts and funds are locked.
        vm.expectRevert();
        pool.withdraw(100e18, 100e18, 0, uint64(block.timestamp));
        vm.stopPrank();

        //Another user makes deposit
        vm.startPrank(user);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);

        pool.deposit(5e18, 5e18, 5e18, uint64(block.timestamp));

        //assert funds left user
        assertEq(pool.balanceOf(user), 5e18);
        assertEq(weth.balanceOf(user), 5e18);
        assertEq(poolToken.balanceOf(user), 5e18);

        //assert funds in pool
        assertEq(weth.balanceOf(address(pool)), 105e18);
        assertEq(poolToken.balanceOf(address(pool)), 5e18);

        //Reverts and funds are locked.
        vm.expectRevert();
        pool.withdraw(5e18, 5e18, 5e18, uint64(block.timestamp));


        //Another user makes deposit
        vm.startPrank(address(3));
        pool.approve(address(pool), 100e18);
        weth.mint(address(3), 5e18);
        poolToken.mint(address(3), 5e18);

        weth.approve(address(pool), 5e18);
        poolToken.approve(address(pool), 5e18);
        pool.approve(address(pool), 5e18);

        pool.deposit(5e18, 5e18, 5e18, uint64(block.timestamp));

        //assert funds left user
        assertEq(pool.balanceOf(address(3)), 5e18);
        assertEq(weth.balanceOf(address(3)), 0);
        assertEq(poolToken.balanceOf(address(3)), 0);

        //Reverts Users funds are locked,
        vm.expectRevert();
        pool.withdraw(5e18, 5e18, 5e18, uint64(block.timestamp));

        vm.stopPrank();


    }

    
}
