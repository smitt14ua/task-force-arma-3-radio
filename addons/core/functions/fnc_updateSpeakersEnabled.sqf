#include "script_component.hpp"

/*
  Name: TFAR_fnc_updateSpeakersEnabled

  Author: Smith
    Recalculates the public TFAR_SRSpeakersEnabled / TFAR_LRSpeakersEnabled flags of the current unit.
    Other clients use these flags to decide whether to look for speaker radios on that unit.
    Flags are only broadcast when their value changes.

  Arguments:
    None

  Return Value:
    None

  Example:
    call TFAR_fnc_updateSpeakersEnabled;

  Public: No
*/

//Settings namespace is published by the server and can still be missing early on a client
if (isNil "TFAR_currentUnit" || {isNull TFAR_currentUnit} || {isNil "TFAR_RadioSettingsNamespace"}) exitWith {};

//Read settings directly, getSw/LrSettings would create default settings for radios that have none yet
private _srSpeakers = ((TFAR_currentUnit call TFAR_fnc_radiosList) findIf {
    (TFAR_RadioSettingsNamespace getVariable [_x, []]) param [TFAR_SW_SPEAKER_OFFSET, false]
}) != -1;
if !((TFAR_currentUnit getVariable ["TFAR_SRSpeakersEnabled", scriptNull]) isEqualTo _srSpeakers) then {
    TFAR_currentUnit setVariable ["TFAR_SRSpeakersEnabled", _srSpeakers, true];
};

private _lrSpeakers = ((TFAR_currentUnit call TFAR_fnc_lrRadiosList) findIf {
    ((_x select 0) getVariable [_x select 1, []]) param [TFAR_LR_SPEAKER_OFFSET, false]
}) != -1;
if !((TFAR_currentUnit getVariable ["TFAR_LRSpeakersEnabled", scriptNull]) isEqualTo _lrSpeakers) then {
    TFAR_currentUnit setVariable ["TFAR_LRSpeakersEnabled", _lrSpeakers, true];
};
