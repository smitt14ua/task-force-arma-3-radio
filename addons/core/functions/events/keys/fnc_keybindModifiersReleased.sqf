#include "script_component.hpp"

/*
  Name: TFAR_fnc_keybindModifiersReleased

  Author: Smith
    Whether a TFAR keybind fired only because of a stale Arma modifier flag: the key combinations bound to it with
    the pressed key all need a modifier that was actually released (see TFAR_fnc_isModifierReleased). CBA fires
    keybinds with Arma's flags.

  Arguments:
    0: TFAR keybind action name <STRING>
    1: Pressed key scancode, -1 if unknown (checks all combinations) <NUMBER>

  Return Value:
    Fired on a released modifier <BOOL>

  Example:
    ["LRTransmit", 58] call TFAR_fnc_keybindModifiersReleased;

  Public: No
*/

params ["_action", ["_scancode", -1, [0]]];

private _keybind = ["TFAR", _action] call CBA_fnc_getKeybind;
if (isNil "_keybind") exitWith {false};
private _binds = _keybind param [8, []];
private _pressedBinds = _binds select {(_x select 0) == _scancode};
if (_pressedBinds isNotEqualTo []) then {_binds = _pressedBinds};

private _released = [0, 1, 2] apply {_x call TFAR_fnc_isModifierReleased};
_binds isNotEqualTo [] && {
    _binds findIf {
        private _modifiers = _x param [1, [false, false, false]];
        //This combination is valid if none of its required modifiers was released
        [0, 1, 2] findIf {(_modifiers select _x) && {_released select _x}} == -1
    } == -1
}
