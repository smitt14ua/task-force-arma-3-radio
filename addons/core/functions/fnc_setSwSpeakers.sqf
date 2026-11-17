#include "script_component.hpp"

/*
  Name: TFAR_fnc_setSwSpeakers

  Author: NKey
    Sets the speakers setting for the SW radio

  Arguments:
    0: Radio <STRING>

  Return Value:
    None

  Example:
    [call TFAR_fnc_activeSWRadio] call TFAR_fnc_setSwSpeakers;

  Public: Yes
*/

params ["_radio_id"];

private _settings = _radio_id call TFAR_fnc_getSwSettings;
if (isNil "_settings") exitWith {}; //No radio
private _currentlyEnabled = _settings select TFAR_SW_SPEAKER_OFFSET;
if (_currentlyEnabled) then {
    _settings set [TFAR_SW_SPEAKER_OFFSET, false];
} else {
    _settings set [TFAR_SW_SPEAKER_OFFSET, true];
};

[_radio_id, _settings] call TFAR_fnc_setSwSettings;

call TFAR_fnc_updateSpeakersEnabled;

//									unit, radio ID,	speakers
["OnSWspeakersSet", [TFAR_currentUnit, _radio_id, _settings select TFAR_SW_SPEAKER_OFFSET]] call TFAR_fnc_fireEventHandlers;
