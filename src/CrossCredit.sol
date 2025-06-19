// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IRouterClient.sol";
import "./lib/Client.sol";

import "openzeppelin/contracts/access/Ownable.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./utils/Error.sol";
import "./lib/CrossCreditLibrary.sol";
import "./interfaces/ICrossCredit.sol";
import "./interfaces/AggregatorV3Interface.sol";
import {CCIPReceiver} from "./applications/CCIPReceiver.sol";

contract CrossCredit is Ownable, CCIPReceiver, ICrossCredit {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private s_whitelistedAssets;
    mapping(address => uint8) private s_assetDecimals;
    mapping(address => mapping(address => CrossCreditLibrary.LendPosition)) private s_userLendPosition;
    mapping(address => mapping(address => CrossCreditLibrary.BorrowPosition)) private s_userBorrowPosition;

    mapping(address => address) private s_assetToAssetOnConnectedChain;
    mapping(address => uint8) private s_assetDecimalsOnConnectedChain;

    mapping(address => AggregatorV3Interface) private s_assetFeed;

    address private s_receiverOnConnectedChain;
    uint64 public s_connectedChainID;
    uint64 public immutable i_sourceChainID;
    address private immutable i_nativeAssetAddress;

    mapping(address => mapping(address => CrossCreditLibrary.LendPosition)) private s_userLendPositionOnConnectedChain;
    mapping(address => mapping(address => CrossCreditLibrary.BorrowPosition)) private s_userBorrowPositionOnConnectedChain;

    IRouterClient private s_router;
//    LinkTokenInterface private s_linkToken;

    uint8 private constant LEND_POSITION = 1;
    uint8 private constant BORROW_POSITION = 2;
    uint8 private constant LIQUIDATE_POSITION = 3;
    uint8 private constant LTV = 75;
    uint8 private constant LIQ = 80;

    modifier onlyWhitelistedAsset(address _asset) {
        if (!s_whitelistedAssets.contains(_asset)) revert Error.NotWhitelistedAsset();
        _;
    }

    modifier validAddress(address _address) {
        if (_address == address(0)) revert Error.InvalidAddress();
        _;
    }

    modifier onlyConnectedAsset(address _asset) {
        if (s_assetToAssetOnConnectedChain[_asset] == address(0)) revert Error.NotConnectedAsset();
        _;
    }

    constructor(address _adminAddress, address _nativeAsset, address router) Ownable(_adminAddress) CCIPReceiver(router) {
        i_nativeAssetAddress = _nativeAsset;
        s_router = IRouterClient(router);

        i_sourceChainID = uint64(block.chainid);
    }

    function listAsset(address _asset, uint8 _decimals) public onlyOwner validAddress(_asset) {
        if (!s_whitelistedAssets.contains(_asset)) {
            s_whitelistedAssets.add(_asset);
            s_assetDecimals[_asset] = _decimals;
        }
    }

    function unlistAsset(address _asset) public onlyOwner validAddress(_asset) {
        if (s_whitelistedAssets.contains(_asset)) {
            s_whitelistedAssets.remove(_asset);
            s_assetDecimals[_asset] = 0;
        }
    }

    function setReceiverOnConnectedChain(address _receiver) public onlyOwner validAddress(_receiver) {
        s_receiverOnConnectedChain = _receiver;
    }

    function setConnectedChainID(uint64 _chainID) public onlyOwner {
        s_connectedChainID = _chainID;
    }

    function setAssetToAssetOnConnectedChain(address _asset, address _connectedChainAsset) public onlyOwner validAddress(_asset) validAddress(_connectedChainAsset) {
        s_assetToAssetOnConnectedChain[_asset] = _connectedChainAsset;
    }

    function setPriceFeed(address _asset, address _feed) public onlyOwner validAddress(_feed) onlyWhitelistedAsset(_asset) {
        s_assetFeed[_asset] = AggregatorV3Interface(_feed);
    }

    function lend(uint256 _amount, address _asset) public payable onlyWhitelistedAsset(_asset) validAddress(_asset) onlyConnectedAsset(_asset) {
        if (_amount == 0) revert Error.NoZeroAmount();
        if (_asset == i_nativeAssetAddress) {
            if (msg.value != _amount) revert Error.InvalidAmount();
        } else {
            IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        }

        CrossCreditLibrary.LendPosition storage lendPosition = s_userLendPosition[msg.sender][_asset];
        lendPosition.amount += _amount;

        CrossCreditLibrary.PositionOnConnected memory c_lendPosition = CrossCreditLibrary.PositionOnConnected({
            sourceChainID: i_sourceChainID, caller: msg.sender, asset: s_assetToAssetOnConnectedChain[_asset], amount: lendPosition.amount
        });

        bytes memory ccipData = abi.encode(c_lendPosition, LEND_POSITION);
        _ccipSend(ccipData);
    }

    function borrow(uint256 _amount, address _asset) public onlyWhitelistedAsset(_asset) validAddress(_asset) {
        if (_amount == 0) revert Error.NoZeroAmount();

        uint256 userTotalLendUSDValue = getTotalUSDValueOfUserByType(msg.sender, 1);
        uint256 userTotalBorrowUSDValue = getTotalUSDValueOfUserByType(msg.sender, 2);

        (int256 price, uint8 priceFeedDecimals) = _getAssetPriceData(_asset);
        uint256 currentBorrowAmountUSD = (_amount * uint256(price)) / (10 ** priceFeedDecimals);

        if (currentBorrowAmountUSD + userTotalBorrowUSDValue > ((LTV * userTotalLendUSDValue) / 100)) revert Error.AmountSurpassesLTV();

        CrossCreditLibrary.BorrowPosition storage borrowPosition = s_userBorrowPosition[msg.sender][_asset];
        borrowPosition.amount += _amount;

        CrossCreditLibrary.PositionOnConnected memory c_borrowPosition = CrossCreditLibrary.PositionOnConnected({
            amount: borrowPosition.amount, caller: msg.sender, asset: s_assetToAssetOnConnectedChain[_asset], sourceChainID: i_sourceChainID
        });

        bytes memory ccipData = abi.encode(c_borrowPosition, BORROW_POSITION);
        _ccipSend(ccipData);

        if (_asset == i_nativeAssetAddress) {
            (bool success,) = payable(msg.sender).call{value: _amount}("");
            if (!success) revert Error.TransferFailed();

        } else {
            IERC20(_asset).safeTransfer(msg.sender, _amount);
        }
    }

    function repay(uint256 _amount, address _asset) public payable onlyWhitelistedAsset(_asset) validAddress(_asset) {
        if (_amount == 0) revert Error.NoZeroAmount();

        uint256 assetAmountBorrowed = s_userBorrowPosition[msg.sender][_asset].amount;

        _amount = _amount > assetAmountBorrowed ? assetAmountBorrowed : _amount;

        if (_asset == i_nativeAssetAddress) {
            require(msg.value == _amount);
        } else {
            IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        }

        CrossCreditLibrary.BorrowPosition storage borrowPosition = s_userBorrowPosition[msg.sender][_asset];
        borrowPosition.amount -= _amount;

        CrossCreditLibrary.PositionOnConnected memory c_borrowPosition = CrossCreditLibrary.PositionOnConnected({
            amount: borrowPosition.amount, caller: msg.sender, asset: s_assetToAssetOnConnectedChain[_asset], sourceChainID: i_sourceChainID
        });

        bytes memory ccipData = abi.encode(c_borrowPosition, BORROW_POSITION);
        _ccipSend(ccipData);

    }

    function unlend(uint256 _amount, address _asset) public onlyWhitelistedAsset(_asset) validAddress(_asset) {
        if (_amount == 0) revert Error.NoZeroAmount();

        uint256 userTotalLendUSDValue = getTotalUSDValueOfUserByType(msg.sender, 1);
        uint256 userTotalBorrowUSDValue = getTotalUSDValueOfUserByType(msg.sender, 2);

        (int256 price, uint8 priceFeedDecimals) = _getAssetPriceData(_asset);
        uint256 currentUnlendAmountUSD = (_amount * uint256(price)) / (10 ** priceFeedDecimals);

        if (userTotalLendUSDValue < currentUnlendAmountUSD) revert Error.InsufficientCollateralRemaining();

        if (userTotalBorrowUSDValue > ((LTV * (userTotalLendUSDValue - currentUnlendAmountUSD))) / 100) revert Error.CollateralExhausted();

        CrossCreditLibrary.LendPosition storage lendPosition = s_userLendPosition[msg.sender][_asset];
        lendPosition.amount -= _amount;

        CrossCreditLibrary.PositionOnConnected memory c_lendPosition = CrossCreditLibrary.PositionOnConnected({
            amount: lendPosition.amount, asset: s_assetToAssetOnConnectedChain[_asset], caller: msg.sender, sourceChainID: i_sourceChainID
        });

        bytes memory ccipData = abi.encode(c_lendPosition, LEND_POSITION);
        _ccipSend(ccipData);

        if (_asset == i_nativeAssetAddress) {
            (bool success,) = payable(msg.sender).call{value: _amount}("");
            if (!success) revert Error.TransferFailed();
        } else {
            IERC20(_asset).safeTransfer(msg.sender, _amount);
        }
    }

    function liquidate(uint256 _amount, address _asset, address _borrower) public payable onlyWhitelistedAsset(_asset) validAddress(_asset) validAddress(_borrower){
        if (_amount == 0) revert Error.NoZeroAmount();

        uint256 userTotalLendUSDValue = getTotalUSDValueOfUserByType(msg.sender, 1);
        uint256 userTotalBorrowUSDValue = getTotalUSDValueOfUserByType(msg.sender, 2);

        (int256 price, uint8 priceFeedDecimals) = _getAssetPriceData(_asset);
        uint256 currentRepayAmountUSD = (_amount * uint256(price)) / (10 ** priceFeedDecimals);

        if(userTotalBorrowUSDValue < ((LIQ * userTotalLendUSDValue) / 100)) revert Error.UserNotLiquidateable();

        if (_asset == i_nativeAssetAddress) {
            if(currentRepayAmountUSD < userTotalBorrowUSDValue) revert Error.InsufficientRepayAmount();
        }

    }

    function getTotalUSDValueOfUserByType(address _user, uint8 _positionType) public view returns (uint256) {
        address[] memory assets = s_whitelistedAssets.values();

        uint256 totalUSDVal = 0;

        for (uint i = 0; i < assets.length; i++) {
            address _asset = assets[i];
            uint256 userAmountOnSource;
            uint256 userAmountOnConnected;

            if (_positionType == 1) { // Lend
                userAmountOnSource = s_userLendPosition[_user][_asset].amount;
                userAmountOnConnected = s_userLendPositionOnConnectedChain[_user][_asset].amount;
            } else if (_positionType == 2) { // Borrow
                userAmountOnSource = s_userBorrowPosition[_user][_asset].amount;
                userAmountOnConnected = s_userBorrowPositionOnConnectedChain[_user][_asset].amount;
            } else {
                // Handle invalid position type, e.g., revert or skip
                continue;
            }

            if (userAmountOnConnected + userAmountOnSource == 0) continue;

            if (address(s_assetFeed[_asset]) == address(0)) continue;

            (int256 price, uint8 priceFeedDecimals) = _getAssetPriceData(_asset);

            uint256 usdAmountOnSource;
            uint256 usdAmountOnConnected;

            if (userAmountOnSource > 0) {
                usdAmountOnSource = (userAmountOnSource * uint256(price)) / (10 ** priceFeedDecimals);
            }

            if (userAmountOnConnected > 0) {
                usdAmountOnConnected = s_assetDecimalsOnConnectedChain[_asset] != s_assetDecimals[_asset] ?
                    (s_assetDecimalsOnConnectedChain[_asset] > s_assetDecimals[_asset] ?
                        (userAmountOnConnected / (10 ** (s_assetDecimalsOnConnectedChain[_asset] - s_assetDecimals[_asset])) * uint256(price)) / (10 ** priceFeedDecimals) :
                        (userAmountOnConnected * (10 ** (s_assetDecimals[_asset] - s_assetDecimalsOnConnectedChain[_asset])) * uint256(price)) / (10 ** priceFeedDecimals)
                    ) :
                    (userAmountOnConnected * uint256(price)) / (10 ** priceFeedDecimals);
            }

            totalUSDVal += (usdAmountOnSource + usdAmountOnConnected);
        }

        return totalUSDVal;
    }

    function isAssetWhitelisted(address _asset) public view returns (bool) {
        return s_whitelistedAssets.contains(_asset);
    }

    function _getAssetPriceData(address _asset) internal view returns (int256 price, uint8 priceFeedDecimals) {
        if (address(s_assetFeed[_asset]) == address(0)) {
            revert Error.PriceFeedNotSet();
        }

        priceFeedDecimals = s_assetFeed[_asset].decimals();
        try s_assetFeed[_asset].latestRoundData() returns (
            uint80 /*roundId*/,
            int256 answer,
            uint256 /*startedAt*/,
            uint256 updatedAt,
            uint80 /*answeredInRound*/
        ) {
            if (updatedAt + 3600 < block.timestamp) {
                revert Error.StaleOraclePrice();
            }
            price = answer;
            if (price <= 0) {
                revert Error.InvalidOraclePrice();
            }
        } catch (bytes memory /**/) {
            revert Error.OracleCallFailed();
        }
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {

        (CrossCreditLibrary.PositionOnConnected memory position, uint8 positionType) = abi.decode(any2EvmMessage.data, (CrossCreditLibrary.PositionOnConnected, uint8));
        if (positionType == LEND_POSITION) {
            s_userLendPositionOnConnectedChain[position.caller][position.asset].amount = position.amount;
        } else if (positionType == BORROW_POSITION) {
            s_userBorrowPositionOnConnectedChain[position.caller][position.asset].amount = position.amount;
        }

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            positionType
        );
    }

    function _ccipSend(bytes memory _data) internal returns (bytes32 messageId){
        if (s_receiverOnConnectedChain == address(0)) revert Error.ReceiverAddressNotSet();
        if (s_connectedChainID == 0) revert Error.ConnectedChainNotSet();
        Client.EVM2AnyMessage memory ccMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(s_receiverOnConnectedChain),
            data: _data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 200_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
//            feeToken: address(s_linkToken)
        });

        uint256 fees = s_router.getFee(
            s_connectedChainID,
            ccMessage
        );

        if (fees > (address(this).balance)) revert Error.NotEnoughBalance();

        messageId = s_router.ccipSend{value: fees}(s_connectedChainID, ccMessage);

        emit MessageSent(
            messageId,
            s_connectedChainID,
            s_receiverOnConnectedChain,
            address(0),
            fees
        );
    }
}
