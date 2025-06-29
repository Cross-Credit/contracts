// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Base} from "./Base.t.sol";
import {console} from "forge-std/console.sol";


contract CrossCreditLiquidation is Base {
    function test_lendBorrowLiquidate() public {
        _setOraclePrices(1);

        uint256 amountToLend = 1e6;
        address assetToLend = address(sourceUSDC);
        uint256 nativeAssetDecimals = 18;

        vm.selectFork(sourceFork);

        vm.startPrank(firstUser);
        sourceUSDC.approve(address(crossCreditOnSource), amountToLend);
        crossCreditOnSource.lend(amountToLend, assetToLend);
        vm.stopPrank();

        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        vm.selectFork(destinationFork);

        uint256 userTotalLendValueDest = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 1);
        (,int initialEthPrice_dest, , ,) = priceFeedOnDestETH.latestRoundData();
        uint256 LTV_CONTRACT = crossCreditOnDest.LTV();
        uint256 borrowLTV_percentage = LTV_CONTRACT - 10;
        uint256 targetBorrowUSD = (borrowLTV_percentage * userTotalLendValueDest) / 100;

        uint256 amountToBorrowRaw = (targetBorrowUSD * (10 ** nativeAssetDecimals)) / uint256(initialEthPrice_dest);

        vm.startPrank(firstUser);
        crossCreditOnDest.borrow(amountToBorrowRaw, NATIVE_ASSET);
        vm.stopPrank();

        uint256 userTotalBorrowValueDest_initial = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 2);

        uint256 LIQ_CONTRACT = crossCreditOnDest.LIQ();
        uint256 currentLTV_initial = (userTotalBorrowValueDest_initial * 100) / userTotalLendValueDest;
        assertTrue(currentLTV_initial < LIQ_CONTRACT, "Loan should be healthy initially");

        _setLiquidationRates(
            userTotalLendValueDest,
            userTotalBorrowValueDest_initial,
            initialEthPrice_dest,
            LIQ_CONTRACT
        );

        vm.selectFork(sourceFork);
        uint liquidatorBalOfCollateralBefore = sourceUSDC.balanceOf(secondUser);
        uint debtorCollateralPositionBefore = crossCreditOnSource.getUserPositionForAssetByType(address(sourceUSDC), firstUser, 1);
        assertEq((debtorCollateralPositionBefore > 0), true, "Debtor collateral position exists");


        vm.selectFork(destinationFork);
        userTotalLendValueDest = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 1);
        uint userTotalBorrowValueAfterPriceIncrease = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 2);

        assertTrue(userTotalBorrowValueAfterPriceIncrease > (LIQ_CONTRACT * userTotalLendValueDest) / 100, "Loan should be liquidatable after price increase");

        vm.deal(secondUser, amountToBorrowRaw);
        uint userBalBeforeLIQ = secondUser.balance;
        vm.startPrank(secondUser);
        crossCreditOnDest.liquidate{value: amountToBorrowRaw}(amountToBorrowRaw, NATIVE_ASSET, firstUser);
        vm.stopPrank();

        assertEq(secondUser.balance, userBalBeforeLIQ - amountToBorrowRaw, "User balance mismatch");

        uint256 finalUserLendValue = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 1);
        uint256 finalUserBorrowValue = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 2);

        assertEq(finalUserLendValue, 0, "User's lend position on dest should be zero after full liquidation");
        assertEq(finalUserBorrowValue, 0, "User's borrow position on dest should be zero after full liquidation");

        ccipLocalSimulatorFork.switchChainAndRouteMessage(sourceFork);
        vm.selectFork(sourceFork);

        uint liquidatorBalOfCollateralAfter = sourceUSDC.balanceOf(secondUser);
        uint debtorCollateralPositionAfter = crossCreditOnSource.getUserPositionForAssetByType(address(sourceUSDC), firstUser, 1);

        finalUserLendValue = crossCreditOnSource.getTotalUSDValueOfUserByType(firstUser, 1);
        finalUserBorrowValue = crossCreditOnSource.getTotalUSDValueOfUserByType(firstUser, 2);

        uint userUSDCPositionSource = crossCreditOnSource.getUserPositionForAssetByType(address(sourceUSDC), firstUser, 1);
        console.log("userUSDCPositionSource", userUSDCPositionSource);

        assertEq(finalUserLendValue, 0, "User's lend position on source should be zero after full liquidation");
        assertEq(finalUserBorrowValue, 0, "User's borrow position on source should be zero after full liquidation");

        assertEq(debtorCollateralPositionAfter, 0, "Debtor collateral position not closed");
        assertEq(liquidatorBalOfCollateralAfter, liquidatorBalOfCollateralBefore + debtorCollateralPositionBefore, "Liquidator collateral balance not increasde");
    }

    function _setLiquidationRates(
        uint256 _userTotalLendValueDest,
        uint256 _userTotalBorrowValueDest_initial,
        int _currentEthPrice,
        uint256 _LIQ_CONTRACT
    ) internal {
        uint256 targetBorrowedUsdValueForLIQ = (_LIQ_CONTRACT * _userTotalLendValueDest) / 100;

        require(_userTotalBorrowValueDest_initial > 0, "Initial borrow value cannot be zero for liquidation price calculation");

        int256 newEthPriceTarget = (_currentEthPrice * int256(targetBorrowedUsdValueForLIQ)) / int256(_userTotalBorrowValueDest_initial);

        newEthPriceTarget = newEthPriceTarget + (newEthPriceTarget / 1000) + 1;

        if (newEthPriceTarget <= _currentEthPrice) {
            newEthPriceTarget = _currentEthPrice + (_currentEthPrice / 50) + 100;
        }

        vm.selectFork(destinationFork);
        priceFeedOnDestETH.setLatestRoundDataReturn(
            uint80(block.timestamp), newEthPriceTarget, block.timestamp, block.timestamp, uint80(block.timestamp)
        );

        vm.selectFork(sourceFork);
        priceFeedOnSourceETH.setLatestRoundDataReturn(
            uint80(block.timestamp), newEthPriceTarget, block.timestamp, block.timestamp, uint80(block.timestamp)
        );
    }
}