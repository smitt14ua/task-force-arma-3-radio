#include "script_component.hpp"

/*
  Name: TFAR_fnc_onAdditionalSwTangentPressed

  Author: NKey
    Fired when the additional keybinding for SR is pressed.

  Arguments:
    None

  Return Value:
    Whether or not the event was handled <BOOL>

  Example:
    call TFAR_fnc_onAdditionalSwTangentPressed;

  Public: No
*/

if (!isMultiplayer) exitWith {private _msg = localize LSTRING(WM_Singleplayer);systemChat _msg;hint _msg;false};

//The speak volume modifier already pressed the plugin's tangent for direct speech
if (!isNil QGVAR(speakVolumeForcedSpeechTime)) exitWith {false};
if ((TF_tangent_lr_pressed or TF_tangent_sw_pressed) or {!alive TFAR_currentUnit} or {!call TFAR_fnc_haveSWRadio}) exitWith {false};

if (!call TFAR_fnc_isAbleToUseRadio) exitWith {call TFAR_fnc_unableToUseHint;false};

private _radio = call TFAR_fnc_activeSwRadio;
private _additionalChannel = _radio call TFAR_fnc_getAdditionalSwChannel;
if (_additionalChannel < 0) exitWith {false}; //No Additional Channel set
private _currentFrequency = [_radio, _additionalChannel + 1] call TFAR_fnc_getChannelFrequency;

if !([0, _radio, _additionalChannel, _currentFrequency, true] call TFAR_fnc_startTangentTransmission) exitWith {false};

TF_tangent_sw_pressed = true;
TF_tangent_sw_additional = true;
false
