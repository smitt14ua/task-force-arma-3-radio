#include "script_component.hpp"

/*
  Name: TFAR_fnc_startTangentTransmission

  Author: Smith
    Starts the transmission of a tangent keybinding.
    If the release of a short press is still delayed (see TFAR_fnc_endTangentTransmission) and the same
    transmission is pressed again, the delayed release is cancelled and the transmission continues.
    Any other transmission is refused until that release was sent, the plugin would drop its PRESSED.

  Arguments:
    0: Radio type, 0 = SW, 1 = LR <NUMBER>
    1: Radio <STRING|ARRAY>
    2: Radio channel <NUMBER>
    3: Radio frequency <STRING>
    4: Is Additional Channel <BOOL>

  Return Value:
    Whether the transmission is running <BOOL>

  Example:
    [0, _radio, _channel, _currentFrequency, false] call TFAR_fnc_startTangentTransmission;

  Public: No
*/

params ["_type", "_radio", "_channel", "_frequency", "_additional"];

private _pending = missionNamespace getVariable [QGVAR(pendingTangentRelease), []];
if (_pending isNotEqualTo []) exitWith {
    private _resume = (_pending select [0, 5]) isEqualTo [_type, _radio, _channel, _frequency, _additional]
        && {(missionNamespace getVariable [QGVAR(tangentTransmission), []]) isEqualTo _pending};
    if (_resume) then {
        GVAR(pendingTangentRelease) = [];
    };
    _resume
};

[_radio, _channel, _frequency, _additional] call ([TFAR_fnc_doSRTransmit, TFAR_fnc_doLRTransmit] select _type)
