#include "script_component.hpp"

/*
  Name: TFAR_static_radios_fnc_instanciatedRadio

  Author: Dedmen
    Instanciates Radio if it isn't already

  Arguments:
    0: The weaponholder containing the Radio <OBJECT>

  Return Value:
    classname of instanciate Radio <STRING>

  Example:
    _this call TFAR_static_radios_fnc_instanciatedRadio;

  Public: No
*/
params ["_radioContainer"];

private _radioClass = ((getItemCargo _radioContainer) select 0) param [0, ""];
if (
    (getItemCargo _radioContainer) isEqualTo [[],[]]
    &&
    {
      private _obj = (everyBackpack _radioContainer) select 0;
      _obj call TFAR_fnc_isLRRadio
    }) exitWith {(everyBackpack _radioContainer) select 0};

if (_radioContainer call TFAR_fnc_isLRRadio) exitWith {_radioContainer};


if (_radioClass isEqualTo "" || {!(_radioClass call TFAR_fnc_isPrototypeRadio)}) exitWith {_radioClass};

// Vanilla ItemRadio has no instances of its own, resolve it to the default personal radio (like core's requestRadios)
private _radioBaseClass = _radioClass;
if (_radioBaseClass == "ItemRadio") then {
    _radioBaseClass = (_radioContainer call TFAR_fnc_getDefaultRadioClasses) param [1, ""];
};
_radioBaseClass = [_radioBaseClass, "tf_parent", ""] call TFAR_fnc_getWeaponConfigProperty;
if (_radioBaseClass isEqualTo "") exitWith {_radioClass};

private _radioID = ([[_radioBaseClass]] call TFAR_fnc_instanciateRadios) select 0;
if (_radioID < 1) exitWith {_radioClass};

private _radioInstanciated = format ["%1_%2", _radioBaseClass, _radioID];

if (_radioInstanciated != _radioClass) then {
    _radioContainer addWeaponCargoGlobal ["arifle_MX_F", 1];
    clearItemCargoGlobal _radioContainer;
    _radioContainer addItemCargoGlobal [_radioInstanciated, 1];
    clearWeaponCargoGlobal _radioContainer;
};
_radioInstanciated
