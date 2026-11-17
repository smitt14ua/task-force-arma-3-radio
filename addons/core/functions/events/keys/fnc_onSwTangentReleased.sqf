#include "script_component.hpp"

/*
  Name: TFAR_fnc_onSwTangentReleased

  Author: NKey
    Fired when the keybinding for SR is released.

  Arguments:
    None

  Return Value:
    Whether or not the event was handled <BOOL>

  Example:
    call TFAR_fnc_onSwTangentReleased;

  Public: No
*/

if (!TF_tangent_sw_pressed || {TF_tangent_sw_additional}) exitWith {false};

TF_tangent_sw_pressed = false;
//End what was pressed, the active radio, channel or frequency may have changed meanwhile
[0] call TFAR_fnc_endTangentTransmission;
false
