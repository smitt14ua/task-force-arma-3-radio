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

params ["_player", "", ["_unitName", ""]];

private _request = _this call TFAR_fnc_preparePositionCoordinates;
private _result = "task_force_radio_pipe" callExtension _request;

if (_result != "OK") then {

    if (GVAR(noTSNotConnectedHint) && {_result == "Not connected to TeamSpeak"}) exitWith {};

    //Every position update gets the error, show the (10 second) hint again only once a second or when it changes
    if (tf_lastError
        && {_result isEqualTo (missionNamespace getVariable [QGVAR(lastPluginError), ""])}
        && {diag_tickTime - (missionNamespace getVariable [QGVAR(lastPluginErrorTime), -1]) < 1}
    ) exitWith {};
    GVAR(lastPluginError) = _result;
    GVAR(lastPluginErrorTime) = diag_tickTime;

    [parseText (_result), 10] call TFAR_fnc_showHint;
    tf_lastError = true;
} else {
    if (tf_lastError) then {
        call TFAR_fnc_hideHint;
        tf_lastError = false;
    };
};

//Name the plugin knows this unit by (differs from TFAR_unitName for spectators), reused by sendPlayerKilled.
//The MPKilled handler that calls it is added once per unit by its own machine in TFAR_fnc_ClientInit.
_player setVariable ["TFAR_pluginUnitName", _unitName];
