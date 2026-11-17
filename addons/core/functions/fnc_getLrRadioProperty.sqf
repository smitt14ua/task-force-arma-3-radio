#include "script_component.hpp"

/*
  Name: TFAR_fnc_getLrRadioProperty

  Author: Garth de Wet (L-H)
    returns specified radio property

  Arguments:
    0: Backpack/vehicle <OBJECT>
    1: Property name <STRING>

  Return Value:
    Value of property <NUMBER|TEXT>

  Example:
    [(vehicle player), "TF_hasLRradio"] call TFAR_fnc_getLrRadioProperty;

  Public: Yes
*/

params ["_radio", "_property", ["_default", ""]];

private _propertyGetVariable = _radio getVariable _property;

if (!isNil "_propertyGetVariable") exitWith {_propertyGetVariable};

if (_radio isKindOf "Bag_Base") exitWith {[typeOf _radio, _property, _default] call TFAR_fnc_getVehicleConfigProperty};

// Number/Text property (or _api variant) on the vehicle itself. configNull marks "not defined"; the getter caches the lookup.
private _vehicleProperty = [typeOf _radio, _property, configNull] call TFAR_fnc_getVehicleConfigProperty;
if (!(_vehicleProperty isEqualType configNull) && {!(_vehicleProperty isEqualType [])}) exitWith {_vehicleProperty};

private _radioTypeVariable = _radio getVariable "TF_RadioType";
if (!isNil "_radioTypeVariable") exitWith {[_radioTypeVariable, _property, _default] call TFAR_fnc_getVehicleConfigProperty};

private _radioTypeConfig = [typeOf _radio, "tf_RadioType"] call TFAR_fnc_getVehicleConfigProperty;
if (_radioTypeConfig != "") exitWith {[_radioTypeConfig, _property, _default] call TFAR_fnc_getVehicleConfigProperty};

private _isAirRadio = (typeOf _radio) isKindOf "Air";

private _radioClassname = "";
switch (_radio call TFAR_fnc_getVehicleSide) do {
    case west: {
        _radioClassname = [TFAR_DefaultRadio_Backpack_West,TFAR_DefaultRadio_Airborne_West] select _isAirRadio;
    };
    case east: {
        _radioClassname = [TFAR_DefaultRadio_Backpack_East,TFAR_DefaultRadio_Airborne_East] select _isAirRadio;
    };
    default {
        _radioClassname = [TFAR_DefaultRadio_Backpack_Independent,TFAR_DefaultRadio_Airborne_Independent] select _isAirRadio;
    };
};

[_radioClassname, _property, _default] call TFAR_fnc_getVehicleConfigProperty;
