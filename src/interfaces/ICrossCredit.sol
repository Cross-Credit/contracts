// SPDX-License-Identifier: MIT
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

    function lend(uint256 _amount, address _asset) external payable;

    function borrow(uint256 _amount, address _asset) external;

    function repay(uint256 _amount, address _asset) external payable;

    function unlend(uint256 _amount, address _asset) external;

    function liquidate(uint256 _amount, address _debtAsset, address _borrower, address _collateralToSeize) external payable;

    function getUserPositionForAssetByTypeOnSource(address _asset, address _user, uint8 _positionType) external view returns (uint256);

    function getUserPositionForAssetByTypeOnDest(address _asset, address _user, uint8 _positionType) external view returns (uint256);
}