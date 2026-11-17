#include "script_component.hpp"

/*
  Name: TFAR_fnc_forceSpectator

  Author: NKey
    If second parameter is true player will moved to spectator mode
    If false - normal behaviour will be restored.

  Arguments:
    0: player <OBJECT>
    1: force <BOOL>

  Return Value:
    None

  Example:
    [player, true] call TFAR_fnc_forceSpectator;

  Public: Yes
*/

params ["_player", "_value"];

_player call TFAR_fnc_releaseAllTangents; //Stop all radio transmissions

private _wasSpectator = _player getVariable ["TFAR_forceSpectator", false];
_player setVariable ["TFAR_forceSpectator", _value, true];

//Name the plugin knows us by (see TFAR_fnc_sendFrequencyInfo). A dead unit's name isn't usable, so use the name
//cached while alive; profileName lacks the " (2)" Arma adds to duplicate names.
private _name = if (alive _player) then {
    name _player
} else {
    _player getVariable [QGVAR(aliveName), [name _player, profileName] select (_player isEqualTo player)]
};
_player setVariable ["TFAR_spectatorName", (_player getVariable ["TFAR_unitName", _name]), true];

if (TFAR_ShowVolumeHUD && _value) then { //Don't have a voice in spectator Mode so hide the HUD
    (QGVAR(HUDVolumeIndicatorRsc) call BIS_fnc_rscLayer) cutText ["", "PLAIN"];
};

//Leaving spectator without respawning (TFAR_fnc_processRespawn restores it on respawn) has to bring the HUD back
if (TFAR_ShowVolumeHUD && {!_value} && {_wasSpectator} && {_player isEqualTo TFAR_currentUnit || {_player isEqualTo player}}) then {
    (QGVAR(HUDVolumeIndicatorRsc) call BIS_fnc_rscLayer) cutRsc [QGVAR(HUDVolumeIndicatorRsc), "PLAIN", 0, true];
    call TFAR_fnc_updateSpeakVolumeUI;
};
