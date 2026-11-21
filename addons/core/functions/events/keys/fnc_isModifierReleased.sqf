#include "script_component.hpp"

/*
  Name: TFAR_fnc_isModifierReleased

  Author: Smith
    Whether a modifier was seen released within the last second and neither of its keys is held since, so Arma's
    flag for it is stale (see TFAR_fnc_trackTangentKeys). After a second Arma's flags are trusted again, in case a
    later KeyDown went to another display.

  Arguments:
    0: Modifier, 0 = Shift, 1 = Ctrl, 2 = Alt <NUMBER>

  Return Value:
    Released <BOOL>

  Example:
    1 call TFAR_fnc_isModifierReleased;

  Public: No
*/

private _keys = [[42, 54], [29, 157], [56, 184]] select _this; //left and right Shift, Ctrl, Alt
if (_keys findIf {_x in GVAR(keysHeld)} != -1) exitWith {false};
_keys findIf {diag_tickTime - (GVAR(keysReleased) getOrDefault [_x, -1e9]) < 1} != -1
