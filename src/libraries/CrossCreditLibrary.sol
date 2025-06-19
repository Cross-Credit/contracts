// SPDX-License-Identifier: UNLICENSED
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
    }

    struct BorrowPosition {
        uint256 amount;
    }
}