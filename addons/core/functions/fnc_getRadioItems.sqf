#include "script_component.hpp"

/*
  Name: TFAR_fnc_getRadioItems

  Author: Dorbedo
    returns the TFAR radio items of a unit (without backpack radios)

  Arguments:
    0: the unit <OBJECT>
    1: without duplicates <BOOL> (default: true)

  Return Value:
    the radioitems of a unit <ARRAY>

  Example:
    _itemlist = [_player] call TFAR_fnc_getRadioItems;

  Public: Yes
*/

params [
    ["_unit", objNull, [objNull]],
    ["_withOutDuplicates", true, [true]]
];

private _allItems = (assignedItems _unit);
// uniformItems/vestItems keep duplicates (getItemCargo select 0 is already unique)
_allItems append (uniformItems _unit);
_allItems append (vestItems _unit);

If (_withOutDuplicates) then {
    _allItems = _allItems arrayIntersect _allItems;
};

_allItems select {((_x call TFAR_fnc_isRadio)||{_x call TFAR_fnc_isPrototypeRadio})}
