#include "script_component.hpp"

/*
  Name: TFAR_fnc_getSwSettings

  Author: NKey, Garth de Wet (L-H)
    Returns the current settings for the passed radio.

  Arguments:
    Radio classname <STRING>

  Return Value:
    settings <ARRAY>

  Example:
    (call TFAR_fnc_activeSwRadio) call TFAR_fnc_getSwSettings;

  Public: Yes
*/
params[["_radio", "", [""]]];

//No radio (e.g. no active SR radio), don't create and cache settings for it
if (_radio isEqualTo "") exitWith {nil};

private _value = TFAR_RadioSettingsNamespace getVariable _radio;
if (!isNil "_value") exitWith {_value};

private _provisional = false;
if (isNil QGVAR(saved_active_sr_settings)) then  {
    _value = [true, TFAR_currentUnit, _radio] call DFUNC(getDefaultRadioSettings);
    _provisional = GVAR(defaultSettingsProvisional);
} else {
    _value = +GVAR(saved_active_sr_settings);
    GVAR(saved_active_sr_settings) = nil;
};

//The side's frequencies didn't arrive from the server yet, don't store the provisional settings
if (_provisional) exitWith {_value};

[_radio, _value, true] call TFAR_fnc_setSwSettings;

_value
