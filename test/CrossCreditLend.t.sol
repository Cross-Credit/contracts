// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Base} from "./Base.t.sol";
import {console} from "forge-std/console.sol";


contract CrossCreditLend is Base {
    function test_lendAndUnlend() public {
        _setOraclePrices(1);

        uint256 amountToLend = 1e6; // ~1 USDC
        address assetToLend = address(sourceUSDC);

        vm.selectFork(sourceFork);

        vm.startPrank(firstUser);
        sourceUSDC.approve(address(crossCreditOnSource), amountToLend);
        crossCreditOnSource.lend(amountToLend, assetToLend);
        vm.stopPrank();

        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        vm.selectFork(sourceFork);
        vm.startPrank(firstUser);
        uint userLendUSDValue = crossCreditOnSource.getTotalUSDValueOfUserByType(firstUser, 1);
        console.log("User lend usd val before unlend: ", userLendUSDValue);
        uint userBalBeforeUnlend = sourceUSDC.balanceOf(firstUser);
        crossCreditOnSource.unlend(amountToLend, assetToLend);
        uint userBalAfterUnlend = sourceUSDC.balanceOf(firstUser);
        userLendUSDValue = crossCreditOnSource.getTotalUSDValueOfUserByType(firstUser, 1);

        assertEq(userLendUSDValue, 0, "User Lend Value mismatch");
        assertEq(userBalAfterUnlend, userBalBeforeUnlend + amountToLend, "User balance mismatch");
        vm.stopPrank();
        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        vm.selectFork(destinationFork);
        userLendUSDValue = crossCreditOnDest.getTotalUSDValueOfUserByType(firstUser, 1);
        assertEq(userLendUSDValue, 0, "User Lend Value mismatch");

    }
}