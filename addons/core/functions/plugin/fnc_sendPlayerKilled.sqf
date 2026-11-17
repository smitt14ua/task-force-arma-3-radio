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

//Runs on every client (MPKilled). The plugin treats RELEASE_ALL_TANGENTS as a release of
//its own tangent, so only send it for the local unit, or a nearby death would cut our transmission.
if (_this isEqualTo TFAR_currentUnit) then {
    _this call TFAR_fnc_releaseAllTangents;
};

private _name = _this getVariable ["TFAR_pluginUnitName", ""];
if (_name isEqualTo "") then {_name = _this getVariable ["TFAR_unitName", name _this]};
private _request = format["KILLED	%1~", _name];//Async call will always return "OK"
private _result = "task_force_radio_pipe" callExtension _request;
