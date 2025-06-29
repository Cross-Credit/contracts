// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IRouterClientMock {
    //<>=============================================================<>
    //||                                                             ||
    //||                    NON-VIEW FUNCTIONS                       ||
    //||                                                             ||
    //<>=============================================================<>

    //<>=============================================================<>
    //||                                                             ||
    //||                    SETTER FUNCTIONS                         ||
    //||                                                             ||
    //<>=============================================================<>
    // Function to set return values for ccipSend
    function setCcipSendReturn(bytes32 _value0) public {
        _ccipSendReturn_0 = _value0;
    }

    // Function to set return values for getFee
    function setGetFeeReturn(uint256 _value0) public {
        _getFeeReturn_0 = _value0;
    }

    // Function to set return values for isChainSupported
    function setIsChainSupportedReturn(bool _value0) public {
        _isChainSupportedReturn_0 = _value0;
    }


    /*******************************************************************
     *   ⚠️ WARNING ⚠️ WARNING ⚠️ WARNING ⚠️ WARNING ⚠️ WARNING ⚠️  *
     *-----------------------------------------------------------------*
     *      Generally you only need to modify the sections above.      *
     *          The code below handles system operations.              *
     *******************************************************************/

    //<>=============================================================<>
    //||                                                             ||
    //||        ⚠️  STRUCT DEFINITIONS - DO NOT MODIFY  ⚠️          ||
    //||                                                             ||
    //<>=============================================================<>
    // Struct definition for Client_EVM2AnyMessage
    struct Client_EVM2AnyMessage {
        bytes receiver;
        bytes data;
        Client_EVMTokenAmount[] tokenAmounts;
        address feeToken;
        bytes extraArgs;
    }

    // Struct definition for Client_EVMTokenAmount
    struct Client_EVMTokenAmount {
        address token;
        uint256 amount;
    }


    //<>=============================================================<>
    //||                                                             ||
    //||        ⚠️  EVENTS DEFINITIONS - DO NOT MODIFY  ⚠️          ||
    //||                                                             ||
    //<>=============================================================<>

    //<>=============================================================<>
    //||                                                             ||
    //||         ⚠️  INTERNAL STORAGE - DO NOT MODIFY  ⚠️           ||
    //||                                                             ||
    //<>=============================================================<>
    bytes32 private _ccipSendReturn_0;
    uint256 private _getFeeReturn_0;
    bool private _isChainSupportedReturn_0;

    //<>=============================================================<>
    //||                                                             ||
    //||          ⚠️  VIEW FUNCTIONS - DO NOT MODIFY  ⚠️            ||
    //||                                                             ||
    //<>=============================================================<>
    // Mock implementation of ccipSend
    function ccipSend(uint64 /*destinationChainSelector*/, Client_EVM2AnyMessage memory /*message*/) public view returns (bytes32) {
        return _ccipSendReturn_0;
    }

    // Mock implementation of getFee
    function getFee(uint64 /*destinationChainSelector*/, Client_EVM2AnyMessage memory /*message*/) public view returns (uint256) {
        return _getFeeReturn_0;
    }

    // Mock implementation of isChainSupported
    function isChainSupported(uint64 /*destChainSelector*/) public view returns (bool) {
        return _isChainSupportedReturn_0;
    }

}