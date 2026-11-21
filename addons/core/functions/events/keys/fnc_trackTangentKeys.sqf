#include "script_component.hpp"

/*
  Name: TFAR_fnc_trackTangentKeys

  Author: Smith
    Remembers which keys are physically held, from the display's KeyDown/KeyUp events. Arma's own modifier flags can
    stay set after the modifier was released: let go of Ctrl and Caps together and the next Caps press still arrives
    with ctrl, so a Ctrl+Caps (LR) tangent fires instead of the Caps (SW) one.

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

if (_pressed) then {
    //Keep the time of the first KeyDown, the key repeats while held
    if !(_scancode in GVAR(keysHeld)) then {GVAR(keysHeld) set [_scancode, time]};
} else {
    GVAR(keysHeld) deleteAt _scancode;
    GVAR(keysReleased) set [_scancode, diag_tickTime];
};

false
