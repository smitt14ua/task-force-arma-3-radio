#include "script_component.hpp"

/*
  Name: TFAR_fnc_endTangentTransmission

  Author: Smith
    Ends the running radio transmission with exactly the radio, channel and frequency it was started with,
    even if the active radio, channel or frequency changed meanwhile.
    The plugin processes the newest message first, so a RELEASED sent in the same poll interval as its
    PRESSED would be handled (and dropped) before it. A short press is therefore released delayed.

  Arguments:
    0: Only end a transmission of this radio type, 0 = SW, 1 = LR, -1 = any <NUMBER> (default: -1)

  Return Value:
    None

  Example:
    [0] call TFAR_fnc_endTangentTransmission;

  Public: No
*/

params [["_type", -1, [0]]];

//Set by TFAR_fnc_doSRTransmit/doLRTransmit, cleared by TFAR_fnc_doSRTransmitEnd/doLRTransmitEnd
private _transmission = missionNamespace getVariable [QGVAR(tangentTransmission), []];
//Not transmitting (radio was off, or a channel change already ended it) or already waiting for the release
if (_transmission isEqualTo [] || {_transmission isEqualTo (missionNamespace getVariable [QGVAR(pendingTangentRelease), []])}) exitWith {};

_transmission params ["_transmissionType", "_radio", "_channel", "_frequency", "_additional", "_pressTime"];
if (_type != -1 && {_type != _transmissionType}) exitWith {};

//Minimum time between PRESSED and RELEASED, the plugin polls messages every 20ms at most
private _remaining = 0.06 - (diag_tickTime - _pressTime);
if (_remaining <= 0) exitWith {
    [_radio, _channel, _frequency, _additional] call ([TFAR_fnc_doSRTransmitEnd, TFAR_fnc_doLRTransmitEnd] select _transmissionType);
};

GVAR(pendingTangentRelease) = _transmission;
[{
    //Cancelled by pressing the same tangent again
    if !((missionNamespace getVariable [QGVAR(pendingTangentRelease), []]) isEqualTo _this) exitWith {};
    GVAR(pendingTangentRelease) = [];
    //Ended meanwhile by something else
    if !((missionNamespace getVariable [QGVAR(tangentTransmission), []]) isEqualTo _this) exitWith {};

    _this params ["_type", "_radio", "_channel", "_frequency", "_additional"];
    [_radio, _channel, _frequency, _additional] call ([TFAR_fnc_doSRTransmitEnd, TFAR_fnc_doLRTransmitEnd] select _type);
}, _transmission, _remaining] call CBA_fnc_waitAndExecute;
