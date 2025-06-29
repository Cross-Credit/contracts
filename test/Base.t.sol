// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CrossCredit} from "../src/CrossCredit.sol";
import {AggregatorV3InterfaceMock} from "./mocks/AggregatorV3InterfaceMock.sol";
import {CustomERC20} from "./mocks/CustomERC20.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {WETH9} from "@chainlink/local/src/shared/WETH9.sol";

contract Base is Test {
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    CrossCredit public crossCreditOnSource;
    CrossCredit public crossCreditOnDest;

    IRouterClient public sourceRouter;
    IRouterClient public destinationRouter;

    AggregatorV3InterfaceMock public priceFeedOnSourceUSDC;
    AggregatorV3InterfaceMock public priceFeedOnSourceETH;

    AggregatorV3InterfaceMock public priceFeedOnDestETH;
    AggregatorV3InterfaceMock public priceFeedOnDestUSDC;

    CustomERC20 public sourceUSDC;
    CustomERC20 public destUSDC;

    uint64 public SOURCE_CHAIN_SELECTOR;
    uint64 public DEST_CHAIN_SELECTOR;

    address public admin = makeAddr("admin");
    address public firstUser = makeAddr("firstUser");
    address public secondUser = makeAddr("secondUser");
    address public thirdUser = makeAddr("thirdUser");

    uint256 internal sourceFork;
    uint256 internal destinationFork;

    address public NATIVE_ASSET = makeAddr("NATIVE_ASSET");

    function setUp() public {
        string memory ARBITRUM_SEPOLIA_RPC_URL = vm.envString("ARBITRUM_SEPOLIA_RPC_URL");
        string memory ETHEREUM_SEPOLIA_RPC_URL = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");

        // Create forks
        sourceFork = vm.createFork(ARBITRUM_SEPOLIA_RPC_URL);
        destinationFork = vm.createFork(ETHEREUM_SEPOLIA_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork)); // Keep simulator state across forks

        // --- Setup Destination Fork (e.g., Ethereum Sepolia) ---
        vm.selectFork(destinationFork);
        Register.NetworkDetails memory destinationNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        DEST_CHAIN_SELECTOR = destinationNetworkDetails.chainSelector;
        destinationRouter = IRouterClient(destinationNetworkDetails.routerAddress);

        crossCreditOnDest = new CrossCredit(admin, NATIVE_ASSET, address(destinationRouter));
        priceFeedOnDestUSDC = new AggregatorV3InterfaceMock();
        priceFeedOnDestETH = new AggregatorV3InterfaceMock();

        vm.startPrank(admin);
        destUSDC = new CustomERC20("USDC", "usdc", 18, 100000e18); // Assuming 6 decimals for USDC on both chains
        console.log("Actual destUSDC address deployed on Destination Fork: ", address(destUSDC));

        destUSDC.transfer(firstUser, 10000e18);
        destUSDC.transfer(secondUser, 10000e18);
        destUSDC.transfer(thirdUser, 10000e18);

        crossCreditOnDest.listAsset(address(destUSDC), destUSDC.decimals());
        crossCreditOnDest.listAsset(NATIVE_ASSET, 18);
        crossCreditOnDest.setPriceFeed(address(destUSDC), address(priceFeedOnDestUSDC));
        crossCreditOnDest.setPriceFeed(address(NATIVE_ASSET), address(priceFeedOnDestETH));
        vm.stopPrank();

        // --- Setup Source Fork (e.g., Arbitrum Sepolia) ---
        vm.selectFork(sourceFork);
        Register.NetworkDetails memory sourceNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        SOURCE_CHAIN_SELECTOR = sourceNetworkDetails.chainSelector;
        sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);

        crossCreditOnSource = new CrossCredit(admin, NATIVE_ASSET, address(sourceRouter));
        priceFeedOnSourceUSDC = new AggregatorV3InterfaceMock();
        priceFeedOnSourceETH = new AggregatorV3InterfaceMock();

        vm.startPrank(admin);
        sourceUSDC = new CustomERC20("USDC", "usdc", 6, 100000e6);
        console.log("Actual sourceUSDC address deployed on Source Fork: ", address(sourceUSDC));

        sourceUSDC.transfer(firstUser, 10000e6);
        sourceUSDC.transfer(secondUser, 10000e6);
        sourceUSDC.transfer(thirdUser, 10000e6);

        crossCreditOnSource.listAsset(address(sourceUSDC), sourceUSDC.decimals());
        crossCreditOnSource.listAsset(NATIVE_ASSET, 18);
        crossCreditOnSource.setPriceFeed(address(sourceUSDC), address(priceFeedOnSourceUSDC));
        crossCreditOnSource.setPriceFeed(address(NATIVE_ASSET), address(priceFeedOnSourceETH));
        vm.stopPrank();

        // --- Set cross-chain mappings and receivers ---
        vm.startPrank(admin);
        vm.selectFork(sourceFork);
        crossCreditOnSource.setConnectedChainID(DEST_CHAIN_SELECTOR);
        crossCreditOnSource.setReceiverOnConnectedChain(address(crossCreditOnDest));
        crossCreditOnSource.setAssetToAssetOnConnectedChain(address(sourceUSDC), address(destUSDC), 18);
        crossCreditOnSource.setAssetToAssetOnConnectedChain(NATIVE_ASSET, NATIVE_ASSET, 18);
        vm.stopPrank();

        vm.startPrank(admin);
        vm.selectFork(destinationFork);
        crossCreditOnDest.setConnectedChainID(SOURCE_CHAIN_SELECTOR);
        crossCreditOnDest.setReceiverOnConnectedChain(address(crossCreditOnSource));
        crossCreditOnDest.setAssetToAssetOnConnectedChain(address(destUSDC), address(sourceUSDC), 6);
        crossCreditOnDest.setAssetToAssetOnConnectedChain(NATIVE_ASSET, NATIVE_ASSET, 18);

        vm.stopPrank();

        // Fund contracts with native token for gas/fees
        vm.selectFork(sourceFork);
        vm.deal(address(crossCreditOnSource), 100 ether);
        vm.selectFork(destinationFork);
        vm.deal(address(crossCreditOnDest), 100 ether);
    }

    function _setOraclePrices(int _price) internal {
        int256 REALISTIC_USDC_PRICE_LOWER = 99_900_000; // 0.999 USD * 1e8
        int256 REALISTIC_USDC_PRICE_UPPER = 100_100_000; // 1.001 USD * 1e8

        int256 SOURCE_USDC_PRICE = bound(_price, REALISTIC_USDC_PRICE_LOWER, REALISTIC_USDC_PRICE_UPPER);
        int256 SOURCE_ETH_PRICE = bound(_price, int256(2500e8), int256(3500e8));

        vm.selectFork(sourceFork);
        priceFeedOnSourceUSDC.setDecimalsReturn(8);
        priceFeedOnSourceUSDC.setDescriptionReturn("");
        priceFeedOnSourceUSDC.setLatestRoundDataReturn(
            uint80(block.timestamp), SOURCE_USDC_PRICE, block.timestamp, block.timestamp, uint80(block.timestamp)
        );

        priceFeedOnSourceETH.setDecimalsReturn(8);
        priceFeedOnSourceETH.setDescriptionReturn("");
        priceFeedOnSourceETH.setLatestRoundDataReturn(
            uint80(block.timestamp), SOURCE_ETH_PRICE, block.timestamp, block.timestamp, uint80(block.timestamp)
        );

        int256 DEST_USDC_PRICE = bound(_price, REALISTIC_USDC_PRICE_LOWER, REALISTIC_USDC_PRICE_UPPER);
        int256 DEST_ETH_PRICE = bound(_price, int256(2500e8), int256(3500e8));
        vm.selectFork(destinationFork);
        priceFeedOnDestUSDC.setDecimalsReturn(8);
        priceFeedOnDestUSDC.setDescriptionReturn("");
        priceFeedOnDestUSDC.setLatestRoundDataReturn(
            uint80(block.timestamp), DEST_USDC_PRICE, block.timestamp, block.timestamp, uint80(block.timestamp)
        );

        priceFeedOnDestETH.setDecimalsReturn(8);
        priceFeedOnDestETH.setDescriptionReturn("");
        priceFeedOnDestETH.setLatestRoundDataReturn(
            uint80(block.timestamp), DEST_ETH_PRICE, block.timestamp, block.timestamp, uint80(block.timestamp)
        );

    }

    function test_sanity_checks() public {
        vm.selectFork(sourceFork);
        uint64 sourceChainID = crossCreditOnSource.i_sourceChainID();
        console.log("Source chain selector: ", sourceChainID);

        vm.selectFork(destinationFork);
        uint64 destChainID = crossCreditOnDest.i_sourceChainID();
        console.log("Dest chain selector: ", destChainID);

        vm.selectFork(sourceFork);
        uint userBal = sourceUSDC.balanceOf(firstUser);
        console.log("User sourceUSDC balance on Source Fork: ", userBal);

        vm.selectFork(destinationFork);
        uint userDestBal = destUSDC.balanceOf(firstUser);
        console.log("User destUSDC balance on Destination Fork: ", userDestBal);
    }

    function test_cross_chain_lend() public {
        uint256 amountToLend = 1e6; // Using 1e6 for 6 decimals USDC

        vm.selectFork(sourceFork);
        vm.startPrank(firstUser);
        sourceUSDC.approve(address(crossCreditOnSource), amountToLend);
        crossCreditOnSource.lend(amountToLend, address(sourceUSDC));
        vm.stopPrank();

        // Simulate message routing by the CCIPLocalSimulatorFork
        // This takes the message from sourceFork and executes it on destinationFork
        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        // --- Query balances on Source Fork ---
        vm.selectFork(sourceFork);
        uint userSAmountLentOnConnected = crossCreditOnSource.getUserPositionForAssetByTypeOnDest(address(sourceUSDC), firstUser, 1);
        uint userSAmountLentOnSource = crossCreditOnSource.getUserPositionForAssetByTypeOnSource(address(sourceUSDC), firstUser, 1);
        uint userSAmountBorrowedOnConnected = crossCreditOnSource.getUserPositionForAssetByTypeOnDest(address(sourceUSDC), firstUser, 2);
        uint userSAmountBorrowedOnSource = crossCreditOnSource.getUserPositionForAssetByTypeOnSource(address(sourceUSDC), firstUser, 2);

//        console.log('Amount Source Lent Connected (on Source Chain, refers to what was sent to connected chain):', userSAmountLentOnConnected);
//        console.log('Amount Source Borrowed Connected (on Source Chain, refers to what was borrowed on connected chain):', userSAmountBorrowedOnConnected);
        console.log('Amount Source Lent Source (on Source Chain, refers to local lends):', userSAmountLentOnSource);
//        console.log('Amount Source Borrowed Source (on Source Chain, refers to local borrows):', userSAmountBorrowedOnSource);

        // --- Query balances on Destination Fork ---
        vm.selectFork(destinationFork);
        // This is the crucial one for the cross-chain lend received on Dest
        uint userAmountLentOnConnectedOnDest = crossCreditOnDest.getUserPositionForAssetByTypeOnDest(address(destUSDC), firstUser, 1);
        uint userAmountLentOnSourceOnDest = crossCreditOnDest.getUserPositionForAssetByTypeOnSource(address(destUSDC), firstUser, 1);
        uint userAmountBorrowedOnConnectedOnDest = crossCreditOnDest.getUserPositionForAssetByTypeOnDest(address(destUSDC), firstUser, 2);
        uint userAmountBorrowedOnSourceOnDest = crossCreditOnDest.getUserPositionForAssetByTypeOnSource(address(destUSDC), firstUser, 2);

        console.log('Amount Dest Lent Connected (on Dest Chain, refers to cross-chain lends received):', userAmountLentOnConnectedOnDest);
//        console.log('Amount Dest Borrowed Connected (on Dest Chain, refers to cross-chain borrows received):', userAmountBorrowedOnConnectedOnDest);
//        console.log('Amount Dest Lent Source (on Dest Chain, refers to local lends on Dest):', userAmountLentOnSourceOnDest);
//        console.log('Amount Dest Borrowed Source (on Dest Chain, refers to local borrows on Dest):', userAmountBorrowedOnSourceOnDest);

        // Assertions for cross-chain lend
        assertEq(userSAmountLentOnSource, amountToLend); // Source should record the local lend
        assertEq(userAmountLentOnConnectedOnDest, amountToLend); // Dest should receive and record the cross-chain lend
    }
}