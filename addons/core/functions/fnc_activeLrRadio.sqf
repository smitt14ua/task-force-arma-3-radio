#include "script_component.hpp"

/*
  Name: TFAR_fnc_activeLrRadio

  Author: NKey
    Returns the active LR radio.

  Arguments:
    None

  Return Value:
    active LR radio, nil if there is none <ARRAY>

  Example:
    _radio = call TFAR_fnc_activeLRRadio;

  Public: Yes
*/

//Reselect when the controlled unit changed (Zeus remote control and release), so its own radio becomes active
private _activeRadioUnit = missionNamespace getVariable "TFAR_activeLrRadioUnit";
if (isNil "_activeRadioUnit" || {_activeRadioUnit isNotEqualTo TFAR_currentUnit}) then {
    if (!isNil "_activeRadioUnit") then {
        TF_lr_active_radio = nil;
    };
    TFAR_activeLrRadioUnit = TFAR_currentUnit;
};

private _radios = TFAR_currentUnit call TFAR_fnc_lrRadiosList;

if (isNil "TF_lr_active_radio") then {
    TF_lr_active_radio = _radios param [0,nil];
} else {
    private _found = _radios findIf {_x isEqualTo TF_lr_active_radio};
    if (_found == -1) then {
        TF_lr_active_radio = _radios param [0,nil];
    };
};

if (!isNil "TFAR_OverrideActiveLRRadio") exitWith {
    private _radioObject = TFAR_OverrideActiveLRRadio select 0;
    private _distObject = [objectParent _radioObject, _radioObject] select isNull objectParent _radioObject;

    if (TFAR_currentUnit distance _distObject > TFAR_MAXREMOTELRRADIODISTANCE) then {
        TFAR_OverrideActiveLRRadio = nil;
        missionNamespace getVariable "TF_lr_active_radio" //nil-safe, there may be no LR radio
    } else {
        TFAR_OverrideActiveLRRadio
    };
};

missionNamespace getVariable "TF_lr_active_radio" //nil-safe, there may be no LR radio
