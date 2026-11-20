#include "script_component.hpp"

/*
  Name: TFAR_fnc_sendPlayerKilled

  Author: NKey
    Notifies the plugin that a unit has been killed.

  Arguments:
    killed unit <OBJECT>

  Return Value:
    None

  Example:
    player call TFAR_fnc_sendPlayerKilled;

  Public: Yes
*/

_this setRandomLip false;

//Runs on every client (MPKilled), but only our own unit's death goes to the plugin (as in master, where the
//local Killed EH never fired for remote units). On KILLED every plugin re-evaluates the mute state of the whole
//channel, so sending every death from every client flooded the TeamSpeak server with mute/unmute requests
//(voices dropped on a 100 player server). Remote deaths reach the plugin anyway: dead players' POS stop.
//player too: our own body can die while we remote control another unit (TFAR_currentUnit).
if !(_this isEqualTo TFAR_currentUnit || {_this isEqualTo player}) exitWith {};

//The plugin treats RELEASE_ALL_TANGENTS as a release of its own tangent. Not when only our body died while we
//remote control another unit, that would cut the controlled unit's transmission.
if (_this isEqualTo TFAR_currentUnit) then {
    _this call TFAR_fnc_releaseAllTangents;
};

//The plugin only knows players, by name. A unit a player remote controls is sent under that player's name, but
//TFAR_pluginUnitName stays on the unit after control ends: a later death of that AI must not mark the former
//controller dead. So use the current controller's name, and skip units that are neither a player nor controlled.
private _controllerIndex = allPlayers findIf {(_x getVariable ["TFAR_controlledUnit", objNull]) isEqualTo _this};
private _name = "";
if (_controllerIndex == -1) then {
    if (_this in allPlayers) then {
        _name = _this getVariable ["TFAR_pluginUnitName", ""];
        if (_name isEqualTo "") then {_name = _this getVariable ["TFAR_unitName", name _this]};
    };
} else {
    private _controller = allPlayers select _controllerIndex;
    _name = _controller getVariable ["TFAR_unitName", name _controller];
};
if (_name isEqualTo "") exitWith {};

private _request = format["KILLED	%1~", _name];//Async call will always return "OK"
private _result = "task_force_radio_pipe" callExtension _request;
