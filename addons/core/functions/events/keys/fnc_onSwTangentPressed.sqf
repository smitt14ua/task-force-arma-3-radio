#include "script_component.hpp"

/*
  Name: TFAR_fnc_onSwTangentPressed

  Author: NKey
    Fired when the keybinding for SR is pressed.

  Arguments:
    None

  Return Value:
    Whether or not the event was handled <BOOL>

  Example:
    call TFAR_fnc_onSwTangentPressed;

  Public: No
*/

if (!isMultiplayer) exitWith {private _msg = localize LSTRING(WM_Singleplayer);systemChat _msg;hint _msg;false};

//The SW key still held from an LR chord (Ctrl+Caps with Ctrl let go first: Caps repeats without Ctrl) is not a SW
//press. A new press right after the LR tangent is (this used to block SW for 0.5 s after any LR press).
private _swKeys = (["TFAR", "SWTransmit"] call CBA_fnc_getKeybind) param [8, []];
if (_swKeys findIf {(GVAR(keysHeld) getOrDefault [_x select 0, 1e9]) <= TF_last_lr_tangent_press} != -1) exitWith {false};
//Arma still reports a modifier released a moment ago, see TFAR_fnc_onLRTangentPressed
if ("SWTransmit" call TFAR_fnc_keybindModifiersReleased) exitWith {false};
//The speak volume modifier already pressed the plugin's tangent for direct speech
if (!isNil QGVAR(speakVolumeForcedSpeechTime)) exitWith {false};
if (((TF_tangent_lr_pressed or TF_tangent_sw_pressed)) or {!alive TFAR_currentUnit} or {!call TFAR_fnc_haveSWRadio}) exitWith {false};

if (!call TFAR_fnc_isAbleToUseRadio) exitWith {call TFAR_fnc_unableToUseHint;false};

private _radio = call TFAR_fnc_activeSwRadio;
private _channel = _radio call TFAR_fnc_getSwChannel;
private _currentFrequency = [_radio, _channel + 1] call TFAR_fnc_getChannelFrequency;

if !([0, _radio, _channel, _currentFrequency, false] call TFAR_fnc_startTangentTransmission) exitWith {false};

TF_tangent_sw_pressed = true;
TF_tangent_sw_additional = false;
false
