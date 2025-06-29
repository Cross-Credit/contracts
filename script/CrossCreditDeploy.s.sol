// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {CrossCredit} from "../src/CrossCredit.sol";

contract CrossCreditDeploy is Script {
    address public constant AVALANCHE_FUJI_ROUTER = 0xF694E193200268f9a4868e4Aa017A0118C9a8177;
    address public constant ETHEREUM_SEPOLIA_ROUTER = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;

    address public constant AVALANCHE_FUJI_LINK_TOKEN = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;

    address public constant ETHEREUM_SEPOLIA_LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public constant ETH_SEPOLIA_ETH_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant ETH_SEPOLIA_LINK_PRICE_FEED = 0xc59E3633BAAC79493d908e63626716e204A45EdF;

    address public constant AVALANCHE_FUJI_AVAX_PRICE_FEED = 0x5498BB86BC934c8D34FDA08E81D444153d0D06aD;
    address public constant AVALANCHE_FUJI_ETH_PRICE_FEED = 0x86d67c3D38D2bCeE722E601025C25a575021c6EA;
    address public constant AVALANCHE_FUJI_LINK_PRICE_FEED = 0x34C4c526902d88a3Aa98DB8a9b802603EB1E3470;

    uint8 public constant AVALANCHE_FUJI_LINK_TOKEN_DECIMALS = 18;
    uint8 public constant ETHEREUM_SEPOLIA_LINK_TOKEN_DECIMALS = 18;

    uint64 public constant ETH_SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;
    uint64 public constant AVALANCHE_FUJI_CHAIN_SELECTOR = 14767482510784806043;

    CrossCredit public crossCreditOnETHSepolia;
    CrossCredit public crossCreditOnAvalancheFuji;

    function run() public {
        string memory AVALANCHE_FUJI_RPC_URL = vm.envString("AVALANCHE_FUJI_RPC_URL");
        string memory ETHEREUM_SEPOLIA_RPC_URL = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");

        vm.createSelectFork(vm.rpcUrl(ETHEREUM_SEPOLIA_RPC_URL));
        vm.startBroadcast();

        crossCreditOnETHSepolia = new CrossCredit(
            msg.sender, NATIVE_TOKEN, ETHEREUM_SEPOLIA_ROUTER
        );
        crossCreditOnETHSepolia.listAsset(NATIVE_TOKEN, 18);
        crossCreditOnETHSepolia.listAsset(ETHEREUM_SEPOLIA_LINK_TOKEN, ETHEREUM_SEPOLIA_LINK_TOKEN_DECIMALS);
        crossCreditOnETHSepolia.setPriceFeed(NATIVE_TOKEN, ETH_SEPOLIA_ETH_PRICE_FEED);
        crossCreditOnETHSepolia.setPriceFeed(ETHEREUM_SEPOLIA_LINK_TOKEN, ETH_SEPOLIA_LINK_PRICE_FEED);
        crossCreditOnETHSepolia.setConnectedChainID(AVALANCHE_FUJI_CHAIN_SELECTOR);
        crossCreditOnETHSepolia.setAssetToAssetOnConnectedChain(
            ETHEREUM_SEPOLIA_LINK_TOKEN, AVALANCHE_FUJI_LINK_TOKEN, AVALANCHE_FUJI_LINK_TOKEN_DECIMALS
        );

        vm.stopBroadcast();

        vm.createSelectFork(vm.rpcUrl(AVALANCHE_FUJI_RPC_URL));
        vm.startBroadcast();

        crossCreditOnAvalancheFuji = new CrossCredit(
            msg.sender, NATIVE_TOKEN, AVALANCHE_FUJI_ROUTER
        );
        crossCreditOnAvalancheFuji.listAsset(NATIVE_TOKEN, 18);
        crossCreditOnAvalancheFuji.listAsset(AVALANCHE_FUJI_LINK_TOKEN, AVALANCHE_FUJI_LINK_TOKEN_DECIMALS);
        crossCreditOnAvalancheFuji.setPriceFeed(NATIVE_TOKEN, AVALANCHE_FUJI_AVAX_PRICE_FEED);
        crossCreditOnAvalancheFuji.setPriceFeed(AVALANCHE_FUJI_LINK_TOKEN, AVALANCHE_FUJI_LINK_PRICE_FEED);
        crossCreditOnAvalancheFuji.setConnectedChainID(ETH_SEPOLIA_CHAIN_SELECTOR);
        crossCreditOnAvalancheFuji.setAssetToAssetOnConnectedChain(
            AVALANCHE_FUJI_LINK_TOKEN, ETHEREUM_SEPOLIA_LINK_TOKEN, ETHEREUM_SEPOLIA_LINK_TOKEN_DECIMALS
        );
        crossCreditOnAvalancheFuji.setReceiverOnConnectedChain(address(crossCreditOnETHSepolia));

        vm.stopBroadcast();

//        vm.createSelectFork(vm.rpcUrl(ETHEREUM_SEPOLIA_RPC_URL));
//        vm.startBroadcast();
//        crossCreditOnETHSepolia.setReceiverOnConnectedChain(address(crossCreditOnAvalancheFuji));
//        vm.stopBroadcast();
    }
}
