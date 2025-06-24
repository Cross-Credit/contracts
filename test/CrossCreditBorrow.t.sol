// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Base} from "./Base.t.sol";
import {console} from "forge-std/console.sol";

contract CrossCreditBorrow is Base {
    function test_lendOnSourceAndBorrowOnDest() public {
        _setOraclePrices(1);

        uint256 amountToLend = 1e6; // ~1 USDC
        address assetToLend = address(sourceUSDC);

        // --- SOURCE CHAIN ACTIONS (Lend) ---
        vm.selectFork(sourceFork);

        vm.startPrank(firstUser);
        sourceUSDC.approve(address(crossCreditOnSource), amountToLend);
        crossCreditOnSource.lend(amountToLend, assetToLend);
        vm.stopPrank();

        // Post-lend state checks on source
        assertEq(sourceUSDC.balanceOf(address(crossCreditOnSource)), amountToLend, "Protocol's USDC balance after lend on source");
        assertEq(crossCreditOnSource.getUserPositionForAssetByType(assetToLend, firstUser, 1), amountToLend, "Source lend position recorded");
        assertEq(crossCreditOnSource.getUserPositionForAssetByType(assetToLend, firstUser, 2), 0, "No source borrow position yet");

        // Calculate USD value of collateral based on source state
        uint256 initialLendUSDValue = crossCreditOnSource.getTotalUSDValueOfUserByType(firstUser, 1);
        console.log("Initial Lend USD Value (Source):", initialLendUSDValue);

        // --- CCIP MESSAGE ROUTING ---
        // Route message from source to destination
        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        // --- DESTINATION CHAIN ACTIONS (Borrow) ---
        vm.selectFork(destinationFork);

        // Initial state checks on destination (after message received)
        // This confirms the mirrored position is correctly recorded
        uint userAmountLentOnConnectedOnDest = crossCreditOnDest.getUserPositionForAssetByTypeOnDest(address(destUSDC), firstUser, 1);
        assertEq(userAmountLentOnConnectedOnDest, amountToLend, "Mirrored lend amount on dest");
        assertEq(crossCreditOnDest.getUserPositionForAssetByTypeOnDest(NATIVE_ASSET, firstUser, 2), 0, "No dest borrow position yet");

        uint userTotalLendValue = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 1);
        uint userTotalBorrowValue = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 2);

        console.log("User lend value (Dest):", userTotalLendValue);
        console.log("User borrow value (Dest):", userTotalBorrowValue);

        // Verify lend value consistency across chains (should be equal after routing)
        assertEq(userTotalLendValue, initialLendUSDValue, "Lend USD value mismatch after CCIP routing");

        // Calculate max borrowable amount and the specific amount to borrow
        (,int usdPriceETH_dest, , ,) = priceFeedOnDestETH.latestRoundData();
        uint256 LTV = crossCreditOnDest.LTV();
        uint256 maxBorrowableUSD = (LTV * userTotalLendValue) / 100;
        uint256 targetBorrowUSD = ((LTV - 10) * userTotalLendValue) / 100; // Borrow 10% less than max for safety

        // Convert target USD amount to raw NATIVE_ASSET (ETH) amount
        uint256 nativeAssetDecimals = crossCreditOnDest.getAssetDecimalsOnSource(NATIVE_ASSET);
        uint256 amountToBorrowRaw = (targetBorrowUSD * (10 ** nativeAssetDecimals)) / uint256(usdPriceETH_dest);
        console.log("Calculated max borrowable USD:", maxBorrowableUSD);
        console.log("Calculated target borrow USD:", targetBorrowUSD);
        console.log("Calculated raw ETH to borrow:", amountToBorrowRaw);

        vm.startPrank(firstUser);
        uint userBalOnDestBefore = firstUser.balance;
        crossCreditOnDest.borrow(amountToBorrowRaw, NATIVE_ASSET);
        uint userBalOnDestAfter = firstUser.balance;
        vm.stopPrank();

        // Post-borrow state checks on destination
        uint borrowedAmountActual = userBalOnDestAfter - userBalOnDestBefore;
        assertEq(borrowedAmountActual, amountToBorrowRaw, "Actual ETH borrowed mismatch with calculated");

        // Check the USD value of the actual borrowed amount vs. target.
        // Convert actual borrowed ETH to USD (using fixed `nativeAssetDecimals` not source decimals)
        uint256 actualBorrowedUSD = (borrowedAmountActual * uint256(usdPriceETH_dest)) / (10 ** nativeAssetDecimals);
        bool usdValCalc = actualBorrowedUSD < targetBorrowUSD ? targetBorrowUSD - actualBorrowedUSD < 10 : actualBorrowedUSD - targetBorrowUSD < 10;
        assertEq(usdValCalc, true, "Borrowed USD value not within tolerance of target");

        // Verify updated borrow position on dest
        assertEq(crossCreditOnDest.getUserPositionForAssetByTypeOnSource(NATIVE_ASSET, firstUser, 2), borrowedAmountActual, "Dest borrow position not updated correctly");

        // --- Cross-Chain Consistency Checks (After Borrow) ---
        ccipLocalSimulatorFork.switchChainAndRouteMessage(sourceFork);

        // Check consistency on Destination after round trip
        vm.selectFork(destinationFork);
        uint userTotalLendValueOnDest = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 1);
        uint userTotalBorrowValueOnDest = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 2);

        // Check consistency on Source after round trip
        vm.selectFork(sourceFork);
        uint userTotalLendValueOnSource = crossCreditOnSource.getTotalUSDValueOfUserByType(firstUser, 1);
        uint userTotalBorrowValueOnSource = crossCreditOnSource.getTotalUSDValueOfUserByType(firstUser, 2);

        assertEq(userTotalLendValueOnDest, userTotalLendValueOnSource, "Final Lend USD value mismatch between chains");
        assertEq(userTotalBorrowValueOnDest, userTotalBorrowValueOnSource, "Final Borrow USD value mismatch between chains");
    }

    function test_lendOnSourceBorrowAndRepayOnDest() public {
        _setOraclePrices(1);

        uint256 amountToLend = 1e6; // ~1 USDC
        address assetToLend = address(sourceUSDC);

        vm.selectFork(sourceFork);

        vm.startPrank(firstUser);
        sourceUSDC.approve(address(crossCreditOnSource), amountToLend);
        crossCreditOnSource.lend(amountToLend, assetToLend);
        vm.stopPrank();

        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        vm.selectFork(destinationFork);
        uint userTotalLendValue = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 1);
        (,int usdPriceETH_dest, , ,) = priceFeedOnDestETH.latestRoundData();
        uint256 LTV = crossCreditOnDest.LTV();
        uint256 maxBorrowableUSD = (LTV * userTotalLendValue) / 100;
        uint256 targetBorrowUSD = ((LTV - 10) * userTotalLendValue) / 100; // Borrow 10% less than max for safety

        uint256 nativeAssetDecimals = crossCreditOnDest.getAssetDecimalsOnSource(NATIVE_ASSET);
        uint256 amountToBorrowRaw = (targetBorrowUSD * (10 ** nativeAssetDecimals)) / uint256(usdPriceETH_dest);

        vm.startPrank(firstUser);
        // BORROW
        uint userBalOnDestBefore = firstUser.balance;
        crossCreditOnDest.borrow(amountToBorrowRaw, NATIVE_ASSET);
        uint userBalOnDestAfter = firstUser.balance;
        vm.stopPrank();

        ccipLocalSimulatorFork.switchChainAndRouteMessage(sourceFork);

        vm.selectFork(destinationFork);
        // REPAY
        vm.startPrank(firstUser);
        uint userTotalBorrowValue = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 2);
        bool usdValCalc = userTotalBorrowValue < targetBorrowUSD ? targetBorrowUSD - userTotalBorrowValue < 10 : userTotalBorrowValue - targetBorrowUSD < 10;
        assertEq(usdValCalc, true, "Borrowed USD value not within tolerance of target");

        _setOraclePrices(1); // Price change
        (,usdPriceETH_dest, , ,) = priceFeedOnDestETH.latestRoundData();
        uint amountToRepay = (userTotalBorrowValue * (10 ** nativeAssetDecimals)) / uint256(usdPriceETH_dest);
        vm.deal(firstUser, amountToRepay);
        crossCreditOnDest.repay{value: amountToRepay}(amountToRepay, NATIVE_ASSET);
        userTotalBorrowValue = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 2);

        bool userBorrowValueRepaid = userTotalBorrowValue == 0 || userTotalBorrowValue < 10;
        assertTrue(userBorrowValueRepaid, "Loan repayment not within range");
        vm.stopPrank();
        ccipLocalSimulatorFork.switchChainAndRouteMessage(sourceFork);

        vm.selectFork(sourceFork);
        userTotalBorrowValue = crossCreditOnSource.getTotalUSDValueOfUserByType(firstUser, 2);
        userBorrowValueRepaid = userTotalBorrowValue == 0 || userTotalBorrowValue < 10;
        assertTrue(userBorrowValueRepaid, "Loan repayment not within range");
    }
}