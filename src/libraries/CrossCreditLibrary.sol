// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library CrossCreditLibrary {
    struct LendPosition {
        uint256 amount;
    }

    struct PositionOnConnected {
        uint64 sourceChainID;
        address caller;
        address asset;
        uint256 amount;
        address liquidator;
        address debtAsset;
    }

    struct BorrowPosition {
        uint256 amount;
    }
}