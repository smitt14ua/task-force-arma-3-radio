#include "script_component.hpp"

/*
  Name: TFAR_fnc_onLRTangentPressed

  Author: NKey
    Fired when the keybinding for LR is pressed.

  Arguments:
    None

  Return Value:
    Whether or not the event was handled <BOOL>

  Example:
    call TFAR_fnc_onLRTangentPressed;

  Public: No
*/
if (!isMultiplayer) exitWith {private _msg = localize LSTRING(WM_Singleplayer);systemChat _msg;hint _msg;false};

//Arma still reports a modifier released a moment ago (Ctrl+Caps let go, then Caps): that is the SW key, see
//TFAR_fnc_onTangentPressedHack
if ("LRTransmit" call TFAR_fnc_keybindModifiersReleased) exitWith {false};
if (time - TF_last_lr_tangent_press < 0.1) exitWith {TF_last_lr_tangent_press = time;false};
TF_last_lr_tangent_press = time;
//The speak volume modifier already pressed the plugin's tangent for direct speech
if (!isNil QGVAR(speakVolumeForcedSpeechTime)) exitWith {false};
if ((TF_tangent_lr_pressed or TF_tangent_sw_pressed) or {!alive TFAR_currentUnit} or {!call TFAR_fnc_haveLRRadio}) exitWith {false};

if (!call TFAR_fnc_isAbleToUseRadio) exitWith {call TFAR_fnc_unableToUseHint;false};
private _radio = call TFAR_fnc_activeLrRadio;
private _channel = _radio call TFAR_fnc_getLrChannel;
private _currentFrequency = [_radio, _channel + 1] call TFAR_fnc_getChannelFrequency;

if !([1, _radio, _channel, _currentFrequency, false] call TFAR_fnc_startTangentTransmission) exitWith {false};

TF_tangent_lr_pressed = true;
TF_tangent_lr_additional = false;
false
