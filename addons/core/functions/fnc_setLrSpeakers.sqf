#include "script_component.hpp"

/*
  Name: TFAR_fnc_setLrSpeakers

  Author: NKey
    Sets the speakers setting for the passed radio

  Arguments:
    0: Radio object <OBJECT>
    1: Radio ID <STRING>

  Return Value:
    None

  Example:
    (call TFAR_fnc_activeLrRadio) call TFAR_fnc_setLrSpeakers;

  Public: Yes
*/

params ["_radio_object", "_radio_qualifier"];

private _settings = [_radio_object, _radio_qualifier] call TFAR_fnc_getLrSettings;
private _currentlyEnabled = _settings select TFAR_LR_SPEAKER_OFFSET;
if (_currentlyEnabled) then {
    _settings set [TFAR_LR_SPEAKER_OFFSET, false];
} else {
    _settings set [TFAR_LR_SPEAKER_OFFSET, true];
};

[[_radio_object, _radio_qualifier], _settings] call TFAR_fnc_setLrSettings;

//Read settings directly, getLrSettings would create default settings for radios that have none yet
private _hasSpeakersOn = {
    ((_x select 0) getVariable [_x select 1, []]) param [TFAR_LR_SPEAKER_OFFSET, false]
};

//Flags tell other clients whether to look for speaker radios. Only broadcast on change.
call TFAR_fnc_updateSpeakersEnabled;

//A vehicle has several radios, a backpack only one
private _objectRadios = [[_radio_object, _radio_qualifier]];
if !(_radio_object isKindOf "Bag_Base") then {
    _objectRadios append (_radio_object call TFAR_fnc_getVehicleRadios);
};
private _objectSpeakers = (_objectRadios findIf _hasSpeakersOn) != -1;
if !((_radio_object getVariable ["TFAR_LRSpeakersEnabled", scriptNull]) isEqualTo _objectSpeakers) then {
    _radio_object setVariable ["TFAR_LRSpeakersEnabled", _objectSpeakers, true];
};

//							unit, radio object,		radio ID			speakers
["OnLRspeakersSet", [TFAR_currentUnit, _radio_object, _radio_qualifier, _settings select TFAR_LR_SPEAKER_OFFSET]] call TFAR_fnc_fireEventHandlers;
