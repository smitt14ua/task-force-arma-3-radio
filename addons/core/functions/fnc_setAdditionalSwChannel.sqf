#include "script_component.hpp"

/*
  Name: TFAR_fnc_setAdditionalSwChannel

  Author: NKey
    Sets the additional channel for the passed radio.
    Toggles: if the passed channel already is the additional channel, the additional channel is disabled (-1).
    The OnSWchannelSet event reports the stored channel (-1 when disabled).

  Arguments:
    0: Radio classname <STRING>
    1: 0-based Channel number <NUMBER>

  Return Value:
    None

  Example:
    // SW Radio - Channel 2
    [(call TFAR_fnc_activeSwRadio), 1] call TFAR_fnc_setAdditionalSwChannel;

  Public: Yes
*/

params ["_radio_id", "_channel_to_set"];

private _settings = _radio_id call TFAR_fnc_getSwSettings;
if (isNil "_settings") exitWith {}; //No radio
private _oldChannel = (_settings select TFAR_ADDITIONAL_CHANNEL_OFFSET);
if ((_settings select TFAR_ADDITIONAL_CHANNEL_OFFSET) != _channel_to_set) then {
    _settings set [TFAR_ADDITIONAL_CHANNEL_OFFSET, _channel_to_set];
} else {
    _settings set [TFAR_ADDITIONAL_CHANNEL_OFFSET, -1];
};
[_radio_id, _settings] call TFAR_fnc_setSwSettings;

//							unit, radio ID,		channel, additional, oldChannel
["OnSWchannelSet", [TFAR_currentUnit, _radio_id, _settings select TFAR_ADDITIONAL_CHANNEL_OFFSET, true, _oldChannel]] call TFAR_fnc_fireEventHandlers;
