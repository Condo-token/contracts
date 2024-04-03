// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Condo} from "../src/Condo.sol";

contract CordoScript is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");
        address account = vm.addr(privateKey);

        address UNISWAP_V2_ROUTER02 = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
        address treasuryWallet = 0xA128253b76d15c3e17d494B03656cCF1ccf50dE4;
        uint256 threshold = 1_000_000 * 1e18;
        vm.broadcast();
        Condo token = new Condo(UNISWAP_V2_ROUTER02, treasuryWallet, threshold);
        vm.stopBroadcast();
    }
}
