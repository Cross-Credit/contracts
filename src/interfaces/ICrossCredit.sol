// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


interface ICrossCredit {
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        address feeToken,
        uint256 fees
    );

    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        uint8 positionType
    );
}