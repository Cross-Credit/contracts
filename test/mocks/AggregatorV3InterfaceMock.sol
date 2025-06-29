// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AggregatorV3InterfaceMock {
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
    // Function to set return values for decimals
    function setDecimalsReturn(uint8 _value0) public {
        _decimalsReturn_0 = _value0;
    }

    // Function to set return values for description
    function setDescriptionReturn(string memory _value0) public {
        _descriptionReturn_0 = _value0;
    }

    // Function to set return values for getRoundData
    function setGetRoundDataReturn(uint80 _value0, int256 _value1, uint256 _value2, uint256 _value3, uint80 _value4) public {
        _getRoundDataReturn_0 = _value0;
        _getRoundDataReturn_1 = _value1;
        _getRoundDataReturn_2 = _value2;
        _getRoundDataReturn_3 = _value3;
        _getRoundDataReturn_4 = _value4;
    }

    // Function to set return values for latestRoundData
    function setLatestRoundDataReturn(uint80 _value0, int256 _value1, uint256 _value2, uint256 _value3, uint80 _value4) public {
        _latestRoundDataReturn_0 = _value0;
        _latestRoundDataReturn_1 = _value1;
        _latestRoundDataReturn_2 = _value2;
        _latestRoundDataReturn_3 = _value3;
        _latestRoundDataReturn_4 = _value4;
    }

    // Function to set return values for version
    function setVersionReturn(uint256 _value0) public {
        _versionReturn_0 = _value0;
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
    uint8 private _decimalsReturn_0;
    string private _descriptionReturn_0;
    uint80 private _getRoundDataReturn_0;
    int256 private _getRoundDataReturn_1;
    uint256 private _getRoundDataReturn_2;
    uint256 private _getRoundDataReturn_3;
    uint80 private _getRoundDataReturn_4;
    uint80 private _latestRoundDataReturn_0;
    int256 private _latestRoundDataReturn_1;
    uint256 private _latestRoundDataReturn_2;
    uint256 private _latestRoundDataReturn_3;
    uint80 private _latestRoundDataReturn_4;
    uint256 private _versionReturn_0;

    //<>=============================================================<>
    //||                                                             ||
    //||          ⚠️  VIEW FUNCTIONS - DO NOT MODIFY  ⚠️            ||
    //||                                                             ||
    //<>=============================================================<>
    // Mock implementation of decimals
    function decimals() public view returns (uint8) {
        return _decimalsReturn_0;
    }

    // Mock implementation of description
    function description() public view returns (string memory) {
        return _descriptionReturn_0;
    }

    // Mock implementation of getRoundData
    function getRoundData(uint80 /*_roundId*/) public view returns (uint80, int256, uint256, uint256, uint80) {
        return (_getRoundDataReturn_0, _getRoundDataReturn_1, _getRoundDataReturn_2, _getRoundDataReturn_3, _getRoundDataReturn_4);
    }

    // Mock implementation of latestRoundData
    function latestRoundData() public view returns (uint80, int256, uint256, uint256, uint80) {
        return (_latestRoundDataReturn_0, _latestRoundDataReturn_1, _latestRoundDataReturn_2, _latestRoundDataReturn_3, _latestRoundDataReturn_4);
    }

    // Mock implementation of version
    function version() public view returns (uint256) {
        return _versionReturn_0;
    }

}