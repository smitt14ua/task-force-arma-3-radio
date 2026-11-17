#include "script_component.hpp"

/*
  Name: TFAR_fnc_watchProvisionalSettings

  Author: Smith
    The side's shared frequencies didn't arrive from the server yet, so the radio got provisional ones
    (see TFAR_fnc_getDefaultRadioSettings). TFAR_fnc_getSwSettings/getLrSettings don't store them, but a setter
    (e.g. a mission script changing a channel) can. Once the server's frequencies arrive, give them to a radio
    whose stored frequencies are still the provisional ones.

  Arguments:
    0: Is SR radio <BOOL>
    1: Radio <STRING|ARRAY>
    2: Provisional frequencies <ARRAY>

  Return Value:
    None

  Example:
    [true, _radio, _value select 2] call TFAR_fnc_watchProvisionalSettings;

  Public: No
*/

params ["_isSR", "_radio", "_frequencies"];

if (isNil QGVAR(provisionalSettings)) then {GVAR(provisionalSettings) = []};
private _key = [_isSR, _radio];
if (_key in GVAR(provisionalSettings)) exitWith {};
GVAR(provisionalSettings) pushBack _key;

private _sideName = switch (TFAR_currentUnit call BIS_fnc_objectSide) do {
    case west : {"west"};
    case east : {"east"};
    default {"independent"};
};
private _variable = format ["TFAR_freq_%1_%2", ["lr", "sr"] select _isSR, _sideName];

[
    {!isNil (_this select 0)},
    {
        params ["_variable", "_key", "_frequencies"];
        GVAR(provisionalSettings) deleteAt (GVAR(provisionalSettings) find _key);
        _key params ["_isSR", "_radio"];

        private _settings = if (_isSR) then {
            TFAR_RadioSettingsNamespace getVariable _radio
        } else {
            (_radio select 0) getVariable (_radio select 1)
        };
        //Not stored meanwhile (the next get uses the server's frequencies), or changed by the player
        if (isNil "_settings" || {(_settings select 2) isNotEqualTo _frequencies}) exitWith {};

        _settings = +_settings;
        _settings set [2, +((missionNamespace getVariable _variable) select 2)];
        if (_isSR) then {
            [_radio, _settings] call TFAR_fnc_setSwSettings;
        } else {
            [_radio, _settings] call TFAR_fnc_setLrSettings;
        };
    },
    [_variable, _key, _frequencies],
    120,
    {GVAR(provisionalSettings) deleteAt (GVAR(provisionalSettings) find (_this select 1))}
] call CBA_fnc_waitUntilAndExecute;
