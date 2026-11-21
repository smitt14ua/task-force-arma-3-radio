#include "script_component.hpp"

/*
  Name: TFAR_fnc_trackTangentKeys

  Author: Smith
    Key tracking for the tangent keybinds, from the main display's KeyDown/KeyUp events.
    - Modifiers: Arma's flags can stay set after the modifier was released (let go of Ctrl and Caps together and the
      next Caps press still arrives with ctrl, firing the Ctrl+Caps LR tangent), see TFAR_fnc_isModifierReleased.
    - Releasing the main key of the LR chord ends the 0.5 s SW block of TFAR_fnc_onSwTangentPressed.

  Arguments:
    0: Pressed (KeyDown) <BOOL>
    1: Display event arguments <ARRAY>

  Return Value:
    false, so the key event is not consumed <BOOL>

  Example:
    [true, _this] call TFAR_fnc_trackTangentKeys;

  Public: No
*/

params ["_pressed", "_args"];
private _scancode = _args select 1;

if (_scancode in [42, 54, 29, 157, 56, 184]) exitWith { //left and right Shift, Ctrl, Alt
    GVAR(modifierKeys) set [_scancode, [diag_tickTime, -1] select _pressed];
    false
};

if (!_pressed && {_scancode == GVAR(lrChordKey)}) then {
    GVAR(lrChordKey) = -1;
    TF_last_lr_tangent_press = -1;
};

false
