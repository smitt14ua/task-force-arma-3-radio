#include "script_component.hpp"

/*
  Name: TFAR_fnc_keybindModifiersReleased

  Author: Smith
    Whether a TFAR keybind fired only because of a stale Arma modifier flag: every key combination bound to it needs
    a modifier that was actually released (see TFAR_fnc_isModifierReleased). CBA fires keybinds with Arma's flags.

  Arguments:
    0: TFAR keybind action name <STRING>

  Return Value:
    Fired on a released modifier <BOOL>

  Example:
    "LRTransmit" call TFAR_fnc_keybindModifiersReleased;

  Public: No
*/

private _keybind = ["TFAR", _this] call CBA_fnc_getKeybind;
if (isNil "_keybind") exitWith {false};

private _released = [0, 1, 2] apply {_x call TFAR_fnc_isModifierReleased};
private _binds = _keybind param [8, []];
_binds isNotEqualTo [] && {
    _binds findIf {
        private _modifiers = _x param [1, [false, false, false]];
        //This combination is valid if none of its required modifiers was released
        [0, 1, 2] findIf {(_modifiers select _x) && {_released select _x}} == -1
    } == -1
}
