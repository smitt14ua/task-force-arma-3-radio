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
private _currentlyEnabled = _settings select TFAR_SW_SPEAKER_OFFSET;
if (_currentlyEnabled) then {
    _settings set [TFAR_SW_SPEAKER_OFFSET, false];
} else {
    _settings set [TFAR_SW_SPEAKER_OFFSET, true];
};

[_radio_id, _settings] call TFAR_fnc_setSwSettings;

//Flag tells other clients whether to look for speaker radios. Only broadcast on change.
//Read settings directly, getSwSettings would create default settings for radios that have none yet
private _unitSpeakers = ((TFAR_currentUnit call TFAR_fnc_radiosList) findIf {
    (TFAR_RadioSettingsNamespace getVariable [_x, []]) param [TFAR_SW_SPEAKER_OFFSET, false]
}) != -1;
if !((TFAR_currentUnit getVariable ["TFAR_SRSpeakersEnabled", scriptNull]) isEqualTo _unitSpeakers) then {
    TFAR_currentUnit setVariable ["TFAR_SRSpeakersEnabled", _unitSpeakers, true];
};

//									unit, radio ID,	speakers
["OnSWspeakersSet", [TFAR_currentUnit, _radio_id, _settings select TFAR_SW_SPEAKER_OFFSET]] call TFAR_fnc_fireEventHandlers;
