#include "script_component.hpp"

/*
  Name: TFAR_fnc_activeSwRadio

  Author: NKey
    returns the active SR radio

  Arguments:
    None

  Return Value:
    active SR radio, nil if there is none <STRING>

  Example:
    call TFAR_fnc_activeSwRadio;

  Public: Yes
*/

private _items = assignedItems TFAR_currentUnit;
private _index = _items findIf {_x call TFAR_fnc_isRadio};
if (_index == -1) exitWith {nil}; //Don't return an undefined variable, that errors in scheduled code
_items select _index
