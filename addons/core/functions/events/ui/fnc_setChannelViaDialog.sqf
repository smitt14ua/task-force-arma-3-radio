#include "script_component.hpp"

/*
  Name: TFAR_fnc_setChannelViaDialog

  Author: Garth de Wet (L-H)
    Sets the channel of the current Dialog radio.

  Arguments:
    0: Mouse button pressed (0,1) <NUMBER>
    1: LR radio <BOOL>
    2: Update formatting. <STRING> (default: nil)

  Return Value:
    None

  Example:
    // LR radio
    [_this select 1, true] call TFAR_fnc_setChannelViaDialog;
    // SW radio
    [_this select 1, false] call TFAR_fnc_setChannelViaDialog;

  Public: Yes
*/

params ["_btn", "_lr", ["_format", ""]];

private _maxChannels = 0;
private _radio = nil;
private _fnc_GetChannel = {};
// Called from an open radio dialog, otherwise (channel cycle keybinds) use the active radio
private _fromDialog = dialog && {!isNil (["TF_sw_dialog_radio", "TF_lr_dialog_radio"] select _lr)};

if (_lr) then {
    _maxChannels = TFAR_MAX_LR_CHANNELS;
    _radio = if (_fromDialog) then {TF_lr_dialog_radio} else {call TFAR_fnc_activeLrRadio};
    _fnc_GetChannel = TFAR_fnc_getLrChannel;
} else {
    _maxChannels = TFAR_MAX_CHANNELS;
    _radio = if (_fromDialog) then {TF_sw_dialog_radio} else {call TFAR_fnc_activeSwRadio};
    _fnc_GetChannel = TFAR_fnc_getSwChannel;
};
if (isNil "_radio") exitWith {};

playSound "TFAR_rotatorPush";
private _cChange = if(_btn == 0)then{-1 + _maxChannels}else {1};
_cChange = ((_radio call _fnc_GetChannel) + _cChange) mod _maxChannels;

if (_lr) then {
    [_radio, _cChange] call TFAR_fnc_setLRChannel;
    if (!_fromDialog) exitWith {};
    if (_format != "") then {
        [_format] call TFAR_fnc_updateLRDialogToChannel;
    } else {
        call TFAR_fnc_updateLRDialogToChannel;
    };
} else {
    [_radio, _cChange] call TFAR_fnc_setSwChannel;
    if (!_fromDialog) exitWith {};
    if (_format != "") then {
        [_format] call TFAR_fnc_updateSWDialogToChannel;
    } else {
        call TFAR_fnc_updateSWDialogToChannel;
    };
};
if (TFAR_showChannelChangedHint) then {[_radio, _lr] call TFAR_fnc_showRadioInfo;};
