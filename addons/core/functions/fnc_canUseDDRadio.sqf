#include "script_component.hpp"

/*
  Name: TFAR_fnc_canUseDDRadio

  Author: NKey
    Checks whether it is possible for the DD radio to be used at the current height and isolated status.

  Arguments:
    0: Eye height ASL <NUMBER>
    1: Isolated and inside <BOOL>
    2: Unit <OBJECT> (default: TFAR_currentUnit)

  Return Value:
    radio can be used <BOOL>

  Example:
    _canUseDD = [-12,true] call TFAR_fnc_canUseDDRadio;

  Public: Yes
*/

params ["_depth", "_isolated_and_inside", ["_unit", objNull, [objNull]]];

if (isNull _unit || {_unit isEqualTo TFAR_currentUnit}) exitWith {
    (_depth < 0) and !(_isolated_and_inside) and {call TFAR_fnc_haveDDRadio}
};

//TFAR_fnc_haveDDRadio only knows TFAR_currentUnit
(_depth < 0) and !(_isolated_and_inside)
    and {getNumber (configFile >> "CfgWeapons" >> vest _unit >> "tf_hasDDradio") isEqualTo 1}
    and {(_unit call TFAR_fnc_radiosList) isNotEqualTo []}
