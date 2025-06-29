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

    function liquidate(uint256 _amount, address _assetPaidByLiquidator, address _borrower) external payable;

    function getUserPositionForAssetByTypeOnSource(address _asset, address _user, uint8 _positionType) external view returns (uint256);

    function getUserPositionForAssetByTypeOnDest(address _asset, address _user, uint8 _positionType) external view returns (uint256);

    function setReceiverOnConnectedChain(address _receiver) external;

    function setConnectedChainID(uint64 _chainID) external;

    function setAssetToAssetOnConnectedChain(address _asset, address _connectedChainAsset, uint8 _assetDecimalsOnConnected) external;

    function setPriceFeed(address _asset, address _feed) external;
}