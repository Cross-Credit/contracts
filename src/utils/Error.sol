// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Error {
    error NotWhitelistedAsset();
    error NotConnectedAsset();
    error InvalidAddress();
    error InvalidAmount();
    error NoZeroAmount();
    error ReceiverAddressNotSet();
    error ConnectedChainNotSet();
    error NotEnoughBalance();
    error StaleOraclePrice();
    error PriceFeedNotSet();
    error InvalidOraclePrice();
    error OracleCallFailed();
    error AmountSurpassesLTV();
    error TransferFailed();
    error InsufficientCollateralRemaining();
    error CollateralExhausted();
    error UserNotLiquidateable();
    error InsufficientRepayAmount();
}
