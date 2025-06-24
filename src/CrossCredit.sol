// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";

import {IRouterClient} from "@chainlink/local/lib/chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/local/lib/chainlink-ccip/chains/evm/contracts/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/local/lib/chainlink-ccip/chains/evm/contracts/applications/CCIPReceiver.sol";

import "openzeppelin/contracts/access/Ownable.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./utils/Error.sol";
import "./libraries/CrossCreditLibrary.sol";
import "./interfaces/ICrossCredit.sol";
import "./interfaces/AggregatorV3Interface.sol";

contract CrossCredit is Ownable, ReentrancyGuard, CCIPReceiver, ICrossCredit {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private s_whitelistedAssets;
    mapping(address => uint8) private s_assetDecimals;
    mapping(address => mapping(address => CrossCreditLibrary.LendPosition)) internal s_userLendPosition;
    mapping(address => mapping(address => CrossCreditLibrary.BorrowPosition)) internal s_userBorrowPosition;

    mapping(address => address) internal s_assetToAssetOnConnectedChain;
    mapping(address => uint8) private s_assetDecimalsOnConnectedChain;

    mapping(address => AggregatorV3Interface) private s_assetFeed;

    bool public s_isConnectedChainSet;
    address private s_receiverOnConnectedChain;
    uint64 public s_connectedChainID;
    uint64 public immutable i_sourceChainID;
    address private immutable i_nativeAssetAddress;

    mapping(address => mapping(address => CrossCreditLibrary.LendPosition)) internal s_userLendPositionOnConnectedChain;
    mapping(address => mapping(address => CrossCreditLibrary.BorrowPosition)) internal s_userBorrowPositionOnConnectedChain;

    IRouterClient private s_router;
//    LinkTokenInterface private s_linkToken;

    uint8 private constant LEND_POSITION = 1;
    uint8 private constant BORROW_POSITION = 2;
    uint8 private constant LIQUIDATE_POSITION = 3;
    uint8 public constant LTV = 75;
    uint8 public constant LIQ = 80;

    bytes32 latestMessageId;
    uint64 latestSourceChainSelector;
    address latestSender;
    string latestMessage;

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

    constructor(address _adminAddress, address _nativeAsset, address router) Ownable(_adminAddress) CCIPReceiver(router) validAddress(_adminAddress) validAddress(_nativeAsset) {
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
        s_isConnectedChainSet = true;
    }

    function setAssetToAssetOnConnectedChain(address _asset, address _connectedChainAsset, uint8 _assetDecimalsOnConnected) public onlyOwner validAddress(_asset) validAddress(_connectedChainAsset) {
        if (_assetDecimalsOnConnected == 0) revert Error.InvalidAssetDecimals();
        s_assetToAssetOnConnectedChain[_asset] = _connectedChainAsset;
        s_assetDecimalsOnConnectedChain[_asset] = _assetDecimalsOnConnected;
    }

    function setPriceFeed(address _asset, address _feed) public onlyOwner validAddress(_feed) onlyWhitelistedAsset(_asset) {
        s_assetFeed[_asset] = AggregatorV3Interface(_feed);
    }

    function lend(uint256 _amount, address _asset) public payable nonReentrant onlyWhitelistedAsset(_asset) validAddress(_asset) onlyConnectedAsset(_asset) {
        if (_amount == 0) revert Error.NoZeroAmount();
        if (_asset == i_nativeAssetAddress) {
            if (msg.value != _amount) revert Error.InvalidAmount();
        } else {
            IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        }

        CrossCreditLibrary.LendPosition storage lendPosition = s_userLendPosition[msg.sender][_asset];
        lendPosition.amount += _amount;

        CrossCreditLibrary.PositionOnConnected memory c_lendPosition = CrossCreditLibrary.PositionOnConnected({
            sourceChainID: i_sourceChainID, caller: msg.sender, asset: s_assetToAssetOnConnectedChain[_asset], amount: lendPosition.amount, liquidator: address(0)
        });

        bytes memory ccipData = abi.encode(c_lendPosition, LEND_POSITION);
        _ccipSend(ccipData);
    }

    function borrow(uint256 _amount, address _asset) public nonReentrant onlyWhitelistedAsset(_asset) validAddress(_asset) {
        if (_amount == 0) revert Error.NoZeroAmount();

        uint256 userTotalLendUSDValue = getTotalUSDValueOfUserByType(msg.sender, 1);
        uint256 userTotalBorrowUSDValue = getTotalUSDValueOfUserByType(msg.sender, 2);

        uint256 assetDecimals = s_assetDecimals[_asset];

        (int256 price, uint8 priceFeedDecimals) = _getAssetPriceData(_asset);
        uint256 currentBorrowAmountUSD = (_amount * uint256(price)) / (10 ** assetDecimals);

        if (currentBorrowAmountUSD + userTotalBorrowUSDValue > ((LTV * userTotalLendUSDValue) / 100)) revert Error.AmountSurpassesLTV();

        CrossCreditLibrary.BorrowPosition storage borrowPosition = s_userBorrowPosition[msg.sender][_asset];
        borrowPosition.amount += _amount;

        CrossCreditLibrary.PositionOnConnected memory c_borrowPosition = CrossCreditLibrary.PositionOnConnected({
            amount: borrowPosition.amount, caller: msg.sender, asset: s_assetToAssetOnConnectedChain[_asset], sourceChainID: i_sourceChainID, liquidator: address(0)
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

    function repay(uint256 _amount, address _asset) public payable nonReentrant onlyWhitelistedAsset(_asset) validAddress(_asset) {
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
            amount: borrowPosition.amount, caller: msg.sender, asset: s_assetToAssetOnConnectedChain[_asset], sourceChainID: i_sourceChainID, liquidator: address(0)
        });

        bytes memory ccipData = abi.encode(c_borrowPosition, BORROW_POSITION);
        _ccipSend(ccipData);

    }

    function unlend(uint256 _amount, address _asset) public nonReentrant onlyWhitelistedAsset(_asset) validAddress(_asset) {
        if (_amount == 0) revert Error.NoZeroAmount();

        uint256 userTotalLendUSDValue = getTotalUSDValueOfUserByType(msg.sender, 1);
        uint256 userTotalBorrowUSDValue = getTotalUSDValueOfUserByType(msg.sender, 2);

        (int256 price, uint8 priceFeedDecimals) = _getAssetPriceData(_asset);

        uint8 localAssetDecimals = s_assetDecimals[_asset];

        uint256 currentUnlendAmountUSD = (_amount * uint256(price)) / (10 ** localAssetDecimals);

        if (userTotalLendUSDValue < currentUnlendAmountUSD) revert Error.InsufficientCollateralRemaining();

        if (userTotalBorrowUSDValue > ((LTV * (userTotalLendUSDValue - currentUnlendAmountUSD))) / 100) revert Error.CollateralExhausted();

        CrossCreditLibrary.LendPosition storage lendPosition = s_userLendPosition[msg.sender][_asset];
        lendPosition.amount -= _amount;

        CrossCreditLibrary.PositionOnConnected memory c_lendPosition = CrossCreditLibrary.PositionOnConnected({
            amount: lendPosition.amount, asset: s_assetToAssetOnConnectedChain[_asset], caller: msg.sender, sourceChainID: i_sourceChainID, liquidator: address(0)
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

    function liquidate(uint256 _amount, address _asset, address _borrower)
    public
    payable nonReentrant
    onlyWhitelistedAsset(_asset)
    validAddress(_asset)
    validAddress(_borrower)
    {
        if (_amount == 0) revert Error.NoZeroAmount();

        uint256 userTotalLendUSDValue = getTotalUSDValueOfUserByType(_borrower, 1);
        uint256 userTotalBorrowUSDValue = getTotalUSDValueOfUserByType(_borrower, 2);

        (int256 price, uint8 priceFeedDecimals) = _getAssetPriceData(_asset);
        uint256 currentRepayAmountUSD = (_amount * uint256(price)) / (10 ** priceFeedDecimals);

        if (userTotalBorrowUSDValue < ((LIQ * userTotalLendUSDValue) / 100)) revert Error.UserNotLiquidateable();
        if (currentRepayAmountUSD < userTotalBorrowUSDValue) revert Error.InsufficientRepayAmount();

        // Liquidator pays the debt asset
        if (_asset == i_nativeAssetAddress) {
            if (msg.value != _amount) revert Error.InvalidAmount();
        } else {
            IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        }

        uint256 refundAmount;
        refundAmount = currentRepayAmountUSD > userTotalBorrowUSDValue ? currentRepayAmountUSD - userTotalBorrowUSDValue : 0;

        address[] memory assets = s_whitelistedAssets.values();

        // Iterate through all assets and process liquidation for each using the helper
        for (uint256 i = 0; i < assets.length; i++) {
            _processAssetDuringLiquidation(_borrower, assets[i], msg.sender);
        }

        // Handle any refund due to the liquidator
        if (refundAmount > 0) {
            // Calculate the token amount to refund based on the USD overpayment
            uint256 tokenAmountToRefund = _amount * refundAmount / currentRepayAmountUSD;

            if (_asset != i_nativeAssetAddress) {
                IERC20(_asset).safeTransfer(msg.sender, tokenAmountToRefund);
            } else {
                (bool success,) = payable(msg.sender).call{value: tokenAmountToRefund}("");
                if (!success) revert Error.TransferFailed();
            }
        }
    }

    function _processAssetDuringLiquidation(
        address _borrower,
        address _currentAsset,
        address _liquidator
    ) internal {
        uint256 userLendAmountOnSource = s_userLendPosition[_borrower][_currentAsset].amount;
        uint256 userLendAmountOnConnected = s_userLendPositionOnConnectedChain[_borrower][_currentAsset].amount;

        s_userLendPosition[_borrower][_currentAsset].amount = 0;
        s_userBorrowPosition[_borrower][_currentAsset].amount = 0;

        s_userLendPositionOnConnectedChain[_borrower][_currentAsset].amount = 0;
        s_userBorrowPositionOnConnectedChain[_borrower][_currentAsset].amount = 0;


        CrossCreditLibrary.PositionOnConnected memory c_liquidatePosition = CrossCreditLibrary.PositionOnConnected({
            amount: userLendAmountOnConnected,
            asset: s_assetToAssetOnConnectedChain[_currentAsset],
            caller: _borrower,
            sourceChainID: i_sourceChainID,
            liquidator: _liquidator
        });

        bytes memory ccipData = abi.encode(c_liquidatePosition, LIQUIDATE_POSITION);
        _ccipSend(ccipData);

        // 5. Transfer collateral to the liquidator on the source chain
        if (_currentAsset != i_nativeAssetAddress) {
            IERC20(_currentAsset).safeTransfer(_liquidator, userLendAmountOnSource);
        } else {
            (bool success,) = payable(_liquidator).call{value: userLendAmountOnSource}("");
            if (!success) revert Error.TransferFailed();
        }
    }

    function getTotalUSDValueOfUserByType(address _user, uint8 _positionType) public view returns (uint256) {
        address[] memory assets = s_whitelistedAssets.values();

        uint256 totalUSDValScaled = 0; // Scaled by priceFeed decimals

        for (uint i = 0; i < assets.length; i++) {
            address _asset = assets[i];
            uint256 userAmountOnSourceRaw;
            uint256 userAmountOnConnectedRaw;

            if (_positionType == 1) { // Lend
                userAmountOnSourceRaw = s_userLendPosition[_user][_asset].amount;
                userAmountOnConnectedRaw = s_userLendPositionOnConnectedChain[_user][_asset].amount;
            } else if (_positionType == 2) { // Borrow
                userAmountOnSourceRaw = s_userBorrowPosition[_user][_asset].amount;
                userAmountOnConnectedRaw = s_userBorrowPositionOnConnectedChain[_user][_asset].amount;
            } else {
                // Handle invalid position type, e.g., revert or skip
                continue;
            }

            if (userAmountOnConnectedRaw == 0 && userAmountOnSourceRaw == 0) continue;
            if (address(s_assetFeed[_asset]) == address(0)) continue; // Ensure price feed exists

            (int256 price, uint8 priceFeedDecimals) = _getAssetPriceData(_asset);
            uint256 localAssetDecimals = s_assetDecimals[_asset];

            uint256 usdAmountOnSourceScaled = 0;
            uint256 usdAmountOnConnectedScaled = 0;

            // Calculate USD value for amount on SOURCE chain (this chain)
            if (userAmountOnSourceRaw > 0) {
                // Correct: Raw amount / (10^asset_decimals) * price
                usdAmountOnSourceScaled = (userAmountOnSourceRaw * uint256(price)) / (10 ** localAssetDecimals);
            }

            // Calculate USD value for amount on CONNECTED chain
            if (userAmountOnConnectedRaw > 0) {
                uint256 connectedAssetDecimals = s_assetDecimalsOnConnectedChain[_asset]; // Decimals of the asset on the CONNECTED chain

                // Normalize userAmountOnConnectedRaw to match localAssetDecimals before pricing with 'price'
                uint256 userAmountOnConnectedNormalized;
                if (connectedAssetDecimals > localAssetDecimals) {
                    userAmountOnConnectedNormalized = userAmountOnConnectedRaw / (10 ** (connectedAssetDecimals - localAssetDecimals));
                } else if (localAssetDecimals > connectedAssetDecimals) {
                    userAmountOnConnectedNormalized = userAmountOnConnectedRaw * (10 ** (localAssetDecimals - connectedAssetDecimals));
                } else { // Decimals are the same
                    userAmountOnConnectedNormalized = userAmountOnConnectedRaw;
                }

                // Correct: Normalized raw amount / (10^local_asset_decimals) * price
                usdAmountOnConnectedScaled = (userAmountOnConnectedNormalized * uint256(price)) / (10 ** localAssetDecimals);
            }

            totalUSDValScaled += (usdAmountOnSourceScaled + usdAmountOnConnectedScaled);
        }

        return totalUSDValScaled;
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

    function getUserPositionForAssetByTypeOnSource(address _asset, address _user, uint8 _positionType) public
    onlyWhitelistedAsset(_asset)
    validAddress(_asset)
    validAddress(_user)
    view returns (uint256) {
        if (_positionType == LEND_POSITION) {
            return s_userLendPosition[_user][_asset].amount;
        } else if (_positionType == BORROW_POSITION) {
            return s_userBorrowPosition[_user][_asset].amount;

        } else {
            revert Error.InvalidPositionType();
        }

    }

    function getUserPositionForAssetByTypeOnDest(address _asset, address _user, uint8 _positionType) public
    onlyWhitelistedAsset(_asset)
    validAddress(_asset)
    validAddress(_user)
    view returns (uint256) {
        if (_positionType == LEND_POSITION) {
            return s_userLendPositionOnConnectedChain[_user][s_assetToAssetOnConnectedChain[_asset]].amount;
        } else if (_positionType == BORROW_POSITION) {
            return s_userBorrowPositionOnConnectedChain[_user][s_assetToAssetOnConnectedChain[_asset]].amount;
        } else {
            revert Error.InvalidPositionType();
        }
    }

    function getAssetDecimalsOnSource(address _asset) public onlyWhitelistedAsset(_asset) validAddress(_asset) view returns (uint8) {
        return s_assetDecimals[_asset];
    }

    function getAssetDecimalsOnDest(address _asset) public onlyWhitelistedAsset(_asset) validAddress(_asset) view returns (uint8) {
        return s_assetDecimalsOnConnectedChain[_asset];
    }

    function getUserPositionForAssetByType(address _asset, address _user, uint8 _positionType) validAddress(_asset) validAddress(_user) public view returns (uint) {
        if (_positionType == 1) {
            return s_userLendPosition[_user][_asset].amount;
        } else if (_positionType == 2) {
            return s_userBorrowPosition[_user][_asset].amount;

        } else {
            revert Error.InvalidPositionType();
        }
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {

        (CrossCreditLibrary.PositionOnConnected memory position, uint8 positionType) = abi.decode(any2EvmMessage.data, (CrossCreditLibrary.PositionOnConnected, uint8));

        if (!s_whitelistedAssets.contains(position.asset)) revert Error.NotWhitelistedAsset();

        console.log("Decoded position.sourceChainID: ", position.sourceChainID);
        console.log("Decoded position.caller: ", position.caller);
        console.log("Decoded position.asset: ", position.asset);
        console.log("Decoded position.amount: ", position.amount);
        console.log("Decoded position.liquidator: ", position.liquidator);
        console.log("Decoded positionType: ", positionType);

        if (positionType == LEND_POSITION) {
            s_userLendPositionOnConnectedChain[position.caller][position.asset].amount = position.amount;
        } else if (positionType == BORROW_POSITION) {
            s_userBorrowPositionOnConnectedChain[position.caller][position.asset].amount = position.amount;
        } else if (positionType == LIQUIDATE_POSITION) {
            s_userLendPosition[position.caller][position.asset].amount = 0;
            s_userBorrowPosition[position.caller][position.asset].amount = 0;
            s_userBorrowPositionOnConnectedChain[position.caller][position.asset].amount = 0;
            s_userLendPositionOnConnectedChain[position.caller][position.asset].amount = 0;

            if (position.asset != i_nativeAssetAddress) {
                IERC20(position.asset).safeTransfer(position.liquidator, position.amount);
            } else {
                (bool success,) = payable(position.liquidator).call{value: position.amount}("");
                if (!success) revert Error.TransferFailed();
            }
        }

        latestMessageId = any2EvmMessage.messageId;
        latestSourceChainSelector = any2EvmMessage.sourceChainSelector;
        latestSender = position.caller;
        latestMessage = "NEW MESSAGE";

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            positionType
        );
    }

    function getLatestMessageDetails()
    public
    view
    returns (bytes32, uint64, address, string memory)
    {
        return (
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage
        );
    }

    function _ccipSend(bytes memory _data) internal returns (bytes32 messageId){
        if (s_receiverOnConnectedChain == address(0)) revert Error.ReceiverAddressNotSet();
        if (!s_isConnectedChainSet) revert Error.ConnectedChainNotSet();
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

    receive() external payable {}

    fallback() external payable {revert Error.FallbackUnsupported();}
}
