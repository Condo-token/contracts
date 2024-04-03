// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Condo} from "../src/Condo.sol";
import {UNISWAP_V2_ROUTER02} from "test/utils/constant_eth.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";

contract CondoTest is Test {
    Condo public condoToken;
    address owner = makeAddr("owner");

    address investor1 = address(0x10);
    address investor2 = address(0x11);

    address treasuryWallet = address(0x2); // Treasury Wallet address

    uint256 totalSupply = 10_000_000_000 * 1e18;
    uint256 threshold = 1_000_000 * 1e18; // Example threshold

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    IUniswapV2Router02 uniswapV2Router;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        uniswapV2Router = IUniswapV2Router02(UNISWAP_V2_ROUTER02);

        condoToken = new Condo(UNISWAP_V2_ROUTER02, treasuryWallet, threshold);

        condoToken.approve(UNISWAP_V2_ROUTER02, type(uint256).max);

        uniswapV2Router.addLiquidityETH{value: totalSupply / 4}(
            address(condoToken),
            totalSupply / 4,
            0,
            0,
            owner,
            block.timestamp
        );

        uint256 totalbalance = condoToken.balanceOf(address(this));
        condoToken.transfer(owner, totalbalance);
    }

    function test_initialization() public view {
        assertEq(condoToken.balanceOf(owner), (totalSupply * 3) / 4);
        assertEq(address(condoToken.uniswapV2Router()), UNISWAP_V2_ROUTER02);
        assertEq(condoToken.treasuryWallet(), treasuryWallet);
        assertEq(condoToken.buyFee(), 3);
        assertEq(condoToken.sellFee(), 3);
    }

    function test_RevertInitialization() public {
        vm.expectRevert("Condo: Invalid uniswapV2 router address");
        new Condo(address(0), treasuryWallet, threshold);

        vm.expectRevert("Condo: Invalid treasury wallet address");
        new Condo(UNISWAP_V2_ROUTER02, address(0), threshold);

        vm.expectRevert("Condo: Invalid threshold amount");
        new Condo(UNISWAP_V2_ROUTER02, treasuryWallet, 0);
    }

    function test_transfer() public {
        uint256 amount = 600_000 ether;

        vm.prank(owner);
        condoToken.transfer(investor1, amount);
        vm.prank(owner);
        condoToken.transfer(investor2, amount);

        assertEq(condoToken.balanceOf(investor1), amount);
        assertEq(condoToken.balanceOf(investor2), amount);
    }

    function testRevertTransfer() public {
        uint256 amount = 600_000 ether;

        vm.prank(owner);
        vm.expectRevert();
        condoToken.transfer(address(0), amount);
    }

    function test_SwapEthForTokens() public {
        uint256 ethAmount = 600_000 ether;

        assertEq(condoToken.balanceOf(address(condoToken)), 0);

        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(condoToken);

        vm.deal(investor1, ethAmount);
        vm.prank(investor1);
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: 200_000 ether
        }(0, path, investor1, block.timestamp);

        assertLe(condoToken.balanceOf(investor1), 200_000 ether);
        assertLe(
            condoToken.balanceOf(address(condoToken)),
            (200_000 ether * 3) / 100
        );

        assertEq(condoToken.balanceOf(address(treasuryWallet)), 0);

        vm.deal(investor2, ethAmount);
        vm.prank(investor2);
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: 1 ether
        }(0, path, investor2, block.timestamp);

        assertEq(condoToken.balanceOf(address(treasuryWallet)), 0);
        assertLe(treasuryWallet.balance, (200_000 ether * 3) / 100);
    }

    function testFuzz_SwapEthForTokens(
        address account,
        uint256 ethAmount
    ) public {
        vm.assume(ethAmount >= 0.001 ether && ethAmount < 10 ether);
        vm.assume(account != address(0));

        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(condoToken);

        vm.deal(account, ethAmount);
        vm.prank(account);
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount
        }(0, path, account, block.timestamp);
    }

    function testFuzz_SwapTokensForEthFuzz(
        address account,
        uint256 tokenAmount
    ) public {
        vm.assume(account != address(0));
        vm.assume(tokenAmount > 1 ether && tokenAmount <= totalSupply / 2);

        vm.prank(owner);
        condoToken.transfer(account, tokenAmount);

        address[] memory path = new address[](2);
        path[0] = address(condoToken);
        path[1] = uniswapV2Router.WETH();

        vm.prank(account);
        condoToken.approve(UNISWAP_V2_ROUTER02, type(uint256).max);
        vm.prank(account);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            account,
            block.timestamp
        );
    }
}
