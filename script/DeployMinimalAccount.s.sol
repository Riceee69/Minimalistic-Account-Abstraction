//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MinimalAccount} from "src/Ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployMinimalAccount is Script {
    function run() public returns (MinimalAccount, address, address, IERC20) {
        return deploy();
    }

    function deploy() public returns (MinimalAccount, address, address, IERC20) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address entryPoint,
            address deployer,
            address usdc
        ) = helperConfig.networkConfig();

        vm.startBroadcast(deployer);
        MinimalAccount minimalAccount = new MinimalAccount(entryPoint);
        //console.log(minimalAccount.owner());
        vm.stopBroadcast();

        return (minimalAccount, entryPoint, deployer, IERC20(usdc));
    }
}
