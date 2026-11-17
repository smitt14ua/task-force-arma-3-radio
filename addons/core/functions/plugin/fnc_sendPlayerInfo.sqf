#include "script_component.hpp"

/*
  Name: TFAR_fnc_sendPlayerInfo

  Author: NKey
    Notifies the plugin about a player

  Arguments:
    0: Unit <OBJECT>
    1: Is unit close to player <BOOL>
    2: Unit name <STRING>

  Return Value:
    None

  Example:
    [player, true, "Guy"] call TFAR_fnc_sendPlayerInfo;

  Public: Yes
*/

params ["_player"];

private _request = _this call TFAR_fnc_preparePositionCoordinates;
private _result = "task_force_radio_pipe" callExtension _request;

if (_result != "OK") then {

    if (GVAR(noTSNotConnectedHint) && {_result == "Not connected to TeamSpeak"}) exitWith {};

    [parseText (_result), 10] call TFAR_fnc_showHint;
    tf_lastError = true;
} else {
    if (tf_lastError) then {
        call TFAR_fnc_hideHint;
        tf_lastError = false;
    };
};

//#TODO this is a bad place to do it, why check every update... 
//"Killed" only fires where the unit is local, so it never fired for other players. MPKilled fires on every machine,
//and only once per machine even if every client adds it. Variable is local, so each client adds it only once per unit.
if !(_player getVariable ["TFAR_killedEHAttached",false]) then {
    _player addMPEventHandler ["MPKilled", {
        if (hasInterface && {!isNil "TFAR_currentUnit"}) then {(_this select 0) call TFAR_fnc_sendPlayerKilled};
    }];
    _player setVariable ["TFAR_killedEHAttached", true];
};
