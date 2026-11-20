#include "script_component.hpp"

/*
  Name: TFAR_fnc_sendMuteSpectators

  Author: Smith
    Sends the muteSpectators setting to the plugin, but only when the plugin can take it.
    Plugins older than this setting show a blocking "invalid config key" message box (which freezes the game),
    and false is the plugin default. So it is sent when enabled, when it was enabled earlier in this game session
    (the plugin keeps it until told otherwise, also across missions), or when the plugin reports a version that
    knows it (official builds 1.0.339+ and 1.1+).

  Arguments:
    0: Mute spectators <BOOL>

  Return Value:
    None

  Example:
    [true] call TFAR_fnc_sendMuteSpectators;

  Public: No
*/

params [["_enabled", false, [false]]];

//setPluginSetting sends nothing before the mission started (CBA runs setting scripts in the briefing), so don't
//remember a send that didn't happen
if (getClientStateNumber != 10) exitWith {};

private _send = _enabled || {uiNamespace getVariable [QGVAR(muteSpectatorsSent), false]} || {
    private _version = ((call TFAR_fnc_getTeamspeakPluginVersion) splitString ".") apply {parseNumber _x};
    _version params [["_major", 0], ["_minor", 0], ["_build", 0]];
    _major > 1 || {_major == 1 && {_minor > 0 || {_build >= 339}}}
};
if (!_send) exitWith {};

uiNamespace setVariable [QGVAR(muteSpectatorsSent), true];
["muteSpectators", _enabled] call TFAR_fnc_setPluginSetting;
