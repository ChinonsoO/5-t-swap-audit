//SPDX-License-Identifiers: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {

    //These pools have 2 assests.
    ERC20Mock poolToken;
    ERC20Mock weth;
    
    Handler handler;

    PoolFactory factory;
    TSwapPool pool; // pooltoken/WETH

    int256 constant starting_X = 100e18; //starting poolToken
    int256 constant starting_Y = 50e18; //starting Weth

    function setUp() public {
        weth = new ERC20Mock();
        poolToken = new ERC20Mock();
        factory = new PoolFactory(address(weth));
        pool = TSwapPool(factory.createPool(address(poolToken)));

        //create initial x&y balances to jumpstart poool;

        poolToken.mint(address(this), uint256(starting_X));
        weth.mint(address(this), uint256(starting_Y));

        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        pool.deposit(uint256(starting_Y), uint256(starting_X), uint256(starting_X) , uint64(block.timestamp));

        handler = new Handler(pool);
        bytes4[] memory selectors = new bytes4[](2);

        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.swapPoolTokenForWethBasedOnOutputWeth.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));


    }

    function statefulFuzz_constantProductForumlaStaysTheSame() public {
        //assert()?;

        //The change in the pool size of weth should follow this function. How do we do this?
        // ∆x = (β/(1-β)) * x
        // solution - In a handler create a var for delta X and make sure == (β/(1-β)) * x

        // assertEq(handler.actualDeltaX(), handler.expectedDelta_X());
        assertEq(handler.actualDeltaY(), handler.expectedDelta_Y());


    }
}