#include "script_component.hpp"

/*
  Name: TFAR_fnc_isModifierReleased

  Author: Smith
    Whether a modifier was released within the last second and neither of its keys is held, so Arma's flag for it
    is stale (see TFAR_fnc_trackTangentKeys). Older releases trust Arma's flag, in case the KeyDown went to another
    display. A lost KeyUp leaves the key held, which also trusts Arma's flag.

  Arguments:
    0: Modifier, 0 = Shift, 1 = Ctrl, 2 = Alt <NUMBER>

  Return Value:
    Released <BOOL>

  Example:
    1 call TFAR_fnc_isModifierReleased;

  Public: No
*/

private _states = ([[42, 54], [29, 157], [56, 184]] select _this) apply {GVAR(modifierKeys) getOrDefault [_x, -1e9]};
!(-1 in _states) && {_states findIf {diag_tickTime - _x < 1} != -1}
