//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    ////////////////////////////////
    // Errors
    ////////////////////////////////
    error HelperConfig__UnsupportedChainId();

    ////////////////////////////////
    // Types
    ////////////////////////////////
    struct NetworkConfig {
        address entryPoint;
        address deployer;
        address usdc;
    }

    ////////////////////////////////
    // State Variables
    ////////////////////////////////
    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ARBITRUM_MAINNET_CHAIN_ID = 42_161;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant ZKSYNC_MAINNET_CHAIN_ID = 324;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    address constant BURNER_WALLET = 0x08269F3fE9A2A2C694Ab2E6A6d833F3d010C9865;
    address constant ANVIL_DEFAULT_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public networkConfig;

    ////////////////////////////////
    // Functions
    ////////////////////////////////
    constructor() {
        networkConfig = getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == ETH_MAINNET_CHAIN_ID) {
            return getEthMainnetConfig();
        } else if (chainId == ARBITRUM_MAINNET_CHAIN_ID) {
            return getArbitrumMainnetConfig();
        } else if (chainId == ZKSYNC_SEPOLIA_CHAIN_ID) {
            return getZkSynceSepoliaConfig();
        } else if (chainId == ZKSYNC_MAINNET_CHAIN_ID) {
            return getZkSynceMainnetConfig();
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__UnsupportedChainId();
        }
    }

    ////////////////////////////////
    // Config Functions
    ////////////////////////////////  
    function getEthMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
            deployer: BURNER_WALLET,
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
        });
    }

    function getArbitrumMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
            deployer: BURNER_WALLET,
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
        });
    }

    function getZkSynceSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0),
            deployer: BURNER_WALLET,
            usdc: 0x5A7d6b2F92C77FAD6CCaBd7EE0624E64907Eaf3E //not the real USDC on zksync sepolia
        });
    }

    function getZkSynceMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0),
            deployer: BURNER_WALLET,
            usdc: 0x5A7d6b2F92C77FAD6CCaBd7EE0624E64907Eaf3E //not the real USDC on zksync sepolia
        });
    } 

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        //deploy a mock entry point 
        vm.startBroadcast(ANVIL_DEFAULT_WALLET);
        EntryPoint mockEntryPoint = new EntryPoint();
        ERC20Mock mockUsdc = new ERC20Mock();
        vm.stopBroadcast();

        return NetworkConfig({
            entryPoint: address(mockEntryPoint),
            deployer: ANVIL_DEFAULT_WALLET,
            usdc: address(mockUsdc)
        });
    }
}