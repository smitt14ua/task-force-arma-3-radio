#include "script_component.hpp"

/*
  Name: TFAR_fnc_startTangentTransmission

  Author: Smith
    Starts the transmission of a tangent keybinding.
    If the release of a short press is still delayed (see TFAR_fnc_endTangentTransmission) and the same
    transmission is pressed again, the delayed release is cancelled and the transmission continues.
    The plugin handles the newest message first, so a PRESSED in the same poll interval as the RELEASED before it
    would be dropped. Any other transmission therefore starts once that release was sent and 60ms passed,
    if its tangent is still held then.

  Arguments:
    0: Radio type, 0 = SW, 1 = LR <NUMBER>
    1: Radio <STRING|ARRAY>
    2: Radio channel <NUMBER>
    3: Radio frequency <STRING>
    4: Is Additional Channel <BOOL>

  Return Value:
    Whether the transmission is running or about to start <BOOL>

  Example:
    [0, _radio, _channel, _currentFrequency, false] call TFAR_fnc_startTangentTransmission;

  Public: No
*/

params ["_type", "_radio", "_channel", "_frequency", "_additional"];

private _pending = missionNamespace getVariable [QGVAR(pendingTangentRelease), []];
if (_pending isNotEqualTo []
    && {(_pending select [0, 5]) isEqualTo [_type, _radio, _channel, _frequency, _additional]}
    && {(missionNamespace getVariable [QGVAR(tangentTransmission), []]) isEqualTo _pending}
) exitWith {
    GVAR(pendingTangentRelease) = [];
    true
};

if (_pending isEqualTo [] && {diag_tickTime - (missionNamespace getVariable [QGVAR(lastTangentRelease), -1]) >= 0.06}) exitWith {
    [_radio, _channel, _frequency, _additional] call ([TFAR_fnc_doSRTransmit, TFAR_fnc_doLRTransmit] select _type)
};

//Too close to a RELEASED: start later. The caller sets the tangent's pressed flag on true, so it is checked then.
[
    {
        (missionNamespace getVariable [QGVAR(pendingTangentRelease), []]) isEqualTo []
        && {diag_tickTime - (missionNamespace getVariable [QGVAR(lastTangentRelease), -1]) >= 0.06}
    },
    {
        params ["_type", "_radio", "_channel", "_frequency", "_additional"];
        private _held = if (_type == 0) then {
            TF_tangent_sw_pressed && {TF_tangent_sw_additional isEqualTo _additional}
        } else {
            TF_tangent_lr_pressed && {TF_tangent_lr_additional isEqualTo _additional}
        };
        //Released meanwhile, or something else started transmitting
        if (!_held || {(missionNamespace getVariable [QGVAR(tangentTransmission), []]) isNotEqualTo []}) exitWith {};
        [_radio, _channel, _frequency, _additional] call ([TFAR_fnc_doSRTransmit, TFAR_fnc_doLRTransmit] select _type);
    },
    _this,
    1
] call CBA_fnc_waitUntilAndExecute;

true
