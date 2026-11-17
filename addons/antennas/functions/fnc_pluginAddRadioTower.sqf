#include "script_component.hpp"

/*
  Name: TFAR_antennas_fnc_pluginAddRadioTower

  Author: Dedmen
    Tells Teamspeak that there is a new Tower
    Performancewise it's best to collect towers and pass multiple in one call.

  Arguments:
    0: the Tower <OBJECT>

  Return Value:
    None

  Example:
    [_tower1, _tower2] call TFAR_antennas_fnc_pluginAddRadioTower;

  Public: yes
*/

TRACE_1("TFAR_antennas_fnc_pluginAddRadioTower",_this);

// Async plugin messages must not exceed 2040 bytes, batch by message length ("RadioTwrAdd<TAB>" + data + "~")
private _maxDataLength = 2040 - 13;
private _towerData = [];
private _dataLength = 0;

private _fnc_sendBatch = {
    #ifdef DEBUG_MODE_FULL
        diag_log _towerData;
        systemChat "sendBatch";
    #endif
    "task_force_radio_pipe" callExtension format["RadioTwrAdd	%1~", _towerData joinString TF_new_line];
};

{
    private _range = [GVAR(radioTowerList),_x] call CBA_fnc_hashGet;
    // The plugin compares against ASL player positions
    private _entry = [netID _x,_range,getPosASL _x] joinString ";";
    private _entryLength = count _entry + 1; // + newline separator

    if (_towerData isNotEqualTo [] && {_dataLength + _entryLength > _maxDataLength}) then {
        call _fnc_sendBatch;
        _towerData = [];
        _dataLength = 0;
    };

    _towerData pushBack _entry;
    _dataLength = _dataLength + _entryLength;
} forEach _this;

if (_towerData isNotEqualTo []) then {
    call _fnc_sendBatch;
};
